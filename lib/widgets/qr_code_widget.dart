import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// 주어진 문자열(URL 등)을 QR 코드로 렌더링하는 위젯.
class QrCodeWidget extends StatelessWidget {
  final String data;
  final double size;

  const QrCodeWidget({super.key, required this.data, this.size = 240});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
          ),
        ],
      ),
      child: QrImageView(
        data: data,
        version: QrVersions.auto,
        size: size,
        gapless: true,
      ),
    );
  }
}
