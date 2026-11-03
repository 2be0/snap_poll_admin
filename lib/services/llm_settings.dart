import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// OpenAI 호환(Chat Completions) LLM 서버 접속 설정.
/// OpenAI, Ollama, LM Studio, vLLM 등 `/chat/completions`를 제공하는 서버라면 모두 사용할 수 있다.
class LlmSettings {
  /// 예: `https://api.openai.com/v1`, `http://localhost:11434/v1`
  final String baseUrl;
  final String model;

  /// 로컬 서버(Ollama 등)는 키가 필요 없으므로 빈 문자열을 허용한다.
  final String apiKey;

  const LlmSettings({
    required this.baseUrl,
    required this.model,
    this.apiKey = '',
  });

  static const LlmSettings empty = LlmSettings(baseUrl: '', model: '');

  bool get isConfigured => baseUrl.trim().isNotEmpty && model.trim().isNotEmpty;

  /// 끝의 `/`를 제거한 `.../chat/completions` 엔드포인트.
  Uri get chatCompletionsUri {
    var base = baseUrl.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return Uri.parse('$base/chat/completions');
  }

  Map<String, dynamic> toJson() => {
        'base_url': baseUrl,
        'model': model,
        'api_key': apiKey,
      };

  factory LlmSettings.fromJson(Map<String, dynamic> json) {
    return LlmSettings(
      baseUrl: json['base_url'] as String? ?? '',
      model: json['model'] as String? ?? '',
      apiKey: json['api_key'] as String? ?? '',
    );
  }
}

/// 자주 쓰는 OpenAI 호환 서버의 기본값. 설정 화면에서 빠르게 채워 넣는 용도.
class LlmPreset {
  final String label;
  final String baseUrl;
  final String model;

  const LlmPreset(this.label, this.baseUrl, this.model);

  static const List<LlmPreset> all = [
    LlmPreset('OpenAI', 'https://api.openai.com/v1', 'gpt-4o-mini'),
    LlmPreset('Ollama (로컬)', 'http://localhost:11434/v1', 'llama3.1'),
    LlmPreset('LM Studio (로컬)', 'http://localhost:1234/v1', 'local-model'),
  ];
}

/// [LlmSettings]를 앱 지원 디렉터리의 `llm_settings.json`에 저장하고,
/// 변경 시 화면이 갱신되도록 [ChangeNotifier]로 노출한다.
///
/// API 키는 앱 샌드박스 컨테이너 안의 파일에 평문으로 저장된다(다른 앱은 접근 불가).
/// 설문 데이터(`polls.json`)와 같은 방식이며, 키체인 연동은 서명/엔타이틀먼트 설정이 필요해 보류했다.
class LlmSettingsController with ChangeNotifier {
  final Future<Directory> Function() _resolveDirectory;
  LlmSettings _settings = LlmSettings.empty;

  LlmSettingsController(this._resolveDirectory);

  LlmSettings get settings => _settings;

  Future<File> _file() async {
    final dir = await _resolveDirectory();
    return File('${dir.path}${Platform.pathSeparator}llm_settings.json');
  }

  /// 저장된 설정을 읽어온다. 파일이 없거나 손상되었으면 빈 설정으로 둔다.
  Future<void> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return;
      final decoded = jsonDecode(await file.readAsString());
      _settings = LlmSettings.fromJson(decoded as Map<String, dynamic>);
      notifyListeners();
    } catch (e) {
      // ignore: avoid_print
      print('LlmSettings: 설정을 불러오지 못했습니다 ($e)');
    }
  }

  Future<void> save(LlmSettings settings) async {
    _settings = settings;
    notifyListeners();
    final file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(settings.toJson()), flush: true);
  }
}
