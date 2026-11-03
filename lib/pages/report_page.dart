import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/poll_provider.dart';
import 'report_widgets.dart';

/// 진행/완료 설문의 응답 결과를 시각적으로 보여주는 보고서 페이지.
/// [initialPollId]가 주어지면 해당 설문을 기본 선택 상태로 연다.
class ReportPage extends StatefulWidget {
  final String? initialPollId;

  const ReportPage({super.key, this.initialPollId});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  late String? _selectedPollId = widget.initialPollId;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PollProvider>();
    final polls = provider.polls;

    if (polls.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('보고서')),
        body: const Center(child: Text('설문 데이터가 없습니다')),
      );
    }

    final selected = polls.firstWhere(
      (p) => p.id == _selectedPollId,
      orElse: () => polls.first,
    );
    final responses = provider.getResponses(selected.id);

    return Scaffold(
      appBar: AppBar(title: const Text('보고서')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            value: selected.id,
            decoration: const InputDecoration(
              labelText: '설문 선택',
              border: OutlineInputBorder(),
            ),
            items: polls
                .map((p) => DropdownMenuItem(value: p.id, child: Text(p.title)))
                .toList(),
            onChanged: (v) => setState(() => _selectedPollId = v),
          ),
          const SizedBox(height: 16),
          SummaryRow(poll: selected, responseCount: responses.length),
          const SizedBox(height: 24),
          if (responses.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text('아직 응답이 없습니다', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ...selected.questions.map(
              (q) => QuestionReport(question: q, responses: responses),
            ),
        ],
      ),
    );
  }
}
