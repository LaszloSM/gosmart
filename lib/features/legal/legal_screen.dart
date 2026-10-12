// lib/features/legal/legal_screen.dart
// Lectura simple: título condensado por sección y cuerpo a 17 sp. Pública:
// se puede leer antes de crear la cuenta.
import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';
import 'legal_texts.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.doc});
  final LegalDoc doc;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: GSColors.background,
      appBar: AppBar(title: Text(doc.title)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(GSSpacing.s4, GSSpacing.s4, GSSpacing.s4,
            MediaQuery.of(context).padding.bottom + GSSpacing.s8),
        children: [
          Text('Versión $legalVersion', style: text.bodySmall),
          for (final s in doc.sections) ...[
            const SizedBox(height: GSSpacing.s5),
            Text(s.title, style: text.titleLarge),
            const SizedBox(height: GSSpacing.s2),
            Text(s.body, style: text.bodyLarge),
          ],
        ],
      ),
    );
  }
}
