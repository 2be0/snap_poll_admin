import 'dart:convert';
import 'dart:io';

import '../models/poll.dart';

/// 설문/응답 데이터를 JSON 파일로 영속화하는 저장소.
/// 앱이 재시작되어도 [PollServer]가 이 저장소를 통해 이전 데이터를 복원할 수 있다.
class PollStore {
  final Future<String> Function() _resolveFilePath;
  String? _cachedPath;

  PollStore(String filePath) : _resolveFilePath = (() async => filePath);

  /// 지정된 디렉터리 아래 `polls.json` 파일을 사용하는 저장소를 만든다.
  factory PollStore.inDirectory(String directoryPath) {
    return PollStore('$directoryPath${Platform.pathSeparator}polls.json');
  }

  /// 저장 디렉터리 경로 계산이 비동기인 경우(예: path_provider) 사용한다.
  /// [resolveDirectory]는 최초 사용 시 한 번만 호출되고 이후에는 캐시된다.
  PollStore.deferred(Future<Directory> Function() resolveDirectory)
      : _resolveFilePath = (() async {
          final dir = await resolveDirectory();
          return '${dir.path}${Platform.pathSeparator}polls.json';
        });

  Future<String> _path() async {
    return _cachedPath ??= await _resolveFilePath();
  }

  /// 저장된 설문 목록을 읽어온다. 파일이 없거나 손상된 경우 빈 목록을 반환한다
  /// (기존 데이터를 덮어쓰지 않도록 예외를 삼키고 로그만 남긴다).
  Future<List<Poll>> load() async {
    try {
      final file = File(await _path());
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];
      final decoded = jsonDecode(content) as List<dynamic>;
      return decoded
          .map((e) => Poll.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // 손상된 파일이어도 앱 기동 자체가 막히면 안 되므로 빈 목록으로 폴백한다.
      // ignore: avoid_print
      print('PollStore: 저장된 데이터를 불러오지 못했습니다 ($e). 빈 목록으로 시작합니다.');
      return [];
    }
  }

  /// 전체 설문 목록을 파일에 저장한다.
  /// 쓰는 도중 프로세스가 종료되어도 기존 파일이 손상되지 않도록,
  /// 임시 파일에 먼저 쓴 뒤 원자적으로 rename한다.
  Future<void> save(List<Poll> polls) async {
    final path = await _path();
    final tmpFile = File('$path.tmp');
    final json = jsonEncode(polls.map((p) => p.toJson()).toList());
    await tmpFile.parent.create(recursive: true);
    await tmpFile.writeAsString(json, flush: true);
    await tmpFile.rename(path);
  }
}

