// lib/features/auth/login_screen.dart
// Entrar: con código por SMS al celular o con correo y contraseña. Se llega
// aquí desde el modo invitado al actuar (reportar, pedir, pagar), así que
// siempre hay forma de volver.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth_errors.dart';
import '../../router/app_router.dart';
import '../../services/auth_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_button.dart';
import '../../widgets/gs_text_field.dart';
import '../../widgets/gs_toast.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLoading = false;
  bool _useSms = true;
  bool _showPassword = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (_useSms) {
        final phone = normalizeColombianPhone(_phoneCtrl.text);
        await authService.sendOtp(phone);
        if (mounted) context.push(AppRoutes.smsVerify, extra: phone);
      } else {
        await authService.signInWithEmail(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
        // El router redirige solo cuando cambia la sesión.
      }
    } catch (e) {
      GSToast.showWithMessenger(messenger,
          message: friendlyAuthError(e), type: GSToastType.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final messenger = ScaffoldMessenger.of(context);
    final email = _emailCtrl.text.trim();
    if (!email.contains('@')) {
      GSToast.showWithMessenger(messenger,
          message: 'Escribe tu correo arriba y vuelve a tocar aquí.');
      return;
    }
    try {
      await authService.resetPassword(email);
      GSToast.showWithMessenger(messenger,
          message: 'Te enviamos un enlace a $email para crear una '
              'contraseña nueva.',
          type: GSToastType.success,
          duration: const Duration(seconds: 5));
    } catch (e) {
      GSToast.showWithMessenger(messenger,
          message: friendlyAuthError(e), type: GSToastType.error);
    }
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: GSColors.background,
      appBar: AppBar(
        title: const Text('Entra a GoSmart'),
        leading: IconButton(
          tooltip: 'Volver',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _close,
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
                Text(
                  'Con tu cuenta puedes reportar la vía, pedir mototaxi y '
                  'pagar tus viajes.',
                  style: text.bodyLarge,
                ),
                const SizedBox(height: GSSpacing.s6),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Celular')),
                    ButtonSegment(value: false, label: Text('Correo')),
                  ],
                  selected: {_useSms},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) =>
                      setState(() => _useSms = s.first),
                ),
                const SizedBox(height: GSSpacing.s6),
                if (_useSms)
                  GSTextField(
                    label: 'Número de celular',
                    hint: '300 123 4567',
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    prefixIcon: Icons.phone_android_rounded,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) => (v == null || v.length < 10)
                        ? 'Ingresa un número válido'
                        : null,
                  )
                else ...[
                  GSTextField(
                    label: 'Correo',
                    hint: 'tucorreo@ejemplo.com',
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.mail_outline_rounded,
                    validator: (v) => (v == null || !v.contains('@'))
                        ? 'Ingresa un correo válido'
                        : null,
                  ),
                  const SizedBox(height: GSSpacing.s4),
                  GSTextField(
                    label: 'Contraseña',
                    hint: 'Tu contraseña',
                    controller: _passwordCtrl,
                    obscureText: !_showPassword,
                    prefixIcon: Icons.lock_outline_rounded,
                    suffixIcon: IconButton(
                      tooltip: _showPassword
                          ? 'Ocultar contraseña'
                          : 'Mostrar contraseña',
                      icon: Icon(_showPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                    ),
                    validator: (v) => (v == null || v.length < 6)
                        ? 'Contraseña muy corta'
                        : null,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _resetPassword,
                      child: const Text('Olvidé mi contraseña'),
                    ),
                  ),
                ],
                const SizedBox(height: GSSpacing.s6),
                GSButton(
                  label: _useSms ? 'Enviar código' : 'Iniciar sesión',
                  onPressed: _submit,
                  isLoading: _isLoading,
                ),
                if (_useSms) ...[
                  const SizedBox(height: GSSpacing.s2),
                  Text(
                    'Te llega un SMS con un código de 6 números.',
                    style: text.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: GSSpacing.s8),
                const Divider(),
                const SizedBox(height: GSSpacing.s4),
                Text('¿Primera vez en GoSmart?',
                    style: text.titleMedium, textAlign: TextAlign.center),
                const SizedBox(height: GSSpacing.s3),
                GSButton(
                  label: 'Crear cuenta',
                  variant: GSButtonVariant.outline,
                  onPressed: () => context.push(AppRoutes.register),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
