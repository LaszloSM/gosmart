import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_button.dart';
import '../../widgets/gs_text_field.dart';
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

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes aceptar los términos para continuar')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final response = await authService.signUp(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
        name: _nameCtrl.text.trim(),
        consentGeo: false,
        consentAi: false,
      );
      if (response.user != null && mounted) {
        context.go(AppRoutes.home);
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: const BackButton(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
            horizontal: GSSpacing.s6, vertical: GSSpacing.s2),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Create your\naccount',
                  style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(height: GSSpacing.s2),
              Text('Join millions using GoSmart',
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: GSColors.textSecondary)),
              const SizedBox(height: GSSpacing.s8),

              GSTextField(
                label: 'Full name',
                hint: 'Muhammad Ali',
                controller: _nameCtrl,
                keyboardType: TextInputType.name,
                prefixIcon: Icons.person_rounded,
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: GSSpacing.s4),
              GSTextField(
                label: 'Phone number',
                hint: '+57 300 000 0000',
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                prefixIcon: Icons.phone_rounded,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) => null,
              ),
              const SizedBox(height: GSSpacing.s4),
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
                controller: _passCtrl,
                obscureText: true,
                prefixIcon: Icons.lock_rounded,
                validator: (v) =>
                    (v == null || v.length < 8)
                        ? 'Minimum 8 characters'
                        : null,
              ),
              const SizedBox(height: GSSpacing.s5),

              // Terms
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _termsAccepted,
                    onChanged: (v) =>
                        setState(() => _termsAccepted = v ?? false),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                    activeColor: GSColors.primary,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: RichText(
                        text: const TextSpan(
                          text: 'I agree to the ',
                          style: TextStyle(
                              color: GSColors.textSecondary, fontSize: 13),
                          children: [
                            TextSpan(
                              text: 'Terms of Service',
                              style: TextStyle(
                                  color: GSColors.primary,
                                  fontWeight: FontWeight.w600),
                            ),
                            TextSpan(text: ' and '),
                            TextSpan(
                              text: 'Privacy Policy',
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
              const SizedBox(height: GSSpacing.s6),

              GSButton(
                label: 'Create account',
                onPressed: _submit,
                isLoading: _isLoading,
                leadingIcon: Icons.person_add_rounded,
              ),
              const SizedBox(height: GSSpacing.s8),
            ],
          ),
        ),
      ),
    );
  }
}
