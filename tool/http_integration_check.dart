// ignore_for_file: avoid_print
//
// 실제 HTTP 네트워크 스택(클라이언트가 브라우저에서 응답을 제출하는 것과 동일한 경로)을
// 통해 PollServer의 API가 올바르게 동작하는지 검증하는 통합 점검 스크립트.
//
// flutter_test(위젯 테스트) 환경에서는 flutter_tester 프로세스 특성상 같은 프로세스 내에서
// 서버로 재접속하는 소켓 I/O가 멈추는 문제가 있어(HttpClient 오버라이드/Socket 모두 재현됨),
// 실제 네트워크 왕복 검증은 순수 Dart 스크립트로 별도 실행한다.
//
// 실행: dart run tool/http_integration_check.dart
import 'dart:convert';
import 'dart:io';

import 'package:snap_poll_admin/models/poll.dart';
import 'package:snap_poll_admin/models/question.dart';
import 'package:snap_poll_admin/server/poll_server.dart';

Future<void> main() async {
  final server = PollServer(port: 0);
  await server.start();
  print('Server started at ${server.baseUrl}');

  final poll = Poll(
    id: 'p1',
    title: '통합 점검 설문',
    description: '',
    createdAt: DateTime.now(),
    questions: [
      Question(
        id: 'q1',
        text: '좋아하는 계절은?',
        type: QuestionType.radio,
        options: ['봄', '여름'],
      ),
    ],
  );
  server.addPoll(poll);
  server.setPublished('p1', true);

  final client = HttpClient();

  final getReq = await client.getUrl(Uri.parse('${server.baseUrl}/api/polls'));
  final getRes = await getReq.close();
  final getBody = await getRes.transform(utf8.decoder).join();
  _check(getRes.statusCode == 200, 'GET /api/polls -> 200');
  _check(getBody.contains('통합 점검 설문'), 'GET /api/polls body contains title');

  final postReq = await client.postUrl(
    Uri.parse('${server.baseUrl}/api/polls/p1/responses'),
  );
  postReq.headers.contentType = ContentType.json;
  postReq.write(jsonEncode({
    'answers': {'q1': '봄'},
  }));
  final postRes = await postReq.close();
  await postRes.drain<void>();
  _check(postRes.statusCode == 201, 'POST responses -> 201');

  final responses = server.getResponses('p1');
  _check(responses.length == 1, 'server recorded 1 response');
  _check(responses.first.answers['q1'] == '봄', 'recorded answer matches');

  client.close();
  await server.stop();
  print('HTTP INTEGRATION CHECK PASSED');
}

void _check(bool condition, String description) {
  if (!condition) {
    print('FAILED: $description');
    exit(1);
  }
  print('OK: $description');
}
