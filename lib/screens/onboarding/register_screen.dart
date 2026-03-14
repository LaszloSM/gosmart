import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_button.dart';
import '../../widgets/gs_text_field.dart';
import '../../router/app_router.dart';

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
  int _step = 0; // 0=info, 1=sms verify

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
        const SnackBar(content: Text('Please accept the terms to continue')),
      );
      return;
    }
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.pushNamed(context, AppRoutes.smsVerify,
          arguments: _phoneCtrl.text);
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
                hint: '+1 555 000 0000',
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                prefixIcon: Icons.phone_rounded,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) =>
                    (v == null || v.length < 8) ? 'Enter a valid number' : null,
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

// ─── SMS Verification screen ──────────────────────────────────────────────────

class SmsVerificationScreen extends StatefulWidget {
  const SmsVerificationScreen({super.key, required this.phone});
  final String phone;

  @override
  State<SmsVerificationScreen> createState() => _SmsVerificationScreenState();
}

class _SmsVerificationScreenState extends State<SmsVerificationScreen> {
  final List<TextEditingController> _ctrls =
      List.generate(6, (_) => TextEditingController());
  bool _isLoading = false;
  int _resendCountdown = 59;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() async {
    while (_resendCountdown > 0 && mounted) {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) setState(() => _resendCountdown--);
    }
  }

  Future<void> _verify() async {
    // Prototype: accepts any code
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.pushNamedAndRemoveUntil(
          context, AppRoutes.home, (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GSColors.bg,
      appBar: AppBar(backgroundColor: Colors.transparent, leading: const BackButton()),
      body: Padding(
        padding: const EdgeInsets.all(GSSpacing.s6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: GSSpacing.s4),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: GSColors.primaryLight,
                borderRadius: BorderRadius.circular(GSRadius.lg),
              ),
              child:
                  const Icon(Icons.sms_rounded, color: GSColors.primary, size: 28),
            ),
            const SizedBox(height: GSSpacing.s5),
            Text('Verify your\nphone',
                style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: GSSpacing.s2),
            Text(
              'We sent a 6-digit code to\n${widget.phone}',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: GSColors.textSecondary),
            ),
            const SizedBox(height: GSSpacing.s8),

            // OTP boxes
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (i) => _OtpBox(controller: _ctrls[i])),
            ),
            const SizedBox(height: GSSpacing.s6),

            GSButton(
              label: 'Verify',
              onPressed: _verify,
              isLoading: _isLoading,
              leadingIcon: Icons.check_circle_rounded,
            ),
            const SizedBox(height: GSSpacing.s5),

            Center(
              child: _resendCountdown > 0
                  ? Text(
                      'Resend code in 0:${_resendCountdown.toString().padLeft(2, '0')}',
                      style: const TextStyle(color: GSColors.textSecondary),
                    )
                  : TextButton(
                      onPressed: () => setState(() {
                        _resendCountdown = 59;
                        _startCountdown();
                      }),
                      child: const Text('Resend code'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  const _OtpBox({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 56,
      child: TextField(
        controller: controller,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(
          
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: GSColors.textPrimary,
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: GSColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(GSRadius.md),
            borderSide: const BorderSide(color: GSColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(GSRadius.md),
            borderSide: const BorderSide(color: GSColors.primary, width: 2),
          ),
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (v) {
          if (v.isNotEmpty) {
            FocusScope.of(context).nextFocus();
          }
        },
      ),
    );
  }
}
