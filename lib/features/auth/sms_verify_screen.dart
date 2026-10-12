// lib/features/auth/sms_verify_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth_errors.dart';
import '../../router/app_router.dart';
import '../../services/auth_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_button.dart';
import '../../widgets/gs_toast.dart';

class SmsVerifyScreen extends StatefulWidget {
  const SmsVerifyScreen({super.key, required this.phone});

  /// Número en formato E.164 (+57…).
  final String phone;

  @override
  State<SmsVerifyScreen> createState() => _SmsVerifyScreenState();
}

class _SmsVerifyScreenState extends State<SmsVerifyScreen> {
  final _codeCtrl = TextEditingController();
  bool _isLoading = false;
  bool _resending = false;

  @override
  void initState() {
    super.initState();
    _codeCtrl.addListener(() {
      setState(() {});
      // Con el sexto número se verifica solo.
      if (_codeCtrl.text.length == 6 && !_isLoading) _verify();
    });
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_codeCtrl.text.length < 6) return;
    setState(() => _isLoading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final res = await authService.verifyOtp(
          phone: widget.phone, token: _codeCtrl.text.trim());
      if (res.user != null && mounted) context.go(AppRoutes.home);
    } catch (e) {
      GSToast.showWithMessenger(messenger,
          message: friendlyAuthError(e), type: GSToastType.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await authService.sendOtp(widget.phone);
      GSToast.showWithMessenger(messenger,
          message: 'Te enviamos un código nuevo.',
          type: GSToastType.success);
    } catch (e) {
      GSToast.showWithMessenger(messenger,
          message: friendlyAuthError(e), type: GSToastType.error);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: GSColors.background,
      appBar: AppBar(title: const Text('Escribe el código')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(GSSpacing.s4),
          children: [
            Text('Te lo enviamos por SMS al', style: text.bodyLarge),
            Text(
              widget.phone,
              style: const TextStyle(
                fontFamily: GSFonts.mono,
                fontFeatures: GSFonts.tabular,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: GSColors.text,
              ),
            ),
            const SizedBox(height: GSSpacing.s6),
            // Un solo campo grande de 6 cifras, como una placa.
            TextField(
              controller: _codeCtrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                fontFamily: GSFonts.display,
                fontFeatures: GSFonts.tabular,
                fontSize: 40,
                fontWeight: FontWeight.w800,
                letterSpacing: 12,
                color: GSColors.brand,
              ),
              decoration: const InputDecoration(
                counterText: '',
                hintText: '······',
              ),
            ),
            const SizedBox(height: GSSpacing.s6),
            GSButton(
              label: 'Verificar',
              onPressed: _codeCtrl.text.length == 6 ? _verify : null,
              isLoading: _isLoading,
            ),
            const SizedBox(height: GSSpacing.s3),
            TextButton(
              onPressed: _resending ? null : _resend,
              child: Text(_resending ? 'Enviando…' : 'No me llegó, enviar otro'),
            ),
          ],
        ),
      ),
    );
  }
}
