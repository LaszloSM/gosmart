// lib/features/auth/register_screen.dart
// Crear cuenta con correo. El tratamiento de datos (Ley 1581) se acepta de
// forma explícita; ubicación y asistente son consentimientos aparte y
// opcionales, y se guardan en el perfil (consent_geo, consent_ai_data).
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth_errors.dart';
import '../../router/app_router.dart';
import '../../services/auth_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_button.dart';
import '../../widgets/gs_text_field.dart';
import '../../widgets/gs_toast.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;
  bool _dataConsent = false;
  bool _geoConsent = true;
  bool _aiConsent = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final res = await authService.signUp(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
        name: _nameCtrl.text.trim(),
        consentGeo: _geoConsent,
        consentAi: _aiConsent,
      );
      // Con confirmación de correo activa no hay sesión todavía.
      if (res.session == null) {
        GSToast.showWithMessenger(messenger,
            message: 'Te enviamos un correo para confirmar tu cuenta.',
            type: GSToastType.success,
            duration: const Duration(seconds: 5));
      }
      // Con sesión, el router lleva al inicio solo.
    } catch (e) {
      GSToast.showWithMessenger(messenger,
          message: friendlyAuthError(e), type: GSToastType.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: GSColors.background,
      appBar: AppBar(
        title: const Text('Crear cuenta'),
        leading: IconButton(
          tooltip: 'Volver',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(AppRoutes.login),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(GSSpacing.s4),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GSTextField(
                  label: 'Nombre',
                  hint: 'Como quieres que te llamen',
                  controller: _nameCtrl,
                  keyboardType: TextInputType.name,
                  prefixIcon: Icons.person_rounded,
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Escribe tu nombre'
                      : null,
                ),
                const SizedBox(height: GSSpacing.s4),
                GSTextField(
                  label: 'Correo',
                  hint: 'tucorreo@ejemplo.com',
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.mail_rounded,
                  validator: (v) => (v == null || !v.contains('@'))
                      ? 'Ingresa un correo válido'
                      : null,
                ),
                const SizedBox(height: GSSpacing.s4),
                GSTextField(
                  label: 'Contraseña',
                  hint: 'Mínimo 8 caracteres',
                  controller: _passCtrl,
                  obscureText: !_showPassword,
                  prefixIcon: Icons.lock_rounded,
                  suffixIcon: IconButton(
                    tooltip: _showPassword
                        ? 'Ocultar contraseña'
                        : 'Mostrar contraseña',
                    icon: Icon(_showPassword
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded),
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
                  ),
                  validator: (v) => (v == null || v.length < 8)
                      ? 'Usa al menos 8 caracteres'
                      : null,
                ),
                const SizedBox(height: GSSpacing.s6),
                Text('Tus datos', style: text.titleLarge),
                const SizedBox(height: GSSpacing.s2),
                _ConsentTile(
                  value: _dataConsent,
                  onChanged: (v) => setState(() => _dataConsent = v),
                  title: 'Autorizo el tratamiento de mis datos personales',
                  subtitle: 'Obligatorio (Ley 1581). Los usamos solo para tu '
                      'cuenta, tus viajes y tus pagos.',
                ),
                Wrap(
                  children: [
                    TextButton(
                      onPressed: () => context.push(AppRoutes.privacy),
                      child: const Text('Leer cómo usamos tus datos'),
                    ),
                    TextButton(
                      onPressed: () => context.push(AppRoutes.terms),
                      child: const Text('Leer los términos'),
                    ),
                  ],
                ),
                _ConsentTile(
                  value: _geoConsent,
                  onChanged: (v) => setState(() => _geoConsent = v),
                  title: 'Usar mi ubicación para planear rutas',
                  subtitle: 'Opcional. Puedes cambiarlo después.',
                ),
                _ConsentTile(
                  value: _aiConsent,
                  onChanged: (v) => setState(() => _aiConsent = v),
                  title: 'Usar mis preguntas para mejorar el asistente',
                  subtitle: 'Opcional.',
                ),
                const SizedBox(height: GSSpacing.s6),
                GSButton(
                  label: 'Crear cuenta',
                  semanticLabel: 'Crear cuenta y aceptar los términos de uso',
                  onPressed: _dataConsent ? _submit : null,
                  isLoading: _isLoading,
                ),
                const SizedBox(height: GSSpacing.s2),
                Text('Al crear tu cuenta aceptas los términos de uso.',
                    style: text.bodySmall, textAlign: TextAlign.center),
                if (!_dataConsent) ...[
                  const SizedBox(height: GSSpacing.s2),
                  Text(
                    'Marca la autorización de datos para continuar.',
                    style: text.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: GSSpacing.s4),
                TextButton(
                  onPressed: () => context.canPop()
                      ? context.pop()
                      : context.go(AppRoutes.login),
                  child: const Text('Ya tengo cuenta'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConsentTile extends StatelessWidget {
  const _ConsentTile({
    required this.value,
    required this.onChanged,
    required this.title,
    required this.subtitle,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: value,
      onChanged: (v) => onChanged(v ?? false),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }
}
