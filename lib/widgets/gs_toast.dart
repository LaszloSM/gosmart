import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

enum GSToastType { success, error, warning, info }

class GSToast {
  static void show(
    BuildContext context, {
    required String message,
    GSToastType type = GSToastType.info,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final colors = _typeColors(type);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(colors.icon, color: colors.iconColor, size: 20),
            const SizedBox(width: GSSpacing.s3),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: GSColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: colors.bg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GSRadius.md),
          side: BorderSide(color: colors.border, width: 1),
        ),
        margin: const EdgeInsets.all(GSSpacing.s4),
        duration: duration,
        action: actionLabel != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: colors.iconColor,
                onPressed: onAction ?? () {},
              )
            : null,
      ),
    );
  }

  /// Use this variant inside async callbacks to avoid BuildContext-across-gap
  /// lint warnings. Capture `ScaffoldMessenger.of(context)` before the await,
  /// then call this method afterward.
  static void showWithMessenger(
    ScaffoldMessengerState messenger, {
    required String message,
    GSToastType type = GSToastType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final colors = _typeColors(type);
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(colors.icon, color: colors.iconColor, size: 20),
            const SizedBox(width: GSSpacing.s3),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: GSColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: colors.bg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GSRadius.md),
          side: BorderSide(color: colors.border, width: 1),
        ),
        margin: const EdgeInsets.all(GSSpacing.s4),
        duration: duration,
      ),
    );
  }

  static _ToastColors _typeColors(GSToastType type) {
    switch (type) {
      case GSToastType.success:
        return const _ToastColors(
          bg: GSColors.successLight,
          border: GSColors.success,
          iconColor: GSColors.success,
          icon: Icons.check_circle_rounded,
        );
      case GSToastType.error:
        return const _ToastColors(
          bg: GSColors.errorLight,
          border: GSColors.error,
          iconColor: GSColors.error,
          icon: Icons.error_rounded,
        );
      case GSToastType.warning:
        return const _ToastColors(
          bg: GSColors.warningLight,
          border: GSColors.warning,
          iconColor: GSColors.warning,
          icon: Icons.warning_rounded,
        );
      case GSToastType.info:
        return const _ToastColors(
          bg: GSColors.infoLight,
          border: GSColors.info,
          iconColor: GSColors.info,
          icon: Icons.info_rounded,
        );
    }
  }
}

class _ToastColors {
  final Color bg;
  final Color border;
  final Color iconColor;
  final IconData icon;
  const _ToastColors({
    required this.bg,
    required this.border,
    required this.iconColor,
    required this.icon,
  });
}

// ─── Push notification banner (simulated) ────────────────────────────────────

class GSNotificationBanner extends StatelessWidget {
  const GSNotificationBanner({
    super.key,
    required this.title,
    required this.body,
    this.icon = Icons.notifications_rounded,
    this.onDismiss,
    this.onTap,
  });

  final String title;
  final String body;
  final IconData icon;
  final VoidCallback? onDismiss;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(GSSpacing.s4),
        padding: const EdgeInsets.all(GSSpacing.s4),
        decoration: BoxDecoration(
          color: GSColors.textPrimary,
          borderRadius: BorderRadius.circular(GSRadius.lg),
          boxShadow: GSShadow.lg,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: GSColors.accentLight,
                borderRadius: BorderRadius.circular(GSRadius.sm),
              ),
              child: Icon(icon, color: GSColors.primary, size: 20),
            ),
            const SizedBox(width: GSSpacing.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      )),
                  Text(body,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      )),
                ],
              ),
            ),
            if (onDismiss != null)
              GestureDetector(
                onTap: onDismiss,
                child: Icon(Icons.close,
                    color: Colors.white.withValues(alpha: 0.5), size: 18),
              ),
          ],
        ),
      ),
    );
  }
}
