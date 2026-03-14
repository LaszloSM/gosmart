// lib/widgets/gs_empty_state.dart
import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import 'gs_button.dart';

/// Reusable empty state with icon, message, and optional CTA.
class GSEmptyState extends StatelessWidget {
  const GSEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(GSSpacing.s8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: GSColors.accentLight,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: GSColors.accent),
            ),
            const SizedBox(height: GSSpacing.s4),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: GSSpacing.s2),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: GSSpacing.s6),
              GSButton(
                label: actionLabel!,
                onPressed: onAction,
                isFullWidth: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Reusable error card with retry button.
class GSErrorCard extends StatelessWidget {
  const GSErrorCard({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(GSSpacing.s8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: GSColors.errorLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded,
                  size: 36, color: GSColors.error),
            ),
            const SizedBox(height: GSSpacing.s4),
            Text(
              'Algo salió mal',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: GSSpacing.s2),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: GSSpacing.s6),
            GSButton(
              label: 'Reintentar',
              onPressed: onRetry,
              isFullWidth: false,
              leadingIcon: Icons.refresh_rounded,
            ),
          ],
        ),
      ),
    );
  }
}
