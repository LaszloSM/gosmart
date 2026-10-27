// lib/features/routes/widgets/destination_plate.dart
// Campo de destino como el de Uber/Google Maps: mientras escribes es una caja
// gris; al elegir una sugerencia queda fijado como tarjeta elegida. Tocarla
// de nuevo la borra para escribir otro destino.
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
        fontFamily: GSFonts.sans,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: GSColors.text,
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
            trailing: Icon(Icons.edit_rounded, color: GSColors.textMuted),
          )
        : TextField(
            key: const ValueKey('blank'),
            controller: controller,
            focusNode: focusNode,
            autofocus: autofocus,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.search,
            style: _letters,
            decoration: InputDecoration(
              hintText: '¿A dónde vas?',
              hintMaxLines: 2,
              hintStyle: _letters.copyWith(color: GSColors.textMuted),
              prefixIcon:
                  Icon(Icons.search_rounded, size: GSSize.iconLg, color: GSColors.text),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: GSSpacing.s4, vertical: GSSpacing.s4),
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
      // A todo el ancho: el layout por defecto centra y encoge el campo.
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topLeft,
        children: [
          ...previous,
          if (current != null) SizedBox(width: double.infinity, child: current),
        ],
      ),
      child: child,
    );
  }
}
