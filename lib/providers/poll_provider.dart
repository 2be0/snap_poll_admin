import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/poll.dart';
import '../server/poll_server.dart';

/// 관리자 UI 상태 관리. [PollServer]는 인메모리 저장소이자 HTTP 서버이므로
/// 관리자 앱에서 직접 호출하는 CRUD는 동기적으로 즉시 반영되고, 이후 화면 갱신을 위해
/// notifyListeners()를 호출한다.
/// 또한 같은 네트워크의 클라이언트가 브라우저로 응답을 제출하는 경우처럼 서버 쪽에서
/// 비동기로 발생하는 변경 사항도 [PollServer.onChange] 스트림을 구독해 실시간으로 반영한다.
class PollProvider with ChangeNotifier {
  final PollServer server;
  Poll? _selectedPoll;
  StreamSubscription<void>? _changeSubscription;

  PollProvider({required this.server}) {
    _changeSubscription = server.onChange.listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    // cancel()은 Future를 반환하지만 ChangeNotifier.dispose()는 동기 메서드이므로
    // 여기서 await할 수는 없다. 다만 구독을 즉시 null로 비워 중복 취소를 막는다.
    unawaited(_changeSubscription?.cancel());
    _changeSubscription = null;
    super.dispose();
  }

  List<Poll> get polls => server.getPolls();

  Poll? get selectedPoll => _selectedPoll;

  void setSelectedPoll(Poll? poll) {
    _selectedPoll = poll;
    notifyListeners();
  }

  void createPoll(Poll poll) {
    server.addPoll(poll);
    notifyListeners();
  }

  void updatePoll(Poll updated) {
    server.updatePoll(updated);
    notifyListeners();
  }

  void deletePoll(String pollId) {
    server.removePoll(pollId);
    if (_selectedPoll?.id == pollId) {
      _selectedPoll = null;
    }
    notifyListeners();
  }

  void publishPoll(String pollId) {
    server.setPublished(pollId, true);
    notifyListeners();
  }

  void unpublishPoll(String pollId) {
    server.setPublished(pollId, false);
    notifyListeners();
  }

  List<PollResponse> getResponses(String pollId) => server.getResponses(pollId);

  String getPollUrl(String pollId) => server.getPollUrl(pollId);

  String get baseUrl => server.baseUrl;
}
