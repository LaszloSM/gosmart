// lib/features/profile/widgets/edit_personal_info_form.dart
// Formulario de datos personales. La cédula no se puede cambiar una vez
// guardada (ver CLAUDE.md → ProfileModel).
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../theme/design_tokens.dart';
import '../../../widgets/gs_button.dart';
import '../../../widgets/gs_text_field.dart';

class EditPersonalInfoForm extends StatefulWidget {
  const EditPersonalInfoForm({
    super.key,
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.cedulaCtrl,
    required this.cityCtrl,
    required this.onSave,
    required this.isCedulaLocked,
    this.initialBirthDate,
    this.onBirthDateChanged,
  });

  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController cedulaCtrl;
  final TextEditingController cityCtrl;

  /// true cuando la cédula ya está guardada: se muestra bloqueada.
  final bool isCedulaLocked;
  final DateTime? initialBirthDate;
  final ValueChanged<DateTime?>? onBirthDateChanged;
  final Future<void> Function() onSave;

  @override
  State<EditPersonalInfoForm> createState() => _EditPersonalInfoFormState();
}

class _EditPersonalInfoFormState extends State<EditPersonalInfoForm> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  DateTime? _birthDate;

  @override
  void initState() {
    super.initState();
    _birthDate = widget.initialBirthDate;
  }

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(1990),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      locale: const Locale('es', 'CO'),
      helpText: 'Fecha de nacimiento',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (picked != null) {
      setState(() => _birthDate = picked);
      widget.onBirthDateChanged?.call(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GSTextField(
            label: 'Nombre completo',
            hint: 'Como aparece en tu cédula',
            controller: widget.nameCtrl,
            prefixIcon: Icons.person_outline_rounded,
            keyboardType: TextInputType.name,
            textCapitalization: TextCapitalization.words,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Escribe tu nombre' : null,
          ),
          const SizedBox(height: GSSpacing.s4),
          GSTextField(
            label: 'Celular',
            hint: '300 000 0000',
            controller: widget.phoneCtrl,
            prefixIcon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: GSSpacing.s4),
          if (widget.isCedulaLocked)
            _ReadOnlyField(
              label: 'Cédula de ciudadanía',
              value: widget.cedulaCtrl.text,
              icon: Icons.lock_outline_rounded,
              helper: 'Ya está registrada y no se puede cambiar.',
            )
          else
            GSTextField(
              label: 'Cédula de ciudadanía',
              hint: 'Solo números',
              controller: widget.cedulaCtrl,
              prefixIcon: Icons.badge_outlined,
              keyboardType: TextInputType.number,
            ),
          const SizedBox(height: GSSpacing.s4),
          GSTextField(
            label: 'Ciudad donde vives',
            hint: 'Riohacha o Maicao',
            controller: widget.cityCtrl,
            prefixIcon: Icons.location_city_outlined,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: GSSpacing.s4),
          _TapField(
            label: 'Fecha de nacimiento',
            value: _birthDate != null
                ? DateFormat('dd/MM/yyyy').format(_birthDate!)
                : null,
            hint: 'Elegir fecha',
            icon: Icons.calendar_today_outlined,
            onTap: _pickBirthDate,
          ),
          const SizedBox(height: GSSpacing.s6),
          GSButton(
            label: 'Guardar cambios',
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

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: GSSpacing.s2),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: GSFonts.sans,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: GSColors.text,
        ),
      ),
    );
  }
}

/// Campo que abre un selector (fecha). Mismo aspecto que un GSTextField.
class _TapField extends StatelessWidget {
  const _TapField({
    required this.label,
    required this.value,
    required this.hint,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String? value;
  final String hint;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        Semantics(
          button: true,
          label: '$label: ${value ?? hint}',
          excludeSemantics: true,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(GSRadius.md),
            child: InputDecorator(
              decoration: InputDecoration(
                prefixIcon: Icon(icon, size: 22, color: GSColors.textMuted),
              ),
              child: Text(
                value ?? hint,
                style: TextStyle(
                  fontFamily: GSFonts.sans,
                  fontFeatures: GSFonts.tabular,
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  color: value != null ? GSColors.text : GSColors.textMuted,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({
    required this.label,
    required this.value,
    required this.icon,
    required this.helper,
  });

  final String label;
  final String value;
  final IconData icon;
  final String helper;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        InputDecorator(
          decoration: InputDecoration(
            filled: true,
            fillColor: GSColors.surfaceSunken,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(GSRadius.md),
              borderSide: BorderSide.none,
            ),
            prefixIcon: Icon(icon, size: 22, color: GSColors.textMuted),
            helperText: helper,
            helperStyle: TextStyle(
                fontFamily: GSFonts.sans, fontSize: 14, color: GSColors.textMuted),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontFamily: GSFonts.sans,
              fontFeatures: GSFonts.tabular,
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: GSColors.text,
            ),
          ),
        ),
      ],
    );
  }
}
