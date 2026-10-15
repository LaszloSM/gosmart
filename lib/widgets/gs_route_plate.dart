// lib/widgets/gs_route_plate.dart
// Tarjeta de lugar u opción (destino, tramo, viaje, nombre): blanca, radio 16,
// ícono en un círculo de color, título en caja normal y una línea de detalle.
// Elegida: borde azul y fondo apenas teñido, como las opciones de viaje de
// Uber/InDrive. Se conserva el nombre GSRoutePlate para no romper los usos.
import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

enum GSPlateSize { sm, md, lg }

class GSRoutePlate extends StatefulWidget {
  const GSRoutePlate({
    super.key,
    required this.text,
    this.from,
    this.detail,
    this.leading,
    this.trailing,
    this.isPlaceholder = false,
    this.isActive = false,
    this.size = GSPlateSize.md,
    this.onTap,
    this.semanticLabel,
    this.maxLines = 1,
    this.detailMaxLines = 1,
  });

  /// Destino o nombre principal.
  final String text;

  /// Origen opcional: "Riohacha → Maicao" (la flecha es un ícono).
  final String? from;

  /// Línea pequeña debajo (hora, precio, correo).
  final String? detail;
  final IconData? leading;
  final Widget? trailing;

  /// Tarjeta en blanco ("¿A dónde vas?"): título en tinta suave.
  final bool isPlaceholder;

  /// Seleccionada o en curso: borde azul y fondo teñido.
  final bool isActive;
  final GSPlateSize size;
  final VoidCallback? onTap;
  final String? semanticLabel;

  /// Líneas del rótulo principal (2 para nombres largos).
  final int maxLines;

  /// Líneas de la línea pequeña (más con texto grande del sistema).
  final int detailMaxLines;

  @override
  State<GSRoutePlate> createState() => _GSRoutePlateState();
}

class _GSRoutePlateState extends State<GSRoutePlate> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed != v && mounted) setState(() => _pressed = v);
  }

  ({double minHeight, double font, double pad, double icon}) get _dims =>
      switch (widget.size) {
        GSPlateSize.sm => (minHeight: 56, font: 16, pad: 12, icon: 20),
        GSPlateSize.md => (minHeight: 64, font: 18, pad: 16, icon: 22),
        GSPlateSize.lg => (minHeight: 80, font: 24, pad: 20, icon: 26),
      };

  @override
  Widget build(BuildContext context) {
    final d = _dims;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final ink = widget.isPlaceholder ? GSColors.textMuted : GSColors.text;
    final letters = TextStyle(
      fontFamily: GSFonts.display,
      fontSize: d.font,
      fontWeight: widget.isPlaceholder ? FontWeight.w600 : FontWeight.w700,
      height: 1.2,
      letterSpacing: d.font > 20 ? -0.3 : -0.1,
      color: ink,
    );

    final main = Row(
      children: [
        if (widget.from != null) ...[
          Flexible(
            child: Text(widget.from!,
                style: letters, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: GSSpacing.s2),
            child: Icon(Icons.arrow_forward_rounded, size: d.icon - 4, color: GSColors.textMuted),
          ),
        ],
        Flexible(
          child: Text(widget.text,
              style: letters,
              maxLines: widget.maxLines,
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );

    // Cambio de título: el nuevo entra con fundido + 6 dp en 200 ms y
    // ease-out fuerte; el que sale solo se desvanece (Emil). Con "quitar
    // animaciones" queda un fundido corto, sin desplazamiento.
    final currentKey = ValueKey('${widget.from}|${widget.text}');
    final lettering = AnimatedSwitcher(
      duration: reduceMotion ? GSDuration.fast : GSDuration.plate,
      switchInCurve: GSCurve.enter,
      switchOutCurve: GSCurve.exit,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.centerLeft,
        children: [...previous, if (current != null) current],
      ),
      transitionBuilder: (child, anim) {
        final fade = FadeTransition(opacity: anim, child: child);
        if (reduceMotion || child.key != currentKey) return fade;
        return AnimatedBuilder(
          animation: anim,
          builder: (_, c) => Transform.translate(
            offset: Offset(0, 6 * (1 - anim.value)),
            child: c,
          ),
          child: fade,
        );
      },
      child: KeyedSubtree(key: currentKey, child: main),
    );

    final body = Container(
      constraints: BoxConstraints(minHeight: d.minHeight),
      padding: EdgeInsets.symmetric(horizontal: d.pad, vertical: GSSpacing.s3),
      child: Row(
        children: [
          if (widget.leading != null) ...[
            // Ícono en círculo teñido, como los accesos de Google Maps.
            Container(
              width: d.icon + 18,
              height: d.icon + 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isActive ? GSColors.brand : GSColors.brandTint,
              ),
              child: Icon(widget.leading,
                  size: d.icon,
                  color: widget.isActive ? GSColors.onBrand : GSColors.brand),
            ),
            const SizedBox(width: GSSpacing.s3),
          ],
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                lettering,
                if (widget.detail != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.detail!,
                    maxLines: widget.detailMaxLines,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: GSFonts.sans,
                      fontFeatures: GSFonts.tabular,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                      color: GSColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (widget.trailing != null) ...[
            const SizedBox(width: GSSpacing.s2),
            widget.trailing!,
          ],
        ],
      ),
    );

    final plate = Material(
      color: widget.isActive
          ? Color.alphaBlend(GSColors.brandTint.withValues(alpha: 0.55), GSColors.surface)
          : GSColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GSRadius.lg),
        side: BorderSide(
          color: widget.isActive ? GSColors.brand : GSColors.line,
          width: widget.isActive ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        splashFactory: NoSplash.splashFactory,
        highlightColor: GSColors.brandTint.withValues(alpha: 0.6),
        child: body,
      ),
    );

    final label = widget.semanticLabel ??
        [widget.from, widget.text, widget.detail].whereType<String>().join(', ');

    return Semantics(
      button: widget.onTap != null,
      selected: widget.isActive,
      label: label,
      excludeSemantics: true,
      // Listener y no onHighlightChanged: dentro de listas con scroll el
      // resaltado espera al arbitraje de gestos y la respuesta llega tarde.
      child: Listener(
        onPointerDown: widget.onTap == null ? null : (_) => _setPressed(true),
        onPointerUp: (_) => _setPressed(false),
        onPointerCancel: (_) => _setPressed(false),
        child: AnimatedScale(
          scale: _pressed && !reduceMotion ? 0.97 : 1,
          duration: GSDuration.press,
          curve: GSCurve.enter,
          child: plate,
        ),
      ),
    );
  }
}
