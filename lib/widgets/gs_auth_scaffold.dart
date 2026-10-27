// lib/widgets/gs_auth_scaffold.dart
// Entrada y registro como Nequi/DiDi: banda honda de marca con el logo, el
// título y una línea, y el formulario en una hoja que monta encima (radio 24).
// Mismo marco para "Entra a GoSmart" y "Crear cuenta".
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/design_tokens.dart';

class GSAuthScaffold extends StatelessWidget {
  const GSAuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.child,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: GSColors.brandDeep,
        body: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(GSSpacing.s2,
                        top + GSSpacing.s2, GSSpacing.s5, GSSpacing.s8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconButton(
                          tooltip: 'Volver',
                          icon: Icon(Icons.arrow_back_rounded,
                              color: GSColors.onBrandDeep),
                          onPressed: onBack,
                        ),
                        const SizedBox(height: GSSpacing.s3),
                        Padding(
                          padding: const EdgeInsets.only(left: GSSpacing.s3),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  // El logo trae fondo blanco: va en su cuadro.
                                  color: Colors.white,
                                  borderRadius:
                                      BorderRadius.circular(GSRadius.lg),
                                ),
                                child: Image.asset(
                                  'assets/images/logo_gosmart.png',
                                  fit: BoxFit.contain,
                                  semanticLabel: 'GoSmart',
                                ),
                              ),
                              const SizedBox(height: GSSpacing.s4),
                              Semantics(
                                header: true,
                                child: Text(
                                  title,
                                  style: TextStyle(
                                    fontFamily: GSFonts.sans,
                                    fontSize: 30,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.6,
                                    height: 1.1,
                                    color: GSColors.onBrandDeep,
                                  ),
                                ),
                              ),
                              const SizedBox(height: GSSpacing.s2),
                              Text(
                                subtitle,
                                style: TextStyle(
                                  fontFamily: GSFonts.sans,
                                  fontSize: 16,
                                  height: 1.4,
                                  color: GSColors.onBrandDeepMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    constraints:
                        BoxConstraints(minHeight: box.maxHeight * 0.55),
                    padding: EdgeInsets.fromLTRB(
                        GSSpacing.s4,
                        GSSpacing.s6,
                        GSSpacing.s4,
                        GSSpacing.s6 + MediaQuery.of(context).padding.bottom),
                    decoration: BoxDecoration(
                      color: GSColors.background,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(GSRadius.xl)),
                    ),
                    // Material propio: las filas con casilla pintan su toque
                    // sobre la hoja y no debajo de ella.
                    child: Material(
                        type: MaterialType.transparency, child: child),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
