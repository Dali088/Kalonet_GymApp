import 'package:flutter/material.dart';

import '../theme/kalonet_colors.dart';
import '../theme/kalonet_tokens.dart';

final class KalonetSurface extends StatelessWidget {
  const KalonetSurface({
    required this.child,
    this.padding = const EdgeInsets.all(KalonetSpacing.md),
    this.accent,
    this.gradient,
    this.margin = EdgeInsets.zero,
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? accent;
  final Gradient? gradient;
  final EdgeInsetsGeometry margin;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final content = DecoratedBox(
      decoration: BoxDecoration(
        color: gradient == null ? KalonetColors.surfaceGlass : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(KalonetRadii.lg),
        border: Border.all(color: accent ?? KalonetColors.borderPale),
      ),
      child: Padding(padding: padding, child: child),
    );

    return Padding(
      padding: margin,
      child: semanticLabel == null
          ? content
          : Semantics(container: true, label: semanticLabel, child: content),
    );
  }
}

final class KalonetSectionHeader extends StatelessWidget {
  const KalonetSectionHeader({
    required this.title,
    this.subtitle,
    this.action,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: KalonetSpacing.xxs),
                Text(subtitle!, style: theme.textTheme.bodySmall),
              ],
            ],
          ),
        ),
        ...?action == null ? null : <Widget>[action!],
      ],
    );
  }
}

final class KalonetMetricTile extends StatelessWidget {
  const KalonetMetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
    this.color = KalonetColors.primary,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return KalonetSurface(
      semanticLabel: '$label, $value, $detail',
      padding: const EdgeInsets.all(KalonetSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(child: Icon(icon, color: color, size: 20)),
          const SizedBox(height: KalonetSpacing.xs),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: KalonetSpacing.xxs),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
          Text(detail, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

final class KalonetProgressBar extends StatelessWidget {
  const KalonetProgressBar({
    required this.value,
    this.color = KalonetColors.primary,
    this.height = 8,
    this.label,
    super.key,
  });

  final double value;
  final Color color;
  final double height;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final progress = value.clamp(0.0, 1.0).toDouble();
    return Semantics(
      label: label,
      value: '${(progress * 100).round()} percent',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(KalonetRadii.pill),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: progress),
          duration: KalonetMotion.resolve(context, KalonetMotion.standard),
          curve: KalonetMotion.curve,
          builder: (context, animated, child) => LinearProgressIndicator(
            value: animated,
            minHeight: height,
            color: color,
            backgroundColor: KalonetColors.border,
          ),
        ),
      ),
    );
  }
}

final class KalonetProgressRing extends StatelessWidget {
  const KalonetProgressRing({
    required this.value,
    required this.label,
    this.color = KalonetColors.primary,
    this.size = 84,
    super.key,
  });

  final double value;
  final String label;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final progress = value.clamp(0.0, 1.0).toDouble();
    return Semantics(
      label: 'Progress',
      value: '$label, ${(progress * 100).round()} percent',
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: progress),
        duration: KalonetMotion.resolve(context, KalonetMotion.slow),
        curve: KalonetMotion.curve,
        builder: (context, animated, child) => SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: animated,
                strokeWidth: 7,
                color: color,
                backgroundColor: KalonetColors.border,
              ),
              Text(label, style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
        ),
      ),
    );
  }
}

final class KalonetStatePanel extends StatelessWidget {
  const KalonetStatePanel.loading({this.message = 'Loading...', super.key})
    : error = null,
      onRetry = null;

  const KalonetStatePanel.error({
    required this.error,
    required this.onRetry,
    super.key,
  }) : message = null;

  final String? message;
  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final isLoading = error == null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(KalonetSpacing.lg),
        child: KalonetSurface(
          semanticLabel: isLoading ? message : error,
          padding: const EdgeInsets.all(KalonetSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                const CircularProgressIndicator()
              else
                const ExcludeSemantics(
                  child: Icon(Icons.cloud_off, color: KalonetColors.warning),
                ),
              const SizedBox(height: KalonetSpacing.md),
              Text(isLoading ? message! : error!, textAlign: TextAlign.center),
              if (!isLoading) ...[
                const SizedBox(height: KalonetSpacing.md),
                OutlinedButton(
                  onPressed: onRetry,
                  child: const Text('Try again'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

final class KalonetEmptyState extends StatelessWidget {
  const KalonetEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return KalonetSurface(
      semanticLabel: '$title. $message',
      padding: const EdgeInsets.all(KalonetSpacing.lg),
      child: Column(
        children: [
          ExcludeSemantics(
            child: Icon(icon, size: 40, color: KalonetColors.primaryBright),
          ),
          const SizedBox(height: KalonetSpacing.sm),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: KalonetSpacing.xs),
          Text(message, textAlign: TextAlign.center),
          if (action != null) ...[
            const SizedBox(height: KalonetSpacing.md),
            action!,
          ],
        ],
      ),
    );
  }
}
