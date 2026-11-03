import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/poll.dart';
import '../models/question.dart';
import '../providers/poll_provider.dart';
import '../services/llm_settings.dart';
import '../services/poll_draft_generator.dart';
import '../widgets/question_editor.dart';
import 'llm_settings_page.dart';

/// 설문 생성과 편집을 겸하는 페이지. [editingPoll]이 null이면 생성 모드.
class CreateEditPollPage extends StatefulWidget {
  final Poll? editingPoll;

  const CreateEditPollPage({super.key, this.editingPoll});

  @override
  State<CreateEditPollPage> createState() => _CreateEditPollPageState();
}

class _CreateEditPollPageState extends State<CreateEditPollPage> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  final TextEditingController _aiRequestController = TextEditingController();
  late List<Question> _questions;
  bool _generating = false;

  bool get _isEditing => widget.editingPoll != null;

  @override
  void initState() {
    super.initState();
    final poll = widget.editingPoll;
    _titleController = TextEditingController(text: poll?.title ?? '');
    _descController = TextEditingController(text: poll?.description ?? '');
    _questions = poll?.questions
            .map((q) => Question(
                  id: q.id,
                  text: q.text,
                  type: q.type,
                  options: List.of(q.options),
                  required: q.required,
                ))
            .toList() ??
        [];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _aiRequestController.dispose();
    super.dispose();
  }

  /// 자연어 요청으로 LLM 초안을 받아 제목/설명/문항을 채운다. 저장은 하지 않는다.
  Future<void> _generateDraft() async {
    final settings = context.read<LlmSettingsController>().settings;
    final generator = context.read<PollDraftGenerator>();
    setState(() => _generating = true);
    try {
      final draft = await generator.generate(_aiRequestController.text, settings);
      if (!mounted) return;
      final hasContent = _titleController.text.trim().isNotEmpty || _questions.isNotEmpty;
      if (hasContent && !await _confirmReplace()) return;
      setState(() {
        _titleController.text = draft.title;
        _descController.text = draft.description;
        _questions = draft.questions;
      });
      _showMessage('AI가 만든 초안입니다. 내용을 확인한 뒤 저장하세요.');
    } on PollDraftException catch (e) {
      if (mounted) _showMessage(e.message);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<bool> _confirmReplace() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('초안으로 바꾸기'),
        content: const Text('지금 입력한 제목과 문항을 AI 초안으로 바꿀까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('바꾸기')),
        ],
      ),
    );
    return result ?? false;
  }

  void _addQuestion() {
    setState(() {
      _questions.add(Question(
        id: 'q_${DateTime.now().microsecondsSinceEpoch}',
        text: '',
        type: QuestionType.radio,
        options: ['옵션 1', '옵션 2'],
      ));
    });
  }

  void _removeQuestion(int index) {
    setState(() => _questions.removeAt(index));
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showMessage('설문 제목을 입력하세요');
      return;
    }
    if (_questions.isEmpty) {
      _showMessage('최소 한 개 이상의 문항이 필요합니다');
      return;
    }
    for (final q in _questions) {
      if (q.text.trim().isEmpty) {
        _showMessage('모든 문항의 내용을 입력하세요');
        return;
      }
      if (q.hasOptions && q.options.length < 2) {
        _showMessage('선택형 문항은 옵션이 2개 이상 필요합니다 (${q.text})');
        return;
      }
    }

    final provider = context.read<PollProvider>();
    if (_isEditing) {
      final updated = Poll(
        id: widget.editingPoll!.id,
        title: title,
        description: _descController.text.trim(),
        createdAt: widget.editingPoll!.createdAt,
        isPublished: widget.editingPoll!.isPublished,
        publishedAt: widget.editingPoll!.publishedAt,
        questions: _questions,
        responses: widget.editingPoll!.responses,
      );
      provider.updatePoll(updated);
    } else {
      final poll = Poll(
        id: 'p_${DateTime.now().microsecondsSinceEpoch}',
        title: title,
        description: _descController.text.trim(),
        createdAt: DateTime.now(),
        questions: _questions,
      );
      provider.createPoll(poll);
    }
    Navigator.of(context).pop();
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? '설문 수정' : '새 설문 만들기')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 기존 설문(응답이 쌓였을 수 있는)의 문항을 통째로 바꾸지 않도록 생성 모드에서만 노출한다.
          if (!_isEditing) ...[
            _AiDraftCard(
              controller: _aiRequestController,
              generating: _generating,
              configured: context.watch<LlmSettingsController>().settings.isConfigured,
              onGenerate: _generateDraft,
            ),
            const SizedBox(height: 20),
          ],
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: '설문 제목',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: '설문 설명 (선택)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('문항 목록', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              TextButton.icon(
                onPressed: _addQuestion,
                icon: const Icon(Icons.add),
                label: const Text('문항 추가'),
              ),
            ],
          ),
          if (_questions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('아직 문항이 없습니다. 문항을 추가하세요.')),
            ),
          ..._questions.asMap().entries.map(
                (entry) => QuestionEditor(
                  key: ValueKey(entry.value.id),
                  question: entry.value,
                  onRemove: () => _removeQuestion(entry.key),
                  onChanged: (_) {},
                ),
              ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: Text(_isEditing ? '저장' : '설문 만들기'),
          ),
        ],
      ),
    );
  }
}

/// 자연어로 설문 초안을 요청하는 카드. LLM 설정이 없으면 설정 페이지로 안내한다.
class _AiDraftCard extends StatelessWidget {
  final TextEditingController controller;
  final bool generating;
  final bool configured;
  final VoidCallback onGenerate;

  const _AiDraftCard({
    required this.controller,
    required this.generating,
    required this.configured,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.primaryContainer.withValues(alpha: 0.35),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, size: 20, color: colors.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('어떤 설문을 만들까요?',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined, size: 20),
                  tooltip: 'AI 설정',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LlmSettingsPage()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              enabled: configured && !generating,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: '예) 중2 광합성 수업 이해도 확인. 객관식 4문항, 마지막엔 소감 주관식 하나',
                border: OutlineInputBorder(),
                filled: true,
              ),
            ),
            const SizedBox(height: 12),
            if (configured)
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: generating ? null : onGenerate,
                  icon: generating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome, size: 18),
                  label: Text(generating ? '초안 만드는 중…' : 'AI로 초안 만들기'),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: Text('AI 서버 설정이 필요합니다.',
                        style: TextStyle(color: Colors.grey.shade700)),
                  ),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LlmSettingsPage()),
                    ),
                    child: const Text('AI 설정 열기'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
