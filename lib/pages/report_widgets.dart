import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/poll.dart';
import '../models/question.dart';

class SummaryRow extends StatelessWidget {
  final Poll poll;
  final int responseCount;

  const SummaryRow({super.key, required this.poll, required this.responseCount});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _StatCard(label: '문항 수', value: '${poll.questions.length}')),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(label: '응답 수', value: '$responseCount')),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(label: '상태', value: poll.isPublished ? '공개 중' : '비공개'),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

/// 문항 하나에 대한 응답 집계 및 시각화.
class QuestionReport extends StatelessWidget {
  final Question question;
  final List<PollResponse> responses;

  const QuestionReport({super.key, required this.question, required this.responses});

  Map<String, int> _tally() {
    final counts = <String, int>{};
    for (final r in responses) {
      final answer = r.answers[question.id];
      if (answer == null) continue;
      if (answer is List) {
        for (final a in answer) {
          counts[a.toString()] = (counts[a.toString()] ?? 0) + 1;
        }
      } else {
        counts[answer.toString()] = (counts[answer.toString()] ?? 0) + 1;
      }
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final counts = _tally();
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(question.text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            Text(QuestionType.label(question.type),
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            const SizedBox(height: 16),
            if (question.type == QuestionType.text)
              _TextAnswerList(question: question, responses: responses)
            else if (counts.isEmpty)
              const Text('응답 없음', style: TextStyle(color: Colors.grey))
            else if (question.type == QuestionType.radio)
              _PieChartView(counts: counts)
            else
              _BarChartView(counts: counts),
          ],
        ),
      ),
    );
  }
}

/// 단일 선택(radio) 문항의 응답 비율을 파이차트로 표시한다.
class _PieChartView extends StatelessWidget {
  final Map<String, int> counts;

  const _PieChartView({required this.counts});

  static const List<Color> _palette = [
    Colors.blue,
    Colors.orange,
    Colors.green,
    Colors.purple,
    Colors.red,
    Colors.teal,
    Colors.brown,
    Colors.pink,
  ];

  @override
  Widget build(BuildContext context) {
    final entries = counts.entries.toList();
    final total = entries.fold<int>(0, (sum, e) => sum + e.value);

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: [
                for (var i = 0; i < entries.length; i++)
                  PieChartSectionData(
                    value: entries[i].value.toDouble(),
                    color: _palette[i % _palette.length],
                    title:
                        '${(entries[i].value / total * 100).round()}%',
                    radius: 70,
                    titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < entries.length; i++)
              _LegendItem(
                color: _palette[i % _palette.length],
                label: '${entries[i].key} (${entries[i].value})',
              ),
          ],
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _BarChartView extends StatelessWidget {
  final Map<String, int> counts;

  const _BarChartView({required this.counts});

  @override
  Widget build(BuildContext context) {
    final entries = counts.entries.toList();
    final maxCount = entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          maxY: (maxCount + 1).toDouble(),
          barGroups: [
            for (var i = 0; i < entries.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: entries[i].value.toDouble(),
                    color: Colors.blue,
                    width: 22,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
          ],
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 28),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= entries.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      entries[idx].key,
                      style: const TextStyle(fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: true, drawVerticalLine: false),
        ),
      ),
    );
  }
}

class _TextAnswerList extends StatelessWidget {
  final Question question;
  final List<PollResponse> responses;

  const _TextAnswerList({required this.question, required this.responses});

  @override
  Widget build(BuildContext context) {
    final answers = responses
        .map((r) => r.answers[question.id]?.toString())
        .where((a) => a != null && a.isNotEmpty)
        .toList();

    if (answers.isEmpty) {
      return const Text('응답 없음', style: TextStyle(color: Colors.grey));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: answers
          .map((a) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(a!),
                ),
              ))
          .toList(),
    );
  }
}
