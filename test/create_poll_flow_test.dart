import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_poll_admin/main.dart';

import 'support/fake_path_provider.dart';

void main() {
  testWidgets(
    '홈에서 새 설문을 만들고 저장하면 Provider 에러 없이 목록에 반영된다',
    (tester) async {
      // main.dart가 실제로 path_provider(getApplicationSupportDirectory)를 사용하므로,
      // 플랫폼 채널이 없는 테스트 환경에서도 동작하도록 임시 디렉터리를 반환하는 가짜 구현을 등록한다.
      final tempDir = setUpFakePathProvider();
      addTearDown(() => tempDir.deleteSync(recursive: true));

      // PollServer.start()는 실제 네트워크 인터페이스 조회/소켓 바인딩(dart:io)을 수행하므로,
      // 가짜 시간으로 동작하는 기본 pump()가 아니라 runAsync로 실제 이벤트 루프를 돌려야 완료된다.
      await tester.runAsync(() async {
        await tester.pumpWidget(const SnapPollAdminApp());
        await Future<void>.delayed(const Duration(seconds: 1));
      });
      await tester.pump();
      await tester.pump();

      expect(find.text('아직 생성된 설문이 없습니다'), findsOneWidget);

      // 홈 -> 새 설문 생성 페이지로 이동 (Navigator.push)
      await tester.tap(find.text('새 설문'));
      await tester.pumpAndSettle();

      expect(find.text('새 설문 만들기'), findsOneWidget);

      // 제목 입력
      await tester.enterText(find.widgetWithText(TextField, '설문 제목'), '점심 메뉴 투표');

      // 문항 추가
      await tester.tap(find.text('문항 추가'));
      await tester.pumpAndSettle();

      // 추가된 문항의 텍스트 입력
      await tester.enterText(find.widgetWithText(TextField, '질문 내용'), '좋아하는 메뉴는?');
      await tester.pumpAndSettle();

      // 저장 버튼이 화면 아래쪽에 있어 스크롤이 필요할 수 있다.
      await tester.scrollUntilVisible(
        find.text('설문 만들기'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // 저장 버튼 클릭 -> 여기서 이전에 ProviderNotFoundException이 발생했었음
      await tester.tap(find.text('설문 만들기'));
      await tester.pumpAndSettle();

      // 예외 없이 홈으로 돌아와 새 설문이 목록에 표시되어야 한다
      expect(tester.takeException(), isNull);
      expect(find.text('점심 메뉴 투표'), findsOneWidget);

      // 퍼블리시 페이지(Navigator.push)에서도 Provider가 정상 상속되는지 확인
      await tester.tap(find.text('퍼블리시'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('퍼블리시 / QR 공유'), findsOneWidget);

      // 설문 공개 스위치 토글 (PollProvider.publishPoll 호출)
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('공개 중'), findsWidgets);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      // 설문 카드의 "결과 보기" 버튼으로 해당 설문의 보고서로 바로 이동할 수 있어야 한다.
      expect(find.text('결과 보기'), findsOneWidget);
      await tester.tap(find.text('결과 보기'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('보고서'), findsWidgets);
      // 드롭다운에 해당 설문이 기본 선택되어 표시되어야 한다.
      expect(find.text('점심 메뉴 투표'), findsWidgets);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      // AppBar의 보고서 아이콘(전체 보고서)에서도 Provider가 정상 상속되는지 확인
      await tester.tap(find.byIcon(Icons.bar_chart).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('보고서'), findsWidgets);
      expect(find.text('점심 메뉴 투표'), findsWidgets);
    },
  );
}
