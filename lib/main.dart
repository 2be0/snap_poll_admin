import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'pages/home_page.dart';
import 'providers/poll_provider.dart';
import 'server/poll_server.dart';
import 'server/poll_store.dart';
import 'services/llm_settings.dart';
import 'services/poll_draft_generator.dart';

void main() {
  runApp(const SnapPollAdminApp());
}

class SnapPollAdminApp extends StatefulWidget {
  const SnapPollAdminApp({super.key});

  @override
  State<SnapPollAdminApp> createState() => _SnapPollAdminAppState();
}

class _SnapPollAdminAppState extends State<SnapPollAdminApp> {
  // 앱 전용 저장 공간(문서/지원 디렉터리)에 설문/응답 데이터를 JSON으로 영속화해,
  // 앱이 재시작되어도 기존 설문과 응답이 그대로 유지되도록 한다.
  // 디렉터리 경로 자체는 비동기로 계산되지만, PollServer/PollStore 인스턴스는
  // 즉시(동기적으로) 만들어 ChangeNotifierProvider를 처음부터 최상위에 고정할 수 있게 한다.
  late final PollStore _store = PollStore.deferred(getApplicationSupportDirectory);
  late final PollServer _server = PollServer(store: _store);
  // 자연어 설문 초안 생성에 쓰는 LLM 서버 설정(llm_settings.json)도 같은 디렉터리에 저장한다.
  late final LlmSettingsController _llmSettings =
      LlmSettingsController(getApplicationSupportDirectory);
  late final PollDraftGenerator _draftGenerator = PollDraftGenerator();
  late final Future<void> _startFuture = Future.wait([_server.start(), _llmSettings.load()]);

  @override
  void dispose() {
    _server.stop();
    _llmSettings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Provider들을 MaterialApp(및 그 내부 Navigator) 바깥에 고정해서,
    // 이후 Navigator.push로 열리는 모든 라우트가 항상 같은 Provider를 상속받도록 한다.
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<PollProvider>(create: (_) => PollProvider(server: _server)),
        ChangeNotifierProvider<LlmSettingsController>.value(value: _llmSettings),
        Provider<PollDraftGenerator>.value(value: _draftGenerator),
      ],
      child: MaterialApp(
        title: 'Snap Poll - Admin',
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
        home: FutureBuilder<void>(
          future: _startFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return Scaffold(
                body: Center(child: Text('서버 시작 실패: ${snapshot.error}')),
              );
            }
            return const HomePage();
          },
        ),
      ),
    );
  }
}
