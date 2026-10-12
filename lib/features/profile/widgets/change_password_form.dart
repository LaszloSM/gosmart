// lib/features/profile/widgets/change_password_form.dart
import 'package:flutter/material.dart';

import '../../../theme/design_tokens.dart';
import '../../../widgets/gs_button.dart';
import '../../../widgets/gs_text_field.dart';

class ChangePasswordForm extends StatefulWidget {
  const ChangePasswordForm({
    super.key,
    required this.newPassCtrl,
    required this.confirmPassCtrl,
    required this.onSave,
  });

  final TextEditingController newPassCtrl;
  final TextEditingController confirmPassCtrl;
  final Future<void> Function() onSave;

  @override
  State<ChangePasswordForm> createState() => _ChangePasswordFormState();
}

class _ChangePasswordFormState extends State<ChangePasswordForm> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    final eye = IconButton(
      tooltip: _visible ? 'Ocultar contraseña' : 'Mostrar contraseña',
      icon: Icon(
        _visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        color: GSColors.textMuted,
      ),
      onPressed: () => setState(() => _visible = !_visible),
    );

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GSTextField(
            label: 'Contraseña nueva',
            hint: 'Mínimo 8 caracteres',
            controller: widget.newPassCtrl,
            prefixIcon: Icons.lock_outline_rounded,
            suffixIcon: eye,
            obscureText: !_visible,
            validator: (v) => (v == null || v.length < 8)
                ? 'Usa al menos 8 caracteres'
                : null,
          ),
          const SizedBox(height: GSSpacing.s4),
          GSTextField(
            label: 'Repite la contraseña',
            hint: 'Igual a la de arriba',
            controller: widget.confirmPassCtrl,
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: !_visible,
            validator: (v) => v != widget.newPassCtrl.text
                ? 'No coincide con la contraseña nueva'
                : null,
          ),
          const SizedBox(height: GSSpacing.s6),
          GSButton(
            label: 'Cambiar contraseña',
            isLoading: _isLoading,
            onPressed: () async {
              if (!_formKey.currentState!.validate()) return;
              setState(() => _isLoading = true);
              try {
                await widget.onSave();
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
          ),
        ],
      ),
    );
  }
}
