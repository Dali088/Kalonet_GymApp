import 'package:flutter/material.dart';

import '../theme/kalonet_colors.dart';

final class KalonetBrandMark extends StatelessWidget {
  const KalonetBrandMark({this.size = 72, this.showGlow = true, super.key});

  final double size;
  final bool showGlow;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      'assets/brand/kalonet_progress_emblem.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => Icon(
        Icons.fitness_center,
        size: size * 0.55,
        color: KalonetColors.primaryBright,
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: KalonetColors.surfaceElevated,
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: KalonetColors.primary.withValues(alpha: 0.18),
                  blurRadius: size * 0.35,
                  spreadRadius: size * 0.04,
                ),
              ]
            : null,
      ),
      child: Padding(padding: EdgeInsets.all(size * 0.12), child: image),
    );
  }
}
