import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/poll.dart';
import '../models/question.dart';
import '../providers/poll_provider.dart';
import '../widgets/question_editor.dart';

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
  late List<Question> _questions;

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
    super.dispose();
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
