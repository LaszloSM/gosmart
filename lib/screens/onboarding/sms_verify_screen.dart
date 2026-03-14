// lib/screens/onboarding/sms_verify_screen.dart
// Placeholder — full implementation in Task 14
import 'package:flutter/material.dart';

class SmsVerifyScreen extends StatelessWidget {
  final String phone;
  const SmsVerifyScreen({super.key, required this.phone});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text('Verify OTP for $phone')),
    );
  }
}
