// lib/features/routes/widgets/destination_plate.dart
// El destino ES la placa: mientras escribes es una placa en blanco con letras
// de rótulo; al elegir una sugerencia queda "pintada" (placa activa con la
// franja fucsia). Tocarla de nuevo la borra para escribir otro destino.
import 'package:flutter/material.dart';

import '../../../theme/design_tokens.dart';
import '../../../widgets/gs_route_plate.dart';

class DestinationPlate extends StatelessWidget {
  const DestinationPlate({
    super.key,
    required this.controller,
    required this.chosenLabel,
    required this.onClear,
    this.focusNode,
    this.autofocus = false,
  });

  final TextEditingController controller;

  /// Nombre del destino elegido; null mientras se escribe.
  final String? chosenLabel;
  final VoidCallback onClear;
  final FocusNode? focusNode;
  final bool autofocus;

  // Getter, no campo: lee la paleta activa (día/noche) cada vez.
  static TextStyle get _letters => TextStyle(
    fontFamily: GSFonts.display,
    fontSize: 22,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.4,
    color: GSColors.brand,
  );

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final painted = chosenLabel != null;

    final child = painted
        ? GSRoutePlate(
            key: const ValueKey('painted'),
            text: chosenLabel!,
            leading: Icons.place_rounded,
            isActive: true,
            maxLines: 2,
            onTap: onClear,
            semanticLabel: 'Destino: $chosenLabel. Toca para cambiarlo',
            trailing: Icon(Icons.edit_outlined, color: GSColors.textMuted),
          )
        : TextField(
            key: const ValueKey('blank'),
            controller: controller,
            focusNode: focusNode,
            autofocus: autofocus,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.search,
            style: _letters,
            decoration: InputDecoration(
              hintText: '¿A DÓNDE VAS?',
              hintStyle: _letters.copyWith(color: GSColors.textMuted),
              prefixIcon: Icon(Icons.search_rounded,
                  size: 26, color: GSColors.brand),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: GSSpacing.s4, vertical: GSSpacing.s4),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(GSRadius.md),
                borderSide: BorderSide(color: GSColors.line, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(GSRadius.md),
                borderSide: BorderSide(color: GSColors.brand, width: 2),
              ),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Borrar',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: controller.clear,
                    ),
            ),
          );

    // Al pintarse: el contrato de la placa (fundido de 200 ms).
    return AnimatedSwitcher(
      duration: reduceMotion ? GSDuration.fast : GSDuration.plate,
      switchInCurve: GSCurve.enter,
      switchOutCurve: GSCurve.exit,
      child: child,
    );
  }
}
