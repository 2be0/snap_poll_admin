import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/llm_settings.dart';

/// 자연어 설문 초안 생성에 사용할 OpenAI 호환 LLM 서버 설정 페이지.
class LlmSettingsPage extends StatefulWidget {
  const LlmSettingsPage({super.key});

  @override
  State<LlmSettingsPage> createState() => _LlmSettingsPageState();
}

class _LlmSettingsPageState extends State<LlmSettingsPage> {
  late final TextEditingController _baseUrlController;
  late final TextEditingController _modelController;
  late final TextEditingController _apiKeyController;
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    final current = context.read<LlmSettingsController>().settings;
    _baseUrlController = TextEditingController(text: current.baseUrl);
    _modelController = TextEditingController(text: current.model);
    _apiKeyController = TextEditingController(text: current.apiKey);
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _modelController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  void _applyPreset(LlmPreset preset) {
    setState(() {
      _baseUrlController.text = preset.baseUrl;
      _modelController.text = preset.model;
    });
  }

  Future<void> _save() async {
    final baseUrl = _baseUrlController.text.trim();
    final model = _modelController.text.trim();
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https')) || uri.host.isEmpty) {
      _showMessage('서버 주소는 http:// 또는 https://로 시작해야 합니다');
      return;
    }
    if (model.isEmpty) {
      _showMessage('모델 이름을 입력하세요');
      return;
    }
    await context.read<LlmSettingsController>().save(LlmSettings(
          baseUrl: baseUrl,
          model: model,
          apiKey: _apiKeyController.text.trim(),
        ));
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 설정')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '자연어로 설문 초안을 만들 때 사용할 LLM 서버입니다. '
            'OpenAI 호환 API(/chat/completions)를 제공하는 서버면 무엇이든 쓸 수 있습니다.',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final preset in LlmPreset.all)
                ActionChip(label: Text(preset.label), onPressed: () => _applyPreset(preset)),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _baseUrlController,
            decoration: const InputDecoration(
              labelText: '서버 주소 (Base URL)',
              hintText: 'https://api.openai.com/v1',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _modelController,
            decoration: const InputDecoration(
              labelText: '모델 이름',
              hintText: 'gpt-4o-mini',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _apiKeyController,
            obscureText: _obscureKey,
            decoration: InputDecoration(
              labelText: 'API 키 (로컬 서버는 비워 두기)',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscureKey ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscureKey = !_obscureKey),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '외부로 전송되는 것은 설문 요청 문장뿐이며, 학생 응답 데이터는 전송되지 않습니다. '
            'API 키는 이 기기의 앱 데이터 폴더에만 저장됩니다.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }
}
