// lib/features/wallet/widgets/inline_error.dart
import 'package:flutter/material.dart';

import '../../../theme/design_tokens.dart';

/// Error en línea: mensaje + "Reintentar". Sin caja roja (DESIGN.md).
class InlineError extends StatelessWidget {
  const InlineError({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.error_outline_rounded, color: GSColors.roadClosed),
        const SizedBox(width: GSSpacing.s2),
        Expanded(
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Reintentar')),
      ],
    );
  }
}
