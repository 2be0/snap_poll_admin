import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/poll.dart';
import '../providers/poll_provider.dart';
import '../widgets/qr_code_widget.dart';

/// 설문 퍼블리시/비공개 전환 및 QR 코드를 통한 응답 링크 공유 페이지.
class PublishPage extends StatelessWidget {
  final Poll poll;

  const PublishPage({super.key, required this.poll});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PollProvider>();
    // 최신 상태 반영을 위해 provider가 들고 있는 Poll을 다시 조회
    final current = provider.polls.firstWhere(
      (p) => p.id == poll.id,
      orElse: () => poll,
    );
    final url = provider.getPollUrl(current.id);

    return Scaffold(
      appBar: AppBar(title: const Text('퍼블리시 / QR 공유')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(current.title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            _StatusChip(isPublished: current.isPublished),
            const SizedBox(height: 24),
            SwitchListTile(
              title: const Text('설문 공개 (퍼블리시)'),
              subtitle: const Text('공개하면 같은 네트워크의 누구나 응답할 수 있습니다'),
              value: current.isPublished,
              onChanged: (v) {
                if (v) {
                  provider.publishPoll(current.id);
                } else {
                  provider.unpublishPoll(current.id);
                }
              },
            ),
            const SizedBox(height: 24),
            if (current.isPublished) ...[
              QrCodeWidget(data: url),
              const SizedBox(height: 16),
              SelectableText(url, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => launchUrl(Uri.parse(url)),
                icon: const Icon(Icons.open_in_browser),
                label: const Text('브라우저에서 열기'),
              ),
            ] else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  '설문을 공개하면 QR 코드와 응답 링크가 표시됩니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool isPublished;

  const _StatusChip({required this.isPublished});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(isPublished ? '공개 중' : '비공개'),
      backgroundColor: isPublished
          ? Colors.green.withValues(alpha: 0.15)
          : Colors.grey.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: isPublished ? Colors.green.shade800 : Colors.grey.shade700,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
