import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:snap_poll_admin/models/question.dart';
import 'package:snap_poll_admin/services/llm_settings.dart';
import 'package:snap_poll_admin/services/poll_draft_generator.dart';

const _settings = LlmSettings(
  baseUrl: 'https://llm.example.com/v1/',
  model: 'test-model',
  apiKey: 'test-key',
);

const _draftJson = {
  'title': '광합성 이해도 확인',
  'description': '수업 내용을 얼마나 이해했는지 확인합니다.',
  'questions': [
    {
      'text': '광합성이 일어나는 세포 소기관은?',
      'type': 'radio',
      'options': ['엽록체', '미토콘드리아', '엽록체', ' '],
      'required': true,
    },
    {
      'text': '광합성에 필요한 것을 모두 고르세요',
      'type': 'checkbox',
      'options': ['빛', '물', '이산화탄소'],
      'required': true,
    },
    {
      'text': '오늘 수업 소감',
      'type': 'text',
      'options': ['무시되어야 함'],
      'required': false,
    },
  ],
};

http.Response _completion(String content, {String finishReason = 'stop'}) {
  return http.Response.bytes(
    utf8.encode(jsonEncode({
      'choices': [
        {
          'message': {'role': 'assistant', 'content': content},
          'finish_reason': finishReason,
        },
      ],
    })),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

void main() {
  test('OpenAI 호환 요청을 보내고 응답을 정규화된 초안으로 변환한다', () async {
    late http.Request captured;
    final generator = PollDraftGenerator(
      client: MockClient((request) async {
        captured = request;
        return _completion(jsonEncode(_draftJson));
      }),
    );

    final draft = await generator.generate('광합성 이해도 설문', _settings);

    expect(captured.url.toString(), 'https://llm.example.com/v1/chat/completions');
    expect(captured.headers['Authorization'], 'Bearer test-key');
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['model'], 'test-model');
    expect(body['response_format']['type'], 'json_schema');
    expect((body['messages'] as List).last['content'], '광합성 이해도 설문');

    expect(draft.title, '광합성 이해도 확인');
    expect(draft.questions, hasLength(3));
    // 중복/공백 옵션 제거
    expect(draft.questions[0].options, ['엽록체', '미토콘드리아']);
    expect(draft.questions[1].type, QuestionType.checkbox);
    // 주관식은 옵션을 비운다
    expect(draft.questions[2].options, isEmpty);
    expect(draft.questions[2].required, isFalse);
    // 문항 ID는 앱이 생성하며 서로 겹치지 않는다
    expect(draft.questions.map((q) => q.id).toSet(), hasLength(3));
    expect(draft.questions.every((q) => q.id.startsWith('q_')), isTrue);
  });

  test('API 키가 없으면 Authorization 헤더를 보내지 않는다 (로컬 서버)', () async {
    late http.Request captured;
    final generator = PollDraftGenerator(
      client: MockClient((request) async {
        captured = request;
        return _completion(jsonEncode(_draftJson));
      }),
    );

    await generator.generate(
      '설문',
      const LlmSettings(baseUrl: 'http://localhost:11434/v1', model: 'llama3.1'),
    );

    expect(captured.headers.containsKey('Authorization'), isFalse);
  });

  test('json_schema를 거부하는 서버면 json_object, 형식 없음 순서로 재시도한다', () async {
    final formats = <Object?>[];
    final generator = PollDraftGenerator(
      client: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        formats.add(body['response_format']?['type']);
        if (formats.length < 3) {
          return http.Response('{"error":{"message":"response_format not supported"}}', 400);
        }
        return _completion('```json\n${jsonEncode(_draftJson)}\n```');
      }),
    );

    final draft = await generator.generate('설문', _settings);

    expect(formats, ['json_schema', 'json_object', null]);
    expect(draft.questions, hasLength(3));
  });

  test('인증 실패는 사용자에게 보여줄 메시지로 바꾼다', () async {
    final generator = PollDraftGenerator(
      client: MockClient(
        (_) async => http.Response('{"error":{"message":"Incorrect API key"}}', 401),
      ),
    );

    expect(
      () => generator.generate('설문', _settings),
      throwsA(isA<PollDraftException>()
          .having((e) => e.message, 'message', contains('API 키'))),
    );
  });

  test('응답이 잘리면(finish_reason=length) 오류로 처리한다', () async {
    final generator = PollDraftGenerator(
      client: MockClient((_) async => _completion('{"title": "잘린', finishReason: 'length')),
    );

    expect(
      () => generator.generate('설문', _settings),
      throwsA(isA<PollDraftException>()),
    );
  });

  test('설정이 비어 있으면 요청을 보내지 않는다', () async {
    var called = false;
    final generator = PollDraftGenerator(
      client: MockClient((_) async {
        called = true;
        return _completion('{}');
      }),
    );

    await expectLater(
      () => generator.generate('설문', LlmSettings.empty),
      throwsA(isA<PollDraftException>()),
    );
    expect(called, isFalse);
  });

  test('제목이나 문항이 없는 응답은 거부한다', () {
    expect(
      () => PollDraftGenerator.parseDraft('{"title": "", "description": "", "questions": []}'),
      throwsA(isA<PollDraftException>()),
    );
    expect(
      () => PollDraftGenerator.parseDraft('JSON이 아닌 답변'),
      throwsA(isA<PollDraftException>()),
    );
  });
}
