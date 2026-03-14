import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_button.dart';
import '../../widgets/gs_text_field.dart';
import '../../widgets/gs_toast.dart';
import '../../router/app_router.dart';
import '../../services/auth_service.dart';

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
        await authService.sendOtp(_phoneCtrl.text.trim());
        if (mounted) {
          context.push(AppRoutes.smsVerify, extra: _phoneCtrl.text.trim());
        }
      } else {
        await authService.signInWithEmail(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
        // GoRouter auto-redirects when Supabase auth state changes.
        // No explicit navigation needed here.
      }
    } catch (e) {
      GSToast.showWithMessenger(
        messenger,
        message: 'Error: ${e.toString()}',
        type: GSToastType.error,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                const SizedBox(height: GSSpacing.s8),

                // ── Brand mark ─────────────────────────────────────────────
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: GSColors.accent,
                    borderRadius: BorderRadius.circular(GSRadius.lg),
                    boxShadow: GSShadow.accent,
                  ),
                  child: const Icon(
                    Icons.directions_transit_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(height: GSSpacing.s6),

                // ── Heading ────────────────────────────────────────────────
                Text(
                  'Bienvenido\nde nuevo',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        color: GSColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                ),
                const SizedBox(height: GSSpacing.s2),
                Text(
                  'Inicia sesión en tu cuenta GoSmart',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: GSColors.textSecondary,
                        fontWeight: FontWeight.w400,
                      ),
                ),
                const SizedBox(height: GSSpacing.s8),

                // ── Segmented toggle ───────────────────────────────────────
                Container(
                  height: 48,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: GSColors.surfaceDark,
                    borderRadius: BorderRadius.circular(GSRadius.full),
                    border: Border.all(color: GSColors.border, width: 1),
                  ),
                  child: Row(
                    children: [
                      _ToggleTab(
                        label: 'SMS OTP',
                        selected: _useSms,
                        onTap: () {
                          if (!_useSms) setState(() => _useSms = true);
                        },
                      ),
                      _ToggleTab(
                        label: 'Correo',
                        selected: !_useSms,
                        onTap: () {
                          if (_useSms) setState(() => _useSms = false);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: GSSpacing.s6),

                // ── Fields ─────────────────────────────────────────────────
                if (_useSms) ...[
                  GSTextField(
                    hint: 'Número de teléfono',
                    label: 'Teléfono',
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    prefixIcon: Icons.phone_android_rounded,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) =>
                        (v == null || v.length < 8)
                            ? 'Ingresa un número válido'
                            : null,
                    semanticLabel: 'Campo de número de teléfono',
                  ),
                ] else ...[
                  GSTextField(
                    hint: 'Correo electrónico',
                    label: 'Correo',
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.email_outlined,
                    validator: (v) =>
                        (v == null || !v.contains('@'))
                            ? 'Ingresa un correo válido'
                            : null,
                  ),
                  const SizedBox(height: GSSpacing.s3),
                  GSTextField(
                    hint: '••••••••',
                    label: 'Contraseña',
                    controller: _passwordCtrl,
                    obscureText: !_showPassword,
                    prefixIcon: Icons.lock_outlined,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: GSColors.textSecondary,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                    ),
                    validator: (v) =>
                        (v == null || v.length < 6)
                            ? 'Contraseña muy corta'
                            : null,
                  ),
                  const SizedBox(height: GSSpacing.s1),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {},
                      style: TextButton.styleFrom(
                        foregroundColor: GSColors.accent,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 4),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        '¿Olvidaste tu contraseña?',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: GSSpacing.s6),

                // ── Primary CTA ────────────────────────────────────────────
                GSButton(
                  label: _useSms ? 'Enviar código' : 'Iniciar sesión',
                  onPressed: _submit,
                  isLoading: _isLoading,
                  leadingIcon:
                      _useSms ? Icons.sms_rounded : Icons.login_rounded,
                ),

                const SizedBox(height: GSSpacing.s6),

                // ── Divider ────────────────────────────────────────────────
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: GSSpacing.s4),
                      child: Text(
                        'o',
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: GSColors.textDisabled,
                                ),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: GSSpacing.s4),

                // ── Social stubs ───────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _SocialButton(
                        label: 'Google',
                        icon: Icons.g_mobiledata_rounded,
                        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Próximamente')),
                        ),
                      ),
                    ),
                    const SizedBox(width: GSSpacing.s3),
                    Expanded(
                      child: _SocialButton(
                        label: 'Apple',
                        icon: Icons.apple_rounded,
                        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Próximamente')),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: GSSpacing.s8),

                // ── Sign-up link ───────────────────────────────────────────
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '¿No tienes cuenta? ',
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: GSColors.textSecondary,
                                ),
                      ),
                      TextButton(
                        onPressed: () => context.go(AppRoutes.register),
                        style: TextButton.styleFrom(
                          foregroundColor: GSColors.accent,
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Regístrate',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Segmented toggle tab
// ─────────────────────────────────────────────────────────────────────────────

class _ToggleTab extends StatelessWidget {
  const _ToggleTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          // Spring-like cubic — decelerates into the final position
          duration: GSDuration.normal,
          curve: Curves.easeOutCubic,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? GSColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(GSRadius.full),
            boxShadow: selected ? GSShadow.accent : [],
          ),
          child: AnimatedDefaultTextStyle(
            duration: GSDuration.normal,
            curve: Curves.easeOutCubic,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? Colors.white : GSColors.textSecondary,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Social provider button
// ─────────────────────────────────────────────────────────────────────────────

class _SocialButton extends StatefulWidget {
  const _SocialButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_SocialButton> createState() => _SocialButtonState();
}

class _SocialButtonState extends State<_SocialButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeIn,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: GSColors.surface,
            borderRadius: BorderRadius.circular(GSRadius.full),
            border: Border.all(color: GSColors.border, width: 1),
            boxShadow: _pressed ? [] : GSShadow.sm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 22, color: GSColors.textPrimary),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: GSColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
