// lib/widgets/gs_pressable.dart
// Cualquier cosa que se toca y no es un botón (tarjeta, servicio, buscador):
// responde al dedo con escala 0,97 en 120 ms ease-out (Emil Kowalski) desde
// el toque, no al soltar. Sin salpicadura: la escala es la respuesta. Con
// "quitar animaciones" no escala.
import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

class GSPressable extends StatefulWidget {
  const GSPressable({
    super.key,
    required this.child,
    required this.onTap,
    this.semanticLabel,
    this.selected,
  });

  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final bool? selected;

  @override
  State<GSPressable> createState() => _GSPressableState();
}

class _GSPressableState extends State<GSPressable> {
  bool _pressed = false;

  void _set(bool v) {
    if (_pressed != v && mounted) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    final enabled = widget.onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      selected: widget.selected,
      label: widget.semanticLabel,
      excludeSemantics: widget.semanticLabel != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        // Listener: la respuesta llega al tocar, sin esperar al arbitraje de
        // gestos de las listas con scroll.
        child: Listener(
          onPointerDown: enabled ? (_) => _set(true) : null,
          onPointerUp: (_) => _set(false),
          onPointerCancel: (_) => _set(false),
          child: AnimatedScale(
            scale: _pressed && !reduce ? 0.97 : 1,
            duration: GSDuration.press,
            curve: GSCurve.enter,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
