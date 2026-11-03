import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/poll.dart';
import 'poll_html_builder.dart';
import 'poll_store.dart';

/// 관리자 앱 내에 내장되는 로컬 HTTP 서버.
/// - 관리자 앱(Flutter UI)과는 [PollServer]의 공개 메서드로 직접(인메모리) 통신한다.
/// - 같은 로컬 네트워크의 클라이언트는 HTTP(웹 브라우저)로 접속해 응답한다.
/// - [store]가 주어지면 설문/응답 데이터를 JSON 파일로 영속화해 앱 재시작 후에도 유지한다.
class PollServer {
  final List<Poll> _polls = [];
  HttpServer? _httpServer;
  String _localIp = '127.0.0.1';
  final int preferredPort;
  int _port;
  final PollStore? store;

  /// 설문/응답 데이터가 변경될 때마다(퍼블리시 토글, 응답 제출 등) 이벤트를 방출한다.
  /// HTTP 요청 스레드(클라이언트 응답 제출 포함)에서 발생한 변경도 관리자 UI가
  /// 이 스트림을 구독해 실시간으로 반영할 수 있도록 한다.
  final StreamController<void> _changes = StreamController<void>.broadcast();
  Stream<void> get onChange => _changes.stream;

  /// 데이터 변경 시마다 파일 저장을 트리거한다. 저장은 비동기로 진행되며,
  /// 마지막 저장 작업이 끝난 뒤 순서대로 처리되도록 체이닝한다(동시 쓰기로 인한 파일 손상 방지).
  Future<void> _saveChain = Future.value();

  void _notifyChanged() {
    if (!_changes.isClosed) _changes.add(null);
    _persist();
  }

  void _persist() {
    final currentStore = store;
    if (currentStore == null) return;
    // 스냅샷을 먼저 떠서(현재 시점의 데이터) 이후 변경과 저장 순서가 꼬이지 않게 한다.
    final snapshot = List<Poll>.of(_polls);
    _saveChain = _saveChain.then((_) => currentStore.save(snapshot)).catchError((
      Object e,
    ) {
      // ignore: avoid_print
      print('PollStore: 저장 실패 ($e)');
    });
  }

  /// 모든 저장 작업이 디스크에 반영될 때까지 대기한다. 테스트나 종료 시 사용.
  /// [store]가 없으면(영속화 미사용) 대기할 대상이 없으므로 즉시 반환한다 —
  /// 테스트 등 서로 다른 Zone에서 만들어진 Future를 불필요하게 await하지 않기 위함이다.
  Future<void> flush() => store == null ? Future.value() : _saveChain;

  /// 후보 포트가 이미 사용 중일 때 순서대로 시도할 대체 포트 목록.
  static const List<int> _fallbackPorts = [5000, 5050, 8080, 8088, 0];

  PollServer({int port = 5000, this.store})
      : preferredPort = port,
        _port = port;

  int get port => _port;
  String get localIp => _localIp;
  String get baseUrl => 'http://$_localIp:$_port';

  /// 서버를 바인딩하고 로컬 IP를 감지한 뒤 요청 처리를 시작한다.
  /// 선호 포트가 이미 사용 중이면(macOS AirPlay 등) 대체 포트로 자동 재시도한다.
  /// 포트 0은 OS가 임의의 빈 포트를 골라주므로 항상 성공한다.
  /// [store]가 있으면 시작 전에 저장된 설문/응답 데이터를 먼저 복원한다.
  Future<void> start() async {
    final currentStore = store;
    if (currentStore != null) {
      final loaded = await currentStore.load();
      _polls
        ..clear()
        ..addAll(loaded);
    }

    _localIp = await _detectLocalIp();
    final candidates = <int>{preferredPort, ..._fallbackPorts}.toList();
    Object? lastError;
    for (final candidate in candidates) {
      try {
        _httpServer = await HttpServer.bind(InternetAddress.anyIPv4, candidate);
        _port = _httpServer!.port;
        _httpServer!.listen(_handleRequest);
        return;
      } on SocketException catch (e) {
        lastError = e;
        continue;
      }
    }
    throw StateError('사용 가능한 포트를 찾지 못했습니다: $lastError');
  }

  Future<void> stop() async {
    await _httpServer?.close(force: true);
    await flush();
    // StreamController.broadcast().close()가 반환하는 Future는 "close 시점에 아직
    // 구독 중인 리스너가 모두 취소될 때까지" 완료되지 않는다(dart:async 문서 참고).
    // PollProvider.dispose()의 구독 취소(cancel())는 비동기이고 그 완료 시점을 서버가
    // 알 방법이 없으므로, close() 완료를 무한정 기다리다 멈추는 것을 방지하기 위해
    // 여기서는 close()를 요청만 하고 그 결과를 기다리지 않는다.
    unawaited(_changes.close());
  }

  /// 사설 대역(192.168.*, 10.*, 172.16-31.*) IPv4 주소를 우선으로 로컬 IP를 찾는다.
  Future<String> _detectLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
        includeLinkLocal: false,
      );
      final candidates = <InternetAddress>[];
      for (final iface in interfaces) {
        candidates.addAll(iface.addresses);
      }
      for (final addr in candidates) {
        if (_isPrivate(addr.address)) return addr.address;
      }
      if (candidates.isNotEmpty) return candidates.first.address;
    } catch (_) {
      // 감지 실패 시 loopback으로 폴백
    }
    return '127.0.0.1';
  }

  bool _isPrivate(String ip) {
    return ip.startsWith('192.168.') ||
        ip.startsWith('10.') ||
        RegExp(r'^172\.(1[6-9]|2[0-9]|3[0-1])\.').hasMatch(ip);
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final path = request.uri.path;
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    try {
      if (path == '/api/polls' && request.method == 'GET') {
        _sendJson(request, _polls.map((p) => p.toJson()).toList());
      } else if (path.startsWith('/api/polls/') &&
          path.endsWith('/responses') &&
          request.method == 'POST') {
        await _handleSubmitResponse(request, path);
      } else if (path.startsWith('/poll/') && request.method == 'GET') {
        await _handlePollPage(request, path);
      } else {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write('Not Found');
      }
    } catch (e) {
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write('Server error: $e');
    } finally {
      await request.response.close();
    }
  }

  Future<void> _handlePollPage(HttpRequest request, String path) async {
    final pollId = path.substring('/poll/'.length);
    final poll = getPollById(pollId);
    request.response.headers.contentType = ContentType.html;
    if (poll == null) {
      request.response.statusCode = HttpStatus.notFound;
      request.response.write('<h1>404 - 설문을 찾을 수 없습니다</h1>');
      return;
    }
    request.response.write(buildPollResponseHtml(poll));
  }

  Future<void> _handleSubmitResponse(HttpRequest request, String path) async {
    final segments = path.split('/'); // '', api, polls, {id}, responses
    final pollId = segments[3];
    final body = await utf8.decoder.bind(request).join();
    final data = jsonDecode(body) as Map<String, dynamic>;
    final response = submitResponse(
      pollId,
      Map<String, dynamic>.from(data['answers'] as Map? ?? {}),
    );
    if (response == null) {
      request.response.statusCode = HttpStatus.notFound;
      _sendJson(request, {'error': 'Poll not found'});
      return;
    }
    request.response.statusCode = HttpStatus.created;
    _sendJson(request, response.toJson());
  }

  /// 설문에 응답 한 건을 추가한다. 클라이언트의 HTTP 제출과 관리자 앱(테스트 포함)
  /// 양쪽에서 동일한 경로로 사용할 수 있도록 공개 메서드로 둔다.
  /// 설문이 없으면 null을 반환한다.
  PollResponse? submitResponse(String pollId, Map<String, dynamic> answers) {
    final poll = getPollById(pollId);
    if (poll == null) return null;
    final response = PollResponse(
      id: 'r_${DateTime.now().microsecondsSinceEpoch}',
      pollId: pollId,
      answers: answers,
      submittedAt: DateTime.now(),
    );
    poll.responses.add(response);
    _notifyChanged();
    return response;
  }

  void _sendJson(HttpRequest request, Object data) {
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(data));
  }

  // ----- 관리자 앱(Provider)에서 사용하는 인메모리 API -----

  List<Poll> getPolls() => List.unmodifiable(_polls);

  Poll? getPollById(String id) {
    for (final p in _polls) {
      if (p.id == id) return p;
    }
    return null;
  }

  void addPoll(Poll poll) {
    _polls.add(poll);
    _notifyChanged();
  }

  /// 기존 설문의 제목/설명/문항을 갱신한다(id, 생성일, 퍼블리시 상태, 응답은 유지).
  void updatePoll(Poll updated) {
    final existing = getPollById(updated.id);
    if (existing == null) return;
    existing.title = updated.title;
    existing.description = updated.description;
    existing.questions = updated.questions;
    _notifyChanged();
  }

  void removePoll(String id) {
    _polls.removeWhere((p) => p.id == id);
    _notifyChanged();
  }

  void setPublished(String id, bool published) {
    final poll = getPollById(id);
    if (poll == null) return;
    poll.isPublished = published;
    poll.publishedAt = published ? DateTime.now() : poll.publishedAt;
    _notifyChanged();
  }

  List<PollResponse> getResponses(String pollId) {
    final poll = getPollById(pollId);
    return poll == null ? [] : List.unmodifiable(poll.responses);
  }

  String getPollUrl(String pollId) => '$baseUrl/poll/$pollId';
}
