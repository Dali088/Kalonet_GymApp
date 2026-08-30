import 'package:flutter/material.dart';

import '../theme/kalonet_colors.dart';
import '../theme/kalonet_tokens.dart';
import 'kalonet_brand_mark.dart';

/// Shared auth background. Form state and submission remain owned by each
/// feature page; this widget only gives those pages a consistent visual frame.
final class KalonetAuthScaffold extends StatelessWidget {
  const KalonetAuthScaffold({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: KalonetGradients.page),
        child: Stack(
          children: [
            Positioned.fill(child: _AuthAmbient()),
            Positioned.fill(child: child),
          ],
        ),
      ),
    );
  }
}

final class _AuthAmbient extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) return const SizedBox.shrink();
        return Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: KalonetSpacing.section),
            child: SizedBox(
              width: 280,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const KalonetBrandMark(size: 76),
                  const SizedBox(height: KalonetSpacing.lg),
                  Text(
                    'Train with intention.',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: KalonetSpacing.sm),
                  const Text(
                    'One calm place for the meals, movement, and momentum that make your day count.',
                    style: TextStyle(color: KalonetColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
