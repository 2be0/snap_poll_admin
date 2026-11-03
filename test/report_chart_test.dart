import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:snap_poll_admin/models/poll.dart';
import 'package:snap_poll_admin/models/question.dart';
import 'package:snap_poll_admin/pages/report_page.dart';
import 'package:snap_poll_admin/providers/poll_provider.dart';
import 'package:snap_poll_admin/server/poll_server.dart';

void main() {
  testWidgets(
    '단일 선택(radio) 문항은 파이차트로, 복수 선택(checkbox) 문항은 막대그래프로 표시된다',
    (tester) async {
      final server = PollServer(port: 0);
      // PollServer.start()는 실제 네트워크 인터페이스 조회/소켓 바인딩(dart:io)을 수행하므로
      // runAsync로 실제 이벤트 루프를 돌려야 완료된다.
      await tester.runAsync(
        () => server.start().timeout(const Duration(seconds: 5)),
      );

      final poll = Poll(
        id: 'p1',
        title: '간식 취향 조사',
        description: '',
        createdAt: DateTime.now(),
        questions: [
          Question(
            id: 'q1',
            text: '가장 좋아하는 간식은?',
            type: QuestionType.radio,
            options: ['빵', '과자'],
          ),
          Question(
            id: 'q2',
            text: '좋아하는 음료를 모두 고르세요',
            type: QuestionType.checkbox,
            options: ['커피', '주스'],
          ),
        ],
      );
      server.addPoll(poll);
      server.setPublished('p1', true);
      poll.responses.add(PollResponse(
        id: 'r1',
        pollId: 'p1',
        answers: {
          'q1': '빵',
          'q2': ['커피', '주스'],
        },
        submittedAt: DateTime.now(),
      ));
      poll.responses.add(PollResponse(
        id: 'r2',
        pollId: 'p1',
        answers: {
          'q1': '과자',
          'q2': ['커피'],
        },
        submittedAt: DateTime.now(),
      ));

      // 두 문항(파이차트+막대그래프) 카드가 스크롤 없이 모두 보이도록 화면을 충분히 키운다.
      addTearDown(tester.view.resetPhysicalSize);
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        ChangeNotifierProvider<PollProvider>(
          create: (_) => PollProvider(server: server),
          child: const MaterialApp(home: ReportPage(initialPollId: 'p1')),
        ),
      );
      // fl_chart는 진입 애니메이션을 계속 재생하므로 pumpAndSettle 대신
      // 고정된 프레임 수만큼 pump하여 애니메이션이 안정화된 상태를 확인한다.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(tester.takeException(), isNull);
      // radio 문항 -> PieChart
      expect(find.byType(PieChart), findsOneWidget);
      // checkbox 문항 -> BarChart
      expect(find.byType(BarChart), findsOneWidget);

      // 파이차트 범례에 옵션과 응답 수가 표시되어야 한다.
      expect(find.text('빵 (1)'), findsOneWidget);
      expect(find.text('과자 (1)'), findsOneWidget);

      await tester.runAsync(() => server.stop());
    },
  );
}

