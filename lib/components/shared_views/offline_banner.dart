import 'package:flutter/material.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1F00),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF5A3F00), width: 1),
      ),
      child: const Row(
        children: [
          Icon(Icons.wifi_off_rounded, size: 14, color: Color(0xFFFFB300)),
          SizedBox(width: 8),
          Text(
            'You are currently offline. Functionality is limited.',
            style: TextStyle(
              color: Color(0xFFFFB300),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              overflow: TextOverflow.fade,
            ),
          ),
        ],
      ),
    );
  }
}
