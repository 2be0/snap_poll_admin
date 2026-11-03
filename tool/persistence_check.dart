// ignore_for_file: avoid_print
//
// 설문/응답 데이터가 파일로 영속화되어 "앱 재시작"에 해당하는 상황(새 PollServer
// 인스턴스를 같은 저장 경로로 다시 생성)에서도 데이터가 유지되는지 검증하는 스크립트.
//
// 실행: dart run tool/persistence_check.dart
import 'dart:io';

import 'package:snap_poll_admin/models/poll.dart';
import 'package:snap_poll_admin/models/question.dart';
import 'package:snap_poll_admin/server/poll_server.dart';
import 'package:snap_poll_admin/server/poll_store.dart';

Future<void> main() async {
  final tempDir = Directory.systemTemp.createTempSync('snap_poll_persist_check_');
  print('Using temp dir: ${tempDir.path}');

  try {
    // 1) 첫 번째 "앱 실행": 설문을 만들고 응답을 제출한 뒤 종료한다.
    final store1 = PollStore.inDirectory(tempDir.path);
    final server1 = PollServer(port: 0, store: store1);
    await server1.start();

    final poll = Poll(
      id: 'p1',
      title: '영속화 점검 설문',
      description: '재시작 후에도 남아있어야 함',
      createdAt: DateTime.now(),
      questions: [
        Question(
          id: 'q1',
          text: '테스트 문항',
          type: QuestionType.radio,
          options: ['A', 'B'],
        ),
      ],
    );
    server1.addPoll(poll);
    server1.setPublished('p1', true);
    server1.submitResponse('p1', {'q1': 'A'});

    // 변경 사항이 실제 파일에 기록될 때까지 대기한다.
    await server1.flush();

    final file = File('${tempDir.path}${Platform.pathSeparator}polls.json');
    _check(file.existsSync(), 'polls.json 파일이 생성되었다');

    await server1.stop();
    print('First "app run" finished and stopped.');

    // 2) 두 번째 "앱 실행"(재시작 시뮬레이션): 같은 디렉터리로 새 PollServer를 만든다.
    final store2 = PollStore.inDirectory(tempDir.path);
    final server2 = PollServer(port: 0, store: store2);
    await server2.start();

    final loadedPolls = server2.getPolls();
    _check(loadedPolls.length == 1, '재시작 후 설문 1개가 복원되었다');
    _check(loadedPolls.first.title == '영속화 점검 설문', '설문 제목이 유지되었다');
    _check(loadedPolls.first.isPublished == true, '퍼블리시 상태가 유지되었다');
    _check(loadedPolls.first.questions.length == 1, '문항이 유지되었다');

    final restoredResponses = server2.getResponses('p1');
    _check(restoredResponses.length == 1, '응답 1건이 복원되었다');
    _check(restoredResponses.first.answers['q1'] == 'A', '응답 내용이 유지되었다');

    await server2.stop();
    print('PERSISTENCE CHECK PASSED');
  } finally {
    tempDir.deleteSync(recursive: true);
  }
}

void _check(bool condition, String description) {
  if (!condition) {
    print('FAILED: $description');
    exit(1);
  }
  print('OK: $description');
}
