import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:snap_poll_admin/models/poll.dart';
import 'package:snap_poll_admin/models/question.dart';
import 'package:snap_poll_admin/pages/home_page.dart';
import 'package:snap_poll_admin/pages/report_page.dart';
import 'package:snap_poll_admin/providers/poll_provider.dart';
import 'package:snap_poll_admin/server/poll_server.dart';

void main() {
  testWidgets(
    '서버 쪽에서 응답이 제출되면(클라이언트의 HTTP 제출과 동일 경로) 홈 화면과 보고서 화면이 자동으로 갱신된다',
    (tester) async {
      final server = PollServer(port: 0);
      await tester.runAsync(
        () => server.start().timeout(const Duration(seconds: 5)),
      );

      final poll = Poll(
        id: 'p1',
        title: '실시간 테스트 설문',
        description: '',
        createdAt: DateTime.now(),
        questions: [
          Question(
            id: 'q1',
            text: '점심 메뉴는?',
            type: QuestionType.radio,
            options: ['김밥', '라면'],
          ),
        ],
      );
      server.addPoll(poll);
      server.setPublished('p1', true);

      addTearDown(tester.view.resetPhysicalSize);
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;

      final provider = PollProvider(server: server);

      await tester.pumpWidget(
        ChangeNotifierProvider<PollProvider>.value(
          value: provider,
          child: const MaterialApp(home: HomePage()),
        ),
      );
      await tester.pumpAndSettle();

      // 초기 상태: 응답 0건
      expect(find.text('0건 응답'), findsOneWidget);

      // PollServer.submitResponse()는 HTTP 핸들러(_handleSubmitResponse)가 실제로
      // 호출하는 것과 동일한 경로이며, 이는 클라이언트가 브라우저에서 폼을 제출했을 때와
      // 서버 내부적으로 완전히 동일하게 동작한다(Flutter Provider를 거치지 않는 경로).
      // 실제 HTTP 왕복(네트워크 계층)까지 포함한 검증은
      // tool/http_integration_check.dart(dart run)에서 별도로 수행한다.
      server.submitResponse('p1', {'q1': '김밥'});

      // 스트림 이벤트가 전파될 시간을 준다.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Navigator.push 등 아무 조작 없이도 홈 화면의 응답 수가 즉시 갱신되어야 한다.
      expect(find.text('1건 응답'), findsOneWidget);
      expect(find.text('0건 응답'), findsNothing);

      // 보고서 화면에서도 최신 응답이 반영되어야 한다.
      await tester.pumpWidget(
        ChangeNotifierProvider<PollProvider>.value(
          value: provider,
          child: const MaterialApp(home: ReportPage(initialPollId: 'p1')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('응답 수'), findsOneWidget);
      expect(find.text('1'), findsWidgets);

      provider.dispose();
      await tester.runAsync(() => server.stop());
    },
  );
}


