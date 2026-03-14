// lib/features/auth/sms_verify_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';
import '../../router/app_router.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_button.dart';
import '../../widgets/gs_text_field.dart';

class SmsVerifyScreen extends StatefulWidget {
  const SmsVerifyScreen({super.key, required this.phone});
  final String phone;

  @override
  State<SmsVerifyScreen> createState() => _SmsVerifyScreenState();
}

class _SmsVerifyScreenState extends State<SmsVerifyScreen> {
  final _codeCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_codeCtrl.text.length < 6) return;
    setState(() => _isLoading = true);
    try {
      final res = await authService.verifyOtp(
        phone: widget.phone,
        token: _codeCtrl.text.trim(),
      );
      if (res.user != null && mounted) {
        context.go(AppRoutes.home);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Código incorrecto: $e'), backgroundColor: Colors.red),
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
      appBar: AppBar(title: const Text('Verificar código')),
      body: Padding(
        padding: const EdgeInsets.all(GSSpacing.s6),
        child: Column(
          children: [
            Text('Ingresa el código enviado a ${widget.phone}',
                style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: GSSpacing.s6),
            GSTextField(
              label: 'Código de 6 dígitos',
              hint: '123456',
              controller: _codeCtrl,
              keyboardType: TextInputType.number,
              prefixIcon: Icons.sms_rounded,
            ),
            const SizedBox(height: GSSpacing.s6),
            GSButton(
              label: 'Verificar',
              onPressed: _verify,
              isLoading: _isLoading,
              leadingIcon: Icons.check_circle_rounded,
            ),
          ],
        ),
      ),
    );
  }
}
