import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_button.dart';
import '../../widgets/gs_text_field.dart';
import '../../widgets/gs_toast.dart';
import '../../router/app_router.dart';
import '../../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;
  bool _termsAccepted = false;
  bool _showPassword = false;

  late final TapGestureRecognizer _termsTap;
  late final TapGestureRecognizer _privacyTap;

  @override
  void initState() {
    super.initState();
    _termsTap = TapGestureRecognizer()
      ..onTap = () => ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Próximamente')));
    _privacyTap = TapGestureRecognizer()
      ..onTap = () => ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Próximamente')));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Debes aceptar los términos para continuar')),
      );
      return;
    }
    setState(() => _isLoading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await authService.signUp(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
        name: _nameCtrl.text.trim(),
        consentGeo: false,
        consentAi: false,
      );
      // GoRouter auto-redirects after successful signup via auth stream
    } catch (e) {
      GSToast.showWithMessenger(messenger,
          message: 'Error: ${e.toString()}', type: GSToastType.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(GSSpacing.s6),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Back button ──────────────────────────────────────────
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: GSColors.textPrimary),
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go(AppRoutes.login);
                        }
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: GSSize.touchTarget,
                        minHeight: GSSize.touchTarget,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: GSSpacing.s4),

                // ── Heading ──────────────────────────────────────────────
                Text(
                  'Crear cuenta',
                  style: tt.displayMedium?.copyWith(
                    color: GSColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: GSSpacing.s2),
                Text(
                  'Únete a GoSmart hoy',
                  style: tt.bodyLarge?.copyWith(
                    color: GSColors.textSecondary,
                  ),
                ),

                const SizedBox(height: GSSpacing.s8),

                // ── Fields ───────────────────────────────────────────────
                GSTextField(
                  hint: 'Nombre completo',
                  label: 'Nombre',
                  controller: _nameCtrl,
                  keyboardType: TextInputType.name,
                  prefixIcon: Icons.person_outline_rounded,
                  textCapitalization: TextCapitalization.words,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty)
                          ? 'Nombre es requerido'
                          : null,
                ),

                const SizedBox(height: GSSpacing.s3),

                GSTextField(
                  hint: '+57 300 000 0000',
                  label: 'Teléfono',
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  prefixIcon: Icons.phone_android_rounded,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),

                const SizedBox(height: GSSpacing.s3),

                GSTextField(
                  hint: 'correo@ejemplo.com',
                  label: 'Correo',
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.email_outlined,
                  validator: (v) =>
                      (v == null || !v.contains('@'))
                          ? 'Correo inválido'
                          : null,
                ),

                const SizedBox(height: GSSpacing.s3),

                GSTextField(
                  hint: '••••••••',
                  label: 'Contraseña',
                  controller: _passCtrl,
                  obscureText: !_showPassword,
                  prefixIcon: Icons.lock_outline_rounded,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showPassword
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: GSColors.textSecondary,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
                  ),
                  validator: (v) =>
                      (v == null || v.length < 8)
                          ? 'Mínimo 8 caracteres'
                          : null,
                ),

                const SizedBox(height: GSSpacing.s4),

                // ── Terms checkbox ───────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _termsAccepted,
                        onChanged: (v) =>
                            setState(() => _termsAccepted = v ?? false),
                        activeColor: GSColors.accent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    const SizedBox(width: GSSpacing.s3),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            color: GSColors.textSecondary,
                            fontSize: 13,
                            height: 1.4,
                          ),
                          children: [
                            const TextSpan(text: 'Acepto los '),
                            TextSpan(
                              text: 'Términos',
                              style: const TextStyle(
                                color: GSColors.accent,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                                decorationColor: GSColors.accent,
                              ),
                              recognizer: _termsTap,
                            ),
                            const TextSpan(text: ' y la '),
                            TextSpan(
                              text: 'Política de Privacidad',
                              style: const TextStyle(
                                color: GSColors.accent,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                                decorationColor: GSColors.accent,
                              ),
                              recognizer: _privacyTap,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: GSSpacing.s6),

                // ── Submit button ────────────────────────────────────────
                GSButton(
                  label: 'Crear cuenta',
                  onPressed: _termsAccepted ? _submit : null,
                  isLoading: _isLoading,
                  leadingIcon: Icons.person_add_rounded,
                ),

                const SizedBox(height: GSSpacing.s6),

                // ── Sign in link ─────────────────────────────────────────
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '¿Ya tienes cuenta? ',
                        style: tt.bodyMedium?.copyWith(
                          color: GSColors.textSecondary,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.go(AppRoutes.login),
                        style: TextButton.styleFrom(
                          foregroundColor: GSColors.accent,
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: const Text('Inicia sesión'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: GSSpacing.s4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
