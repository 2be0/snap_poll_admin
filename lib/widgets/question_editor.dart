import 'package:flutter/material.dart';

import '../models/question.dart';

/// 설문 생성/편집 화면에서 문항 하나를 편집하는 카드형 위젯.
class QuestionEditor extends StatefulWidget {
  final Question question;
  final VoidCallback onRemove;
  final ValueChanged<Question> onChanged;

  const QuestionEditor({
    super.key,
    required this.question,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  State<QuestionEditor> createState() => _QuestionEditorState();
}

class _QuestionEditorState extends State<QuestionEditor> {
  late TextEditingController _textController;
  late TextEditingController _optionController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.question.text);
    _optionController = TextEditingController();
  }

  @override
  void dispose() {
    _textController.dispose();
    _optionController.dispose();
    super.dispose();
  }

  void _emitChange() => widget.onChanged(widget.question);

  void _addOption() {
    final value = _optionController.text.trim();
    if (value.isEmpty) return;
    setState(() {
      widget.question.options.add(value);
      _optionController.clear();
    });
    _emitChange();
  }

  void _removeOption(int index) {
    setState(() => widget.question.options.removeAt(index));
    _emitChange();
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      labelText: '질문 내용',
                      isDense: true,
                    ),
                    onChanged: (v) {
                      q.text = v;
                      _emitChange();
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: widget.onRemove,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: q.type,
                    decoration: const InputDecoration(
                      labelText: '유형',
                      isDense: true,
                    ),
                    items: QuestionType.all
                        .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(QuestionType.label(t)),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => q.type = v);
                      _emitChange();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Row(
                  children: [
                    Checkbox(
                      value: q.required,
                      onChanged: (v) {
                        setState(() => q.required = v ?? false);
                        _emitChange();
                      },
                    ),
                    const Text('필수'),
                  ],
                ),
              ],
            ),
            if (q.hasOptions) ...[
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('선택 옵션', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 4),
              ...q.options.asMap().entries.map(
                    (entry) => _OptionRow(
                      label: entry.value,
                      onRemove: () => _removeOption(entry.key),
                    ),
                  ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _optionController,
                      decoration: const InputDecoration(
                        hintText: '옵션 추가',
                        isDense: true,
                      ),
                      onSubmitted: (_) => _addOption(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: _addOption,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _OptionRow({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 8, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: onRemove,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
