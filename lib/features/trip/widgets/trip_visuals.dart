// lib/features/trip/widgets/trip_visuals.dart
// Piezas del viaje al estilo InDrive/Uber: la línea de tramos, el radar de
// "buscando conductor", la tarifa que propones y la tarjeta de cada oferta.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/money.dart';
import '../../../core/motion.dart';
import '../../../models/dispatch_models.dart';
import '../../../theme/design_tokens.dart';
import '../../../widgets/gs_pressable.dart';

/// Minutos aproximados en la ciudad (moto o taxi a ~20 km/h + 1 de arranque).
int etaMinutes(LatLng from, LatLng to) {
  final km = const Distance().as(LengthUnit.Meter, from, to) / 1000;
  return (km / 20 * 60).ceil() + 1;
}

/// "1,2 km" / "350 m" con coma decimal.
String shortDistance(double km) => km < 1
    ? '${(km * 1000 / 10).round() * 10} m'
    : '${km.toStringAsFixed(1).replaceAll('.', ',')} km';

// ── Línea de tramos ──────────────────────────────────────────────────────────
/// Los tramos en fila, como las paradas de un metro: hecho (lleno con
/// visto), el actual (anillo de marca) y lo que falta (gris).
class LegTimeline extends StatelessWidget {
  const LegTimeline({
    super.key,
    required this.legs,
    required this.currentId,
    required this.iconFor,
    required this.labelFor,
  });

  final List<TripLegRow> legs;
  final String? currentId;
  final IconData Function(String mode) iconFor;
  final String Function(String mode) labelFor;

  @override
  Widget build(BuildContext context) {
    final i = legs.indexWhere((l) => l.id == currentId);
    final done = legs.where((l) => l.status == LegStatus.completed).length;
    return Semantics(
      label: 'Tramo ${i < 0 ? done : i + 1} de ${legs.length}',
      excludeSemantics: true,
      child: SizedBox(
        height: 40,
        child: Row(
          children: [
            for (var k = 0; k < legs.length; k++) ...[
              if (k > 0)
                Expanded(
                  child: Container(
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: legs[k - 1].status == LegStatus.completed
                          ? GSColors.brand
                          : GSColors.line,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              _Stop(
                icon: iconFor(legs[k].mode),
                done: legs[k].status == LegStatus.completed,
                current: legs[k].id == currentId,
                dead: legs[k].status == LegStatus.cancelled ||
                    legs[k].status == LegStatus.failed,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stop extends StatelessWidget {
  const _Stop({required this.icon, required this.done, required this.current, required this.dead});
  final IconData icon;
  final bool done;
  final bool current;
  final bool dead;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    final bg = done
        ? GSColors.brand
        : current
            ? GSColors.brandTint
            : GSColors.surfaceSunken;
    final fg = done
        ? GSColors.onBrand
        : current
            ? GSColors.brand
            : GSColors.textMuted;
    return AnimatedContainer(
      duration: reduce ? Duration.zero : GSDuration.normal,
      curve: GSCurve.enter,
      width: current ? 40 : 32,
      height: current ? 40 : 32,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: current ? Border.all(color: GSColors.brand, width: 2.5) : null,
      ),
      child: Icon(
        done ? Icons.check_rounded : (dead ? Icons.close_rounded : icon),
        size: current ? GSSize.iconMd : GSSize.iconSm,
        color: fg,
      ),
    );
  }
}

// ── Radar ────────────────────────────────────────────────────────────────────
/// "Buscando conductor": tres ondas que salen del vehículo, en bucle. Es la
/// única animación en bucle de la app y solo vive mientras se espera; con
/// "quitar animaciones" quedan las ondas quietas.
class SearchingRadar extends StatefulWidget {
  const SearchingRadar({super.key, required this.icon, this.size = 132});
  final IconData icon;
  final double size;

  @override
  State<SearchingRadar> createState() => _SearchingRadarState();
}

class _SearchingRadarState extends State<SearchingRadar> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _c.stop();
      _c.value = 0.5;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: SizedBox.square(
          dimension: widget.size,
          child: CustomPaint(
            painter: _RadarPainter(_c, GSColors.brand),
            child: Center(
              child: Container(
                width: widget.size * 0.38,
                height: widget.size * 0.38,
                decoration: BoxDecoration(
                  color: GSColors.brand,
                  shape: BoxShape.circle,
                  boxShadow: GSShadow.float,
                ),
                child: Icon(widget.icon, color: GSColors.onBrand, size: widget.size * 0.2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter(this.t, this.color) : super(repaint: t);
  final Animation<double> t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final minR = size.shortestSide * 0.19;
    final maxR = size.shortestSide / 2;
    for (var k = 0; k < 3; k++) {
      final p = (t.value + k / 3) % 1.0;
      // ease-out: las ondas salen rápido y se frenan al desvanecerse.
      final e = 1 - math.pow(1 - p, 3).toDouble();
      final r = minR + (maxR - minR) * e;
      canvas.drawCircle(
        c,
        r,
        Paint()..color = color.withValues(alpha: 0.22 * (1 - p)),
      );
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.color != color;
}

// ── Tu tarifa ────────────────────────────────────────────────────────────────
/// La tarifa que ofreces, grande y al centro, con − y + en píldoras y
/// atajos de +$500 / +$1.000 (como InDrive).
class FareComposer extends StatelessWidget {
  const FareComposer({
    super.key,
    required this.fare,
    required this.onChanged,
    this.min = 1000,
    this.step = 500,
    this.hint,
  });

  final int fare;
  final ValueChanged<int> onChanged;
  final int min;
  final int step;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final reduce = MediaQuery.of(context).disableAnimations;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _RoundStep(
              icon: Icons.remove_rounded,
              tooltip: 'Bajar ${formatCop(step)}',
              onTap: fare - step >= min ? () => onChanged(fare - step) : null,
            ),
            Expanded(
              child: Semantics(
                liveRegion: true,
                label: 'Tu tarifa ${formatCop(fare)}',
                excludeSemantics: true,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: AnimatedSwitcher(
                    duration: reduce ? Duration.zero : const Duration(milliseconds: 160),
                    switchInCurve: GSCurve.enter,
                    transitionBuilder: (child, a) => FadeTransition(
                      opacity: a,
                      child: SlideTransition(
                        position: Tween(begin: const Offset(0, 0.18), end: Offset.zero).animate(a),
                        child: child,
                      ),
                    ),
                    child: Text(
                      formatCop(fare),
                      key: ValueKey(fare),
                      style: TextStyle(
                        fontFamily: GSFonts.display,
                        fontFeatures: GSFonts.tabular,
                        fontSize: 40,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        color: GSColors.text,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _RoundStep(
              icon: Icons.add_rounded,
              tooltip: 'Subir ${formatCop(step)}',
              onTap: () => onChanged(fare + step),
            ),
          ],
        ),
        if (hint != null) ...[
          const SizedBox(height: 2),
          Text(hint!, textAlign: TextAlign.center, style: text.bodySmall),
        ],
        const SizedBox(height: GSSpacing.s3),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: GSSpacing.s2,
          runSpacing: GSSpacing.s2,
          children: [
            for (final add in const [500, 1000, 2000])
              ActionChip(
                label: Text('+${formatCop(add)}',
                    style: const TextStyle(fontFeatures: GSFonts.tabular)),
                onPressed: () => onChanged(fare + add),
              ),
          ],
        ),
      ],
    );
  }
}

class _RoundStep extends StatelessWidget {
  const _RoundStep({required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: GSPressable(
        onTap: onTap,
        semanticLabel: tooltip,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: enabled ? GSColors.surfaceSunken : GSColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: GSColors.line),
          ),
          child: Icon(icon, color: enabled ? GSColors.text : GSColors.line),
        ),
      ),
    );
  }
}

// ── Forma de pago ────────────────────────────────────────────────────────────
/// Saldo o efectivo, en dos píldoras (se elige antes de pedir, como InDrive).
class PayMethodPicker extends StatelessWidget {
  const PayMethodPicker({super.key, required this.method, required this.onChanged, this.balance});
  final String method;
  final ValueChanged<String> onChanged;
  final int? balance;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      showSelectedIcon: false,
      segments: [
        ButtonSegment(
          value: 'wallet',
          icon: const Icon(Icons.account_balance_wallet_rounded),
          label: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(balance == null ? 'Saldo' : 'Saldo ${formatCop(balance!)}',
                maxLines: 1, style: const TextStyle(fontFeatures: GSFonts.tabular)),
          ),
        ),
        const ButtonSegment(
          value: 'cash',
          icon: Icon(Icons.payments_rounded),
          label: FittedBox(fit: BoxFit.scaleDown, child: Text('Efectivo', maxLines: 1)),
        ),
      ],
      selected: {method},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

// ── Oferta de un conductor ──────────────────────────────────────────────────
/// Una oferta: quién es, su calificación, a cuánto está y el precio; un toque
/// en "Aceptar". Entra deslizándose desde abajo (180 ms) al llegar.
class OfferCard extends StatelessWidget {
  const OfferCard({
    super.key,
    required this.offer,
    required this.onAccept,
    this.busy = false,
    this.index = 0,
    this.myFare,
  });

  final RideOffer offer;
  final VoidCallback? onAccept;
  final bool busy;
  final int index;

  /// Lo que ofreciste tú: si la oferta es otra, se marca la diferencia.
  final int? myFare;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final o = offer;
    final name = o.firstName ?? 'Un conductor';
    final facts = [
      if (o.etaMin != null) 'a ${o.etaMin} min',
      if (o.pickupKm != null) shortDistance(o.pickupKm!),
      if (o.vehicle != null) o.vehicle!,
    ].join(' · ');
    final diff = myFare == null ? 0 : o.fare - myFare!;
    return Container(
      padding: const EdgeInsets.all(GSSpacing.s3),
      decoration: BoxDecoration(
        color: GSColors.surface,
        borderRadius: BorderRadius.circular(GSRadius.lg),
        border: Border.all(color: GSColors.line),
      ),
      child: Row(
        children: [
          DriverAvatar(name: name, size: 48),
          const SizedBox(width: GSSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(name,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleMedium),
                    ),
                    const SizedBox(width: GSSpacing.s2),
                    Icon(Icons.star_rounded, size: GSSize.iconSm, color: GSColors.text),
                    Text(
                      o.rating == null ? 'Nuevo' : o.rating!.toStringAsFixed(1).replaceAll('.', ','),
                      style: text.bodySmall?.copyWith(fontFeatures: GSFonts.tabular),
                    ),
                  ],
                ),
                if (facts.isNotEmpty)
                  Text(facts,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(fontFeatures: GSFonts.tabular)),
              ],
            ),
          ),
          const SizedBox(width: GSSpacing.s2),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(formatCop(o.fare),
                  style: text.titleLarge?.copyWith(fontFeatures: GSFonts.tabular)),
              if (diff != 0)
                Text(diff > 0 ? '${formatCop(diff)} más' : '${formatCop(-diff)} menos',
                    style: text.bodySmall?.copyWith(fontFeatures: GSFonts.tabular)),
              const SizedBox(height: GSSpacing.s1),
              FilledButton(
                onPressed: busy ? null : onAccept,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: GSSpacing.s4),
                  tapTargetSize: MaterialTapTargetSize.padded,
                ),
                child: const Text('Aceptar'),
              ),
            ],
          ),
        ],
      ),
    ).gsEnter(context,
        delay: Duration(milliseconds: 40 * index), slide: const Offset(0, 0.25), scale: 0.96);
  }
}

/// Inicial del conductor en un círculo de marca suave (sin fotos en el MVP).
class DriverAvatar extends StatelessWidget {
  const DriverAvatar({super.key, required this.name, this.size = 52});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: GSColors.brandTint, shape: BoxShape.circle),
      child: Text(
        initial,
        style: TextStyle(
          fontFamily: GSFonts.sans,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w800,
          color: GSColors.brand,
        ),
      ),
    );
  }
}

/// Barra de tiempo que se vacía (lo que le queda a la solicitud).
class CountdownBar extends StatelessWidget {
  const CountdownBar({super.key, required this.left, required this.total});
  final Duration left;
  final Duration total;

  @override
  Widget build(BuildContext context) {
    final f = total.inMilliseconds == 0
        ? 0.0
        : (left.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    final reduce = MediaQuery.of(context).disableAnimations;
    return ClipRRect(
      borderRadius: BorderRadius.circular(GSRadius.full),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: f),
        duration: reduce ? Duration.zero : const Duration(seconds: 1),
        curve: Curves.linear,
        builder: (context, v, _) => LinearProgressIndicator(
          value: v,
          minHeight: 6,
          backgroundColor: GSColors.surfaceSunken,
          color: GSColors.brand,
        ),
      ),
    );
  }
}
