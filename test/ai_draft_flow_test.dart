import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:snap_poll_admin/models/question.dart';
import 'package:snap_poll_admin/pages/create_edit_poll_page.dart';
import 'package:snap_poll_admin/providers/poll_provider.dart';
import 'package:snap_poll_admin/server/poll_server.dart';
import 'package:snap_poll_admin/services/llm_settings.dart';
import 'package:snap_poll_admin/services/poll_draft_generator.dart';

void main() {
  testWidgets(
    '자연어 요청으로 받은 AI 초안이 편집기에 채워지고, 저장하면 설문이 만들어진다',
    (tester) async {
      final tempDir = Directory.systemTemp.createTempSync('snap_poll_ai_test_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final settings = LlmSettingsController(() async => tempDir);
      await tester.runAsync(() => settings.save(const LlmSettings(
            baseUrl: 'http://localhost:11434/v1',
            model: 'llama3.1',
          )));

      String? sentRequest;
      final generator = PollDraftGenerator(
        client: MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          sentRequest = (body['messages'] as List).last['content'] as String;
          return http.Response.bytes(
            utf8.encode(jsonEncode({
              'choices': [
                {
                  'finish_reason': 'stop',
                  'message': {
                    'content': jsonEncode({
                      'title': '점심 메뉴 투표',
                      'description': '오늘 점심을 정해요.',
                      'questions': [
                        {
                          'text': '먹고 싶은 메뉴는?',
                          'type': 'radio',
                          'options': ['김밥', '라면', '떡볶이'],
                          'required': true,
                        },
                        {
                          'text': '하고 싶은 말',
                          'type': 'text',
                          'options': [],
                          'required': false,
                        },
                      ],
                    }),
                  },
                },
              ],
            })),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final server = PollServer(port: 0);
      final pollProvider = PollProvider(server: server);
      addTearDown(pollProvider.dispose);

      addTearDown(tester.view.resetPhysicalSize);
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<PollProvider>.value(value: pollProvider),
            ChangeNotifierProvider<LlmSettingsController>.value(value: settings),
            Provider<PollDraftGenerator>.value(value: generator),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CreateEditPollPage()),
                    ),
                    child: const Text('열기'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();

      // 설정이 되어 있으므로 AI 카드의 생성 버튼이 보인다.
      expect(find.text('어떤 설문을 만들까요?'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '점심 메뉴 투표 만들어줘');
      await tester.tap(find.text('AI로 초안 만들기'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(sentRequest, '점심 메뉴 투표 만들어줘');
      expect(find.text('점심 메뉴 투표'), findsOneWidget);
      expect(find.text('먹고 싶은 메뉴는?'), findsOneWidget);
      expect(find.text('떡볶이'), findsOneWidget);
      expect(find.text('하고 싶은 말'), findsOneWidget);

      // 초안은 저장 전까지 설문으로 만들어지지 않는다.
      expect(server.getPolls(), isEmpty);

      await tester.scrollUntilVisible(
        find.text('설문 만들기'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('설문 만들기'));
      await tester.pumpAndSettle();

      final polls = server.getPolls();
      expect(polls, hasLength(1));
      expect(polls.first.title, '점심 메뉴 투표');
      expect(polls.first.questions.map((q) => q.type), [QuestionType.radio, QuestionType.text]);
    },
  );

  testWidgets('AI 설정이 없으면 설정 안내를 보여준다', (tester) async {
    final settings = LlmSettingsController(() async => Directory.systemTemp);
    final pollProvider = PollProvider(server: PollServer(port: 0));
    addTearDown(pollProvider.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PollProvider>.value(value: pollProvider),
          ChangeNotifierProvider<LlmSettingsController>.value(value: settings),
          Provider<PollDraftGenerator>.value(value: PollDraftGenerator()),
        ],
        child: const MaterialApp(home: CreateEditPollPage()),
      ),
    );

    expect(find.text('AI 서버 설정이 필요합니다.'), findsOneWidget);
    expect(find.text('AI 설정 열기'), findsOneWidget);
    expect(find.text('AI로 초안 만들기'), findsNothing);
  });
}
