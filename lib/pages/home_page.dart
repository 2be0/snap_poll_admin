import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/poll.dart';
import '../providers/poll_provider.dart';
import 'create_edit_poll_page.dart';
import 'llm_settings_page.dart';
import 'publish_page.dart';
import 'report_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PollProvider>();
    final polls = provider.polls;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Snap Poll - 관리자'),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome_outlined),
            tooltip: 'AI 설정',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LlmSettingsPage()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: '보고서',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ReportPage()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _ServerInfoBanner(baseUrl: provider.baseUrl),
          Expanded(
            child: polls.isEmpty
                ? const _EmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: polls.length,
                    itemBuilder: (context, index) => _PollListTile(poll: polls[index]),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CreateEditPollPage()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('새 설문'),
      ),
    );
  }
}

class _ServerInfoBanner extends StatelessWidget {
  final String baseUrl;

  const _ServerInfoBanner({required this.baseUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.indigo.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.wifi, size: 16, color: Colors.indigo),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '로컬 서버 주소: $baseUrl',
              style: const TextStyle(fontSize: 12, color: Colors.indigo),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.poll_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 12),
          Text('아직 생성된 설문이 없습니다', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class _PollListTile extends StatelessWidget {
  final Poll poll;

  const _PollListTile({required this.poll});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<PollProvider>();
    final responseCount = provider.getResponses(poll.id).length;

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
                  child: Text(poll.title,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ),
                Chip(
                  label: Text(poll.isPublished ? '공개 중' : '비공개'),
                  backgroundColor: poll.isPublished
                      ? Colors.green.withValues(alpha: 0.15)
                      : Colors.grey.withValues(alpha: 0.15),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: poll.isPublished ? Colors.green.shade800 : Colors.grey.shade700,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            if (poll.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(poll.description,
                  style: TextStyle(color: Colors.grey.shade600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.list_alt, size: 16, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text('${poll.questions.length}개 문항'),
                const SizedBox(width: 16),
                Icon(Icons.people_outline, size: 16, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text('$responseCount건 응답'),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CreateEditPollPage(editingPoll: poll),
                    ),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('편집'),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => PublishPage(poll: poll)),
                  ),
                  icon: const Icon(Icons.qr_code, size: 18),
                  label: const Text('퍼블리시'),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ReportPage(initialPollId: poll.id),
                    ),
                  ),
                  icon: const Icon(Icons.bar_chart, size: 18),
                  label: const Text('결과 보기'),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: () => _confirmDelete(context, provider, poll),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, PollProvider provider, Poll poll) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('설문 삭제'),
        content: Text('\'${poll.title}\' 설문을 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          TextButton(
            onPressed: () {
              provider.deletePoll(poll.id);
              Navigator.pop(ctx);
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
