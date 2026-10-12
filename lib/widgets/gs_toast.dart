import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

enum GSToastType { success, error, warning, info }

/// Aviso pasajero (snackbar de Material, como pide Android): fondo tinta,
/// texto blanco y un ícono que nombra el tipo. El error no usa rojo de
/// relleno; el ícono lleva un rojo claro legible sobre la tinta.
class GSToast {
  static void show(
    BuildContext context, {
    required String message,
    GSToastType type = GSToastType.info,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    showWithMessenger(
      ScaffoldMessenger.of(context),
      message: message,
      type: type,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// Para callbacks asíncronos: captura `ScaffoldMessenger.of(context)`
  /// antes del await y llama esto después.
  static void showWithMessenger(
    ScaffoldMessengerState messenger, {
    required String message,
    GSToastType type = GSToastType.info,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final (icon, iconColor) = switch (type) {
      GSToastType.success => (Icons.check_circle_rounded, GSColors.onBrand),
      GSToastType.error => (Icons.error_rounded, const Color(0xFFFFB4A9)),
      GSToastType.warning => (Icons.warning_rounded, const Color(0xFFFFD48A)),
      GSToastType.info => (Icons.info_rounded, GSColors.onBrandMuted),
    };
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: GSSpacing.s3),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontFamily: GSFonts.sans,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: GSColors.onBrand,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: GSColors.text,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GSRadius.md),
          ),
          margin: const EdgeInsets.all(GSSpacing.s4),
          duration: duration,
          action: actionLabel != null
              ? SnackBarAction(
                  label: actionLabel,
                  textColor: GSColors.onBrandMuted,
                  onPressed: onAction ?? () {},
                )
              : null,
        ),
      );
  }
}
