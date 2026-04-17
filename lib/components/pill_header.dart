// ignore_for_file: deprecated_member_use

// apple-like header that has a pill on the left to close
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

class PillHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;

  const PillHeader({super.key, required this.title, this.onBack});

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;

    return SizedBox(
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            title,
            style: context.theme.typography.xl.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.foreground,
            ),
          ),
          Positioned(
            left: 16,
            child: GestureDetector(
              onTap:
                  onBack ??
                  () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      // go home
                      context.go('/');
                    }
                  },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.border),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      color: colors.background.withOpacity(0.8),
                      child: Icon(
                        FIcons.chevronLeft,
                        size: 20,
                        color: colors.foreground,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
