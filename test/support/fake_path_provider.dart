import 'dart:io';

import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// 위젯 테스트 환경에는 실제 플랫폼 채널이 없어 `path_provider`가 동작하지 않으므로,
/// 임시 디렉터리를 반환하는 가짜 구현체를 등록해 앱의 실제 진입점(main.dart)을
/// 수정 없이 테스트에서도 그대로 사용할 수 있게 한다.
class FakePathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  final Directory tempDir;

  FakePathProviderPlatform(this.tempDir);

  @override
  Future<String?> getApplicationSupportPath() async => tempDir.path;

  @override
  Future<String?> getApplicationDocumentsPath() async => tempDir.path;

  @override
  Future<String?> getTemporaryPath() async => tempDir.path;
}

/// 테스트 전용 임시 디렉터리를 만들고 [PathProviderPlatform.instance]에 등록한다.
/// 반환된 디렉터리는 테스트가 끝난 뒤 호출자가 정리해야 한다.
Directory setUpFakePathProvider() {
  final tempDir = Directory.systemTemp.createTempSync('snap_poll_test_');
  PathProviderPlatform.instance = FakePathProviderPlatform(tempDir);
  return tempDir;
}
