// lib/widgets/gs_empty_state.dart
import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import 'gs_button.dart';
import 'gs_route_plate.dart';

/// Estado vacío: una placa en blanco (todavía sin destino pintado), una
/// frase que dice cómo llenarla y, si aplica, la acción que la llena.
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
    return Padding(
      padding: const EdgeInsets.all(GSSpacing.s4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GSRoutePlate(text: title, leading: icon, isPlaceholder: true),
          if (subtitle != null) ...[
            const SizedBox(height: GSSpacing.s3),
            Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: GSSpacing.s4),
            GSButton(label: actionLabel!, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}
