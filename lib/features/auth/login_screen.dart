import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_button.dart';
import '../../widgets/gs_text_field.dart';
import '../../widgets/gs_toast.dart';
import '../../router/app_router.dart';
import '../../services/auth_service.dart';
import 'package:go_router/go_router.dart';

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
    try {
      if (_useSms) {
        await authService.sendOtp(_phoneCtrl.text.trim());
        if (mounted) {
          context.push(AppRoutes.smsVerify, extra: _phoneCtrl.text.trim());
        }
      } else {
        final response = await authService.signInWithEmail(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
        if (response.user != null && mounted) {
          context.go(AppRoutes.home);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GSColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(GSSpacing.s6),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: GSSpacing.s10),
                // Logo
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: GSColors.primary,
                    borderRadius: BorderRadius.circular(GSRadius.lg),
                    boxShadow: GSShadow.primary,
                  ),
                  child: const Icon(Icons.directions_transit_rounded,
                      color: Colors.white, size: 32),
                ),
                const SizedBox(height: GSSpacing.s6),
                Text('Welcome\nback!',
                    style: Theme.of(context).textTheme.displaySmall),
                const SizedBox(height: GSSpacing.s2),
                Text(
                  'Sign in to your GoSmart account',
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: GSColors.textSecondary),
                ),
                const SizedBox(height: GSSpacing.s8),

                // Toggle SMS / Email
                _AuthToggle(
                  useSms: _useSms,
                  onToggle: (v) => setState(() => _useSms = v),
                ),
                const SizedBox(height: GSSpacing.s5),

                if (_useSms) ...[
                  GSTextField(
                    label: 'Phone number',
                    hint: '+1 555 000 0000',
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    prefixIcon: Icons.phone_rounded,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) =>
                        (v == null || v.length < 8) ? 'Enter a valid number' : null,
                    semanticLabel: 'Phone number input',
                  ),
                ] else ...[
                  GSTextField(
                    label: 'Email',
                    hint: 'you@example.com',
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.email_rounded,
                    validator: (v) =>
                        (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                  ),
                  const SizedBox(height: GSSpacing.s4),
                  GSTextField(
                    label: 'Password',
                    hint: '••••••••',
                    controller: _passwordCtrl,
                    obscureText: true,
                    prefixIcon: Icons.lock_rounded,
                    suffixIcon: const Icon(Icons.visibility_rounded,
                        size: 20, color: GSColors.textSecondary),
                    validator: (v) =>
                        (v == null || v.length < 6) ? 'Password too short' : null,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {},
                      child: const Text('Forgot password?'),
                    ),
                  ),
                ],

                const SizedBox(height: GSSpacing.s6),

                GSButton(
                  label: _useSms ? 'Send verification code' : 'Sign in',
                  onPressed: _submit,
                  isLoading: _isLoading,
                  leadingIcon: _useSms ? Icons.sms_rounded : Icons.login_rounded,
                ),
                const SizedBox(height: GSSpacing.s4),

                // Social
                Row(children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('or', style: Theme.of(context).textTheme.bodyMedium),
                  ),
                  const Expanded(child: Divider()),
                ]),
                const SizedBox(height: GSSpacing.s4),
                Row(children: [
                  Expanded(
                    child: _SocialButton(
                      label: 'Google',
                      icon: Icons.g_mobiledata_rounded,
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Google sign-in coming soon')),
                      ),
                    ),
                  ),
                  const SizedBox(width: GSSpacing.s3),
                  Expanded(
                    child: _SocialButton(
                      label: 'Apple',
                      icon: Icons.apple_rounded,
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Apple sign-in coming soon')),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: GSSpacing.s8),

                Center(
                  child: TextButton(
                    onPressed: () => context.push(AppRoutes.register),
                    child: RichText(
                      text: const TextSpan(
                        text: "Don't have an account? ",
                        style: TextStyle(color: GSColors.textSecondary, fontSize: 14),
                        children: [
                          TextSpan(
                            text: 'Sign up',
                            style: TextStyle(
                                color: GSColors.primary,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthToggle extends StatelessWidget {
  const _AuthToggle({required this.useSms, required this.onToggle});
  final bool useSms;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: GSColors.surfaceDark,
        borderRadius: BorderRadius.circular(GSRadius.full),
      ),
      child: Row(
        children: [
          _Tab(label: 'Phone', selected: useSms, onTap: () => onToggle(true)),
          _Tab(label: 'Email', selected: !useSms, onTap: () => onToggle(false)),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: GSDuration.normal,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? GSColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(GSRadius.full),
            boxShadow: selected ? GSShadow.sm : [],
          ),
          child: Text(
            label,
            style: TextStyle(
              
              fontSize: 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? GSColors.textPrimary : GSColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: GSColors.surface,
          borderRadius: BorderRadius.circular(GSRadius.md),
          border: Border.all(color: GSColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: GSColors.textPrimary),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w500, color: GSColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}
