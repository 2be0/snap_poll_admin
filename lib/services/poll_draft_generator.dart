import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/question.dart';
import 'llm_settings.dart';

/// LLM이 만든 설문 초안. 저장 전 관리자가 편집기에서 검토/수정한다.
class PollDraft {
  final String title;
  final String description;
  final List<Question> questions;

  const PollDraft({
    required this.title,
    required this.description,
    required this.questions,
  });
}

/// 초안 생성 실패. [message]는 그대로 사용자에게 보여줄 수 있는 한국어 문장이다.
class PollDraftException implements Exception {
  final String message;

  const PollDraftException(this.message);

  @override
  String toString() => message;
}

/// 자연어 요청을 OpenAI 호환 `/chat/completions` API로 보내 설문 초안을 만든다.
///
/// 서버마다 지원하는 응답 형식이 달라서, 가장 엄격한 `json_schema`부터 시도하고
/// 서버가 400/422로 거부하면 `json_object`, 그다음 형식 지정 없이 순서대로 재시도한다.
/// 어느 경우든 응답 JSON은 앱에서 다시 검증·정규화한다.
class PollDraftGenerator {
  final http.Client _client;
  final Duration timeout;

  PollDraftGenerator({http.Client? client, this.timeout = const Duration(seconds: 120)})
      : _client = client ?? http.Client();

  static const String _systemPrompt = '''
You draft surveys for a classroom/workshop poll app.
Respond with a single JSON object only, matching this shape:
{"title": string, "description": string, "questions": [{"text": string, "type": "radio" | "checkbox" | "text", "options": [string], "required": boolean}]}

Rules:
- "radio" = single choice, "checkbox" = multiple choice, "text" = free-text answer.
- Choice questions ("radio", "checkbox") must have at least 2 distinct options.
- "text" questions must have "options": [].
- Follow the number and kinds of questions the user asks for. If unspecified, write 3 to 5 questions.
- Write the title, description, questions and options in the same language as the user's request.
- "description" is one short sentence for respondents; use "" if nothing useful to say.
- Set "required" to true unless the user says otherwise.''';

  static const Map<String, dynamic> _schema = {
    'type': 'object',
    'additionalProperties': false,
    'required': ['title', 'description', 'questions'],
    'properties': {
      'title': {'type': 'string'},
      'description': {'type': 'string'},
      'questions': {
        'type': 'array',
        'items': {
          'type': 'object',
          'additionalProperties': false,
          'required': ['text', 'type', 'options', 'required'],
          'properties': {
            'text': {'type': 'string'},
            'type': {
              'type': 'string',
              'enum': ['radio', 'checkbox', 'text'],
            },
            'options': {
              'type': 'array',
              'items': {'type': 'string'},
            },
            'required': {'type': 'boolean'},
          },
        },
      },
    },
  };

  static final List<Map<String, dynamic>?> _responseFormats = [
    {
      'type': 'json_schema',
      'json_schema': {'name': 'poll_draft', 'strict': true, 'schema': _schema},
    },
    {'type': 'json_object'},
    null,
  ];

  Future<PollDraft> generate(String request, LlmSettings settings) async {
    if (!settings.isConfigured) {
      throw const PollDraftException('AI 설정에서 서버 주소와 모델을 먼저 입력하세요.');
    }
    if (request.trim().isEmpty) {
      throw const PollDraftException('어떤 설문을 만들지 입력하세요.');
    }

    http.Response? lastRejected;
    for (final format in _responseFormats) {
      final response = await _post(settings, request.trim(), format);
      if (response.statusCode == 400 || response.statusCode == 422) {
        // 이 서버가 해당 response_format을 지원하지 않는 경우일 수 있으므로 다음 형식으로 재시도.
        lastRejected = response;
        continue;
      }
      _throwIfHttpError(response);
      return parseDraft(_extractContent(response));
    }
    _throwIfHttpError(lastRejected!);
    throw StateError('unreachable');
  }

  Future<http.Response> _post(
    LlmSettings settings,
    String request,
    Map<String, dynamic>? responseFormat,
  ) async {
    final body = <String, dynamic>{
      'model': settings.model.trim(),
      'messages': [
        {'role': 'system', 'content': _systemPrompt},
        {'role': 'user', 'content': request},
      ],
      if (responseFormat != null) 'response_format': responseFormat,
    };
    final headers = {
      'Content-Type': 'application/json',
      if (settings.apiKey.trim().isNotEmpty)
        'Authorization': 'Bearer ${settings.apiKey.trim()}',
    };
    try {
      return await _client
          .post(settings.chatCompletionsUri, headers: headers, body: jsonEncode(body))
          .timeout(timeout);
    } on TimeoutException {
      throw const PollDraftException('AI 서버 응답 시간이 초과되었습니다.');
    } on FormatException {
      throw const PollDraftException('AI 서버 주소 형식이 올바르지 않습니다.');
    } catch (e) {
      throw PollDraftException('AI 서버에 연결할 수 없습니다. 주소와 네트워크를 확인하세요. ($e)');
    }
  }

  void _throwIfHttpError(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    final detail = _errorMessage(response);
    switch (response.statusCode) {
      case 401:
      case 403:
        throw PollDraftException('API 키가 올바르지 않거나 권한이 없습니다. ($detail)');
      case 404:
        throw PollDraftException('서버 주소나 모델 이름을 확인하세요. ($detail)');
      case 429:
        throw PollDraftException('요청 한도를 초과했습니다. 잠시 후 다시 시도하세요. ($detail)');
      default:
        throw PollDraftException('AI 서버 오류 (HTTP ${response.statusCode}): $detail');
    }
  }

  /// OpenAI 형식 `{"error": {"message": ...}}`을 우선 읽고, 아니면 본문 일부를 돌려준다.
  String _errorMessage(http.Response response) {
    final body = utf8.decode(response.bodyBytes, allowMalformed: true);
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final error = decoded['error'];
        if (error is Map && error['message'] is String) return error['message'] as String;
        if (error is String) return error;
      }
    } catch (_) {}
    return body.length > 200 ? '${body.substring(0, 200)}…' : body;
  }

  String _extractContent(http.Response response) {
    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw const PollDraftException('AI 서버 응답을 해석할 수 없습니다.');
    }
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) {
      throw const PollDraftException('AI 서버가 빈 응답을 보냈습니다.');
    }
    final choice = choices.first as Map<String, dynamic>;
    final message = choice['message'] as Map<String, dynamic>? ?? const {};
    final refusal = message['refusal'];
    if (refusal is String && refusal.isNotEmpty) {
      throw PollDraftException('AI가 요청을 거절했습니다: $refusal');
    }
    if (choice['finish_reason'] == 'length') {
      throw const PollDraftException('응답이 너무 길어 중간에 잘렸습니다. 문항 수를 줄여 다시 시도하세요.');
    }
    final content = message['content'];
    if (content is! String || content.trim().isEmpty) {
      throw const PollDraftException('AI 서버가 빈 응답을 보냈습니다.');
    }
    return content;
  }

  /// 모델 출력(JSON 문자열)을 [PollDraft]로 변환한다. 코드 블록(```json)이나 앞뒤 설명 문장이
  /// 섞여 있어도 첫 `{`부터 마지막 `}`까지를 JSON으로 읽는다. 테스트를 위해 공개한다.
  static PollDraft parseDraft(String content) {
    final start = content.indexOf('{');
    final end = content.lastIndexOf('}');
    if (start < 0 || end <= start) {
      throw const PollDraftException('AI 응답에서 설문 JSON을 찾지 못했습니다.');
    }
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(content.substring(start, end + 1)) as Map<String, dynamic>;
    } catch (_) {
      throw const PollDraftException('AI 응답의 JSON 형식이 올바르지 않습니다.');
    }

    final title = (json['title'] as String? ?? '').trim();
    final rawQuestions = json['questions'];
    if (title.isEmpty || rawQuestions is! List || rawQuestions.isEmpty) {
      throw const PollDraftException('AI 응답에 제목이나 문항이 없습니다. 요청을 조금 더 구체적으로 적어 보세요.');
    }

    final baseId = DateTime.now().microsecondsSinceEpoch;
    final questions = <Question>[];
    for (final raw in rawQuestions) {
      if (raw is! Map) continue;
      final text = (raw['text'] as String? ?? '').trim();
      if (text.isEmpty) continue;
      final type = QuestionType.all.contains(raw['type']) ? raw['type'] as String : QuestionType.text;
      final options = <String>[];
      if (type != QuestionType.text && raw['options'] is List) {
        for (final o in raw['options'] as List) {
          final option = o.toString().trim();
          if (option.isNotEmpty && !options.contains(option)) options.add(option);
        }
      }
      questions.add(Question(
        // 문항 ID는 모델에 맡기지 않고 앱의 기존 규칙(q_{microseconds})으로 생성한다.
        id: 'q_${baseId + questions.length}',
        text: text,
        type: type,
        options: options,
        required: raw['required'] is bool ? raw['required'] as bool : true,
      ));
    }
    if (questions.isEmpty) {
      throw const PollDraftException('AI 응답에 사용할 수 있는 문항이 없습니다.');
    }

    return PollDraft(
      title: title,
      description: (json['description'] as String? ?? '').trim(),
      questions: questions,
    );
  }
}
