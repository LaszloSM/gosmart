// lib/widgets/gs_route_plate.dart
// Gesto distintivo del mundo "rótulo de colectivo": la placa de ruta que los
// colectivos de la costa llevan pintada en el parabrisas. Cada destino, tramo,
// viaje o nombre importante se muestra en una placa: blanca, borde fino, letras
// condensadas en ultramar y, si está activa, una franja fucsia debajo.
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
  });

  /// Destino o nombre principal. Se pinta en mayúsculas.
  final String text;

  /// Origen opcional: "RIOHACHA → MAICAO" (la flecha es un ícono; Barlow no
  /// trae el glifo →).
  final String? from;

  /// Línea pequeña debajo (hora, precio, correo).
  final String? detail;
  final IconData? leading;
  final Widget? trailing;

  /// Placa en blanco ("¿A dónde vas?"): letras en tinta suave.
  final bool isPlaceholder;

  /// Franja fucsia de 4 dp: la placa seleccionada o en curso.
  final bool isActive;
  final GSPlateSize size;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  State<GSRoutePlate> createState() => _GSRoutePlateState();
}

class _GSRoutePlateState extends State<GSRoutePlate> {
  bool _pressed = false;

  ({double minHeight, double font, double pad, double icon}) get _dims =>
      switch (widget.size) {
        GSPlateSize.sm => (minHeight: 48, font: 18, pad: 12, icon: 18),
        GSPlateSize.md => (minHeight: 56, font: 22, pad: 16, icon: 22),
        GSPlateSize.lg => (minHeight: 72, font: 30, pad: 16, icon: 26),
      };

  @override
  Widget build(BuildContext context) {
    final d = _dims;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final ink = widget.isPlaceholder ? GSColors.textMuted : GSColors.brand;
    final letters = TextStyle(
      fontFamily: GSFonts.display,
      fontSize: d.font,
      fontWeight: FontWeight.w800,
      height: 1.05,
      letterSpacing: 0.4,
      color: ink,
    );

    final main = Row(
      children: [
        if (widget.from != null) ...[
          Flexible(
            child: Text(widget.from!.toUpperCase(),
                style: letters, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: GSSpacing.s2),
            child: Icon(Icons.arrow_forward_rounded,
                size: d.icon, color: GSColors.stripe),
          ),
        ],
        Flexible(
          child: Text(widget.text.toUpperCase(),
              style: letters, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );

    // Cambio de rótulo: fundido + 8 dp en 200 ms, ease-out fuerte (Emil).
    final lettering = AnimatedSwitcher(
      duration: reduceMotion ? Duration.zero : GSDuration.fast,
      switchInCurve: GSCurve.enter,
      switchOutCurve: GSCurve.exit,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.centerLeft,
        children: [...previous, if (current != null) current],
      ),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.25), end: Offset.zero)
              .animate(anim),
          child: child,
        ),
      ),
      child: KeyedSubtree(
        key: ValueKey('${widget.from}|${widget.text}'),
        child: main,
      ),
    );

    final body = Container(
      constraints: BoxConstraints(minHeight: d.minHeight),
      padding: EdgeInsets.fromLTRB(
          d.pad, GSSpacing.s2, d.pad, GSSpacing.s2 + (widget.isActive ? 0 : 4)),
      child: Row(
        children: [
          if (widget.leading != null) ...[
            Icon(widget.leading, size: d.icon, color: ink),
            SizedBox(width: d.pad * 0.75),
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: GSFonts.sans,
                      fontFeatures: GSFonts.tabular,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
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
      color: GSColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GSRadius.md),
        side: BorderSide(
          color: widget.isActive ? GSColors.brand : GSColors.line,
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        onHighlightChanged:
            widget.onTap == null ? null : (v) => setState(() => _pressed = v),
        splashFactory: NoSplash.splashFactory,
        highlightColor: GSColors.brandTint.withValues(alpha: 0.6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            body,
            if (widget.isActive)
              Container(height: 4, color: GSColors.stripe),
          ],
        ),
      ),
    );

    final label = widget.semanticLabel ??
        [widget.from, widget.text, widget.detail].whereType<String>().join(', ');

    return Semantics(
      button: widget.onTap != null,
      selected: widget.isActive,
      label: label,
      excludeSemantics: true,
      child: AnimatedScale(
        scale: _pressed && !reduceMotion ? 0.97 : 1,
        duration: GSDuration.press,
        curve: GSCurve.enter,
        child: plate,
      ),
    );
  }
}
