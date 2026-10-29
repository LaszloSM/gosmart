// lib/features/alerts/alert_detail_sheet.dart
// Tocar un pin del mapa: qué es, desde cuándo, dónde y qué dice la gente.
// Como Waze: "Sigue ahí" alarga la alerta; "Ya no está" la apaga si otro
// lo confirma. El que reportó no vota lo suyo.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion.dart';
import '../../models/map_alert.dart';
import '../../providers/auth_provider.dart';
import '../../providers/map_alerts_provider.dart';
import '../../router/app_router.dart';
import '../../services/geocoding_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_alert_badge.dart';
import '../../widgets/gs_pressable.dart';
import '../../widgets/gs_toast.dart';

Future<void> showAlertDetail(BuildContext context, MapAlert alert) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    sheetAnimationStyle: MediaQuery.of(context).disableAnimations
        ? AnimationStyle.noAnimation
        : null,
    builder: (_) => AlertDetailSheet(alertId: alert.id, initial: alert),
  );
}

class AlertDetailSheet extends ConsumerWidget {
  const AlertDetailSheet({super.key, required this.alertId, required this.initial});
  final String alertId;
  final MapAlert initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // La versión viva (cambia al votar); si ya no está en la lista, la inicial.
    final alert = (ref.watch(mapAlertsProvider).valueOrNull ?? const <MapAlert>[])
            .where((a) => a.id == alertId)
            .firstOrNull ??
        initial;
    final text = Theme.of(context).textTheme;
    final isGuest = ref.watch(isGuestProvider);
    final bottom = MediaQuery.of(context).padding.bottom;

    Future<void> vote(bool stillThere) async {
      if (isGuest) {
        Navigator.of(context).pop();
        context.push(AppRoutes.login);
        return;
      }
      final messenger = ScaffoldMessenger.of(context);
      final nav = Navigator.of(context);
      try {
        await ref.read(mapAlertsProvider.notifier).vote(alert, stillThere: stillThere);
        GSToast.showWithMessenger(messenger,
            message: stillThere
                ? 'Gracias: la alerta sigue en el mapa.'
                : 'Gracias: si alguien más lo confirma, se quita.',
            type: GSToastType.success);
        nav.maybePop();
      } catch (_) {
        GSToast.showWithMessenger(messenger,
            message: 'No pudimos guardar tu respuesta. Revisa tu conexión.',
            type: GSToastType.error);
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: GSColors.surface,
        borderRadius: GSRadius.sheetRadius,
      ),
      padding: EdgeInsets.fromLTRB(GSSpacing.s5, GSSpacing.s3, GSSpacing.s5, bottom + GSSpacing.s5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: GSColors.line,
                borderRadius: BorderRadius.circular(GSRadius.full),
              ),
            ),
          ),
          const SizedBox(height: GSSpacing.s4),
          Row(
            children: [
              GSAlertBadge(kind: alert.kind, size: 56).gsPop(context, from: 0.8),
              const SizedBox(width: GSSpacing.s4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(alert.kind.label, style: text.headlineSmall),
                    const SizedBox(height: 2),
                    Text(
                      alert.mine
                          ? 'Lo reportaste tú · ${alertAge(alert.happenedAt)}'
                          : 'Reportado ${alertAge(alert.happenedAt)}',
                      style: text.bodyMedium?.copyWith(fontFeatures: GSFonts.tabular),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: GSSpacing.s4),
          _Where(alert: alert),
          const SizedBox(height: GSSpacing.s2),
          _Votes(alert: alert),
          const SizedBox(height: GSSpacing.s5),
          if (!alert.mine)
            Row(
              children: [
                Expanded(
                  child: _VoteButton(
                    icon: Icons.thumb_up_rounded,
                    label: 'Sigue ahí',
                    selected: alert.myVote == true,
                    primary: true,
                    onTap: () => vote(true),
                  ),
                ),
                const SizedBox(width: GSSpacing.s3),
                Expanded(
                  child: _VoteButton(
                    icon: Icons.thumb_down_rounded,
                    label: 'Ya no está',
                    selected: alert.myVote == false,
                    onTap: () => vote(false),
                  ),
                ),
              ],
            )
          else
            Text(
              'Otros viajeros confirman o desmienten tu reporte.',
              textAlign: TextAlign.center,
              style: text.bodyMedium,
            ),
        ],
      ),
    );
  }
}

class _Where extends StatelessWidget {
  const _Where({required this.alert});
  final MapAlert alert;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(Icons.location_on_rounded, size: GSSize.iconMd, color: GSColors.textMuted),
        const SizedBox(width: GSSpacing.s2),
        Expanded(
          child: alert.segmentName != null
              ? Text('Troncal · ${alert.segmentName}',
                  maxLines: 2, overflow: TextOverflow.ellipsis, style: text.bodyLarge)
              // La calle, no coordenadas (Geocoding/Places por la función maps).
              : FutureBuilder<String?>(
                  future: geocodingService.reverse(alert.at),
                  builder: (context, snap) => Text(
                    snap.data ??
                        (snap.connectionState == ConnectionState.done
                            ? 'Punto en el mapa'
                            : 'Buscando la dirección…'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyLarge,
                  ),
                ),
        ),
      ],
    );
  }
}

class _Votes extends StatelessWidget {
  const _Votes({required this.alert});
  final MapAlert alert;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = alert.confirmations, d = alert.denials;
    final line = c == 0 && d == 0
        ? 'Nadie lo ha confirmado todavía'
        : [
            if (c > 0) '$c ${c == 1 ? 'dice' : 'dicen'} que sigue',
            if (d > 0) '$d ${d == 1 ? 'dice' : 'dicen'} que ya no está',
          ].join(' · ');
    return Row(
      children: [
        Icon(Icons.groups_rounded, size: GSSize.iconMd, color: GSColors.textMuted),
        const SizedBox(width: GSSpacing.s2),
        Expanded(
          child: Text(line,
              style: text.bodyLarge?.copyWith(fontFeatures: GSFonts.tabular)),
        ),
      ],
    );
  }
}

/// Botón de voto grande (pulgar): el elegido queda lleno.
class _VoteButton extends StatelessWidget {
  const _VoteButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.primary = false,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final filled = selected || (primary && !selected);
    final bg = selected
        ? GSColors.brand
        : primary
            ? GSColors.brandTint
            : GSColors.surfaceSunken;
    final fg = selected ? GSColors.onBrand : primary ? GSColors.brand : GSColors.text;
    return GSPressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: MediaQuery.of(context).disableAnimations ? Duration.zero : GSDuration.fast,
        curve: GSCurve.enter,
        height: GSSize.button,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(GSRadius.full),
          border: filled ? null : Border.all(color: GSColors.line),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: GSSize.iconMd, color: fg),
            const SizedBox(width: GSSpacing.s2),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: GSFonts.sans,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
