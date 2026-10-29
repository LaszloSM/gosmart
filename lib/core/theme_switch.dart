// lib/core/theme_switch.dart
// Cambiar de tema sin salto: antes del cambio se toma una foto de la pantalla
// y se deja encima, desvaneciéndose en 320 ms mientras debajo ya está el tema
// nuevo (como Telegram). Con "quitar animaciones" el cambio es directo.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../theme/design_tokens.dart';

/// Envuelve la app (en MaterialApp.builder). Debe quedar FUERA de lo que se
/// reconstruye al cambiar el brillo.
class ThemeSwitchHost extends StatefulWidget {
  const ThemeSwitchHost({super.key, required this.child});
  final Widget child;

  static final _key = GlobalKey<_ThemeSwitchHostState>();

  /// La llave que usa la app para el host (una sola instancia).
  static GlobalKey get hostKey => _key;

  /// Toma la foto y deja que [change] cambie el tema.
  static Future<void> run(BuildContext context, VoidCallback change) async {
    final host = _key.currentState;
    if (host == null || MediaQuery.of(context).disableAnimations) {
      change();
      return;
    }
    await host._snapshotThen(change);
  }

  @override
  State<ThemeSwitchHost> createState() => _ThemeSwitchHostState();
}

class _ThemeSwitchHostState extends State<ThemeSwitchHost>
    with SingleTickerProviderStateMixin {
  final _boundary = GlobalKey();
  ui.Image? _shot;
  late final _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));

  Future<void> _snapshotThen(VoidCallback change) async {
    final ro = _boundary.currentContext?.findRenderObject();
    if (ro is RenderRepaintBoundary) {
      try {
        final img = await ro.toImage(pixelRatio: MediaQuery.devicePixelRatioOf(context));
        setState(() => _shot = img);
      } catch (_) {}
    }
    change();
    _fade.forward(from: 0).whenComplete(() {
      if (!mounted) return;
      _shot?.dispose();
      setState(() => _shot = null);
    });
  }

  @override
  void dispose() {
    _fade.dispose();
    _shot?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        RepaintBoundary(key: _boundary, child: widget.child),
        if (_shot != null)
          Positioned.fill(
            child: IgnorePointer(
              child: FadeTransition(
                opacity: ReverseAnimation(CurvedAnimation(parent: _fade, curve: GSCurve.move)),
                child: RawImage(image: _shot, fit: BoxFit.cover),
              ),
            ),
          ),
      ],
    );
  }
}
