// lib/features/settings/alert_settings_screen.dart
// Qué alertas quieres, como en Waze (Configuración › Alertas y reportes):
// por cada tipo, "Ver en el mapa" y, si se ve, "Avisarme al acercarme".
// Arriba, una vista previa con los globos tal como salen en el mapa.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/motion.dart';
import '../../models/map_alert.dart';
import '../../providers/map_alerts_provider.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_alert_badge.dart';
import '../../widgets/gs_list_row.dart';
import '../../widgets/gs_nav_spacer.dart';

class AlertSettingsScreen extends ConsumerWidget {
  const AlertSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(alertPrefsProvider);
    final notifier = ref.read(alertPrefsProvider.notifier);
    final text = Theme.of(context).textTheme;
    final allShown = prefs.values.every((p) => p.show);
    final anyWarn = prefs.values.any((p) => p.show && p.warn);

    return Scaffold(
      backgroundColor: GSColors.background,
      appBar: AppBar(title: const Text('Alertas en el mapa')),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Vista previa: los globos de los tipos activos, en fila.
          Padding(
            padding: const EdgeInsets.fromLTRB(GSSpacing.s4, GSSpacing.s3, GSSpacing.s4, 0),
            child: Container(
              padding: const EdgeInsets.all(GSSpacing.s4),
              decoration: BoxDecoration(
                color: GSColors.surface,
                borderRadius: BorderRadius.circular(GSRadius.lg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Así las ves en el mapa', style: text.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    'De cerca, globos con su ícono; de lejos, puntos de color. '
                    'Rojo: cierre o choque. Ámbar: precaución.',
                    style: text.bodySmall,
                  ),
                  const SizedBox(height: GSSpacing.s3),
                  Wrap(
                    spacing: GSSpacing.s2,
                    runSpacing: GSSpacing.s2,
                    children: [
                      for (final k in AlertKind.all)
                        AnimatedOpacity(
                          opacity: prefs[k.id]!.show ? 1 : 0.25,
                          duration: MediaQuery.of(context).disableAnimations
                              ? Duration.zero
                              : GSDuration.fast,
                          child: GSAlertBadge(kind: k, size: 36),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const GSSectionTitle('Todas'),
          GSGroup(children: [
            SwitchListTile(
              value: allShown,
              onChanged: (v) => notifier.setAll(show: v),
              title: const Text('Ver todas en el mapa'),
              secondary: const Icon(Icons.layers_rounded),
            ),
            SwitchListTile(
              value: anyWarn,
              onChanged: (v) => notifier.setAll(warn: v),
              title: const Text('Avisarme al acercarme'),
              subtitle: const Text('Un aviso arriba del mapa a unos 400 m'),
              secondary: const Icon(Icons.notifications_active_rounded),
            ),
          ]),
          const GSSectionTitle('Por tipo'),
          GSGroup(children: [
            for (var i = 0; i < AlertKind.all.length; i++)
              _KindRow(
                kind: AlertKind.all[i],
                pref: prefs[AlertKind.all[i].id]!,
                onChanged: (p) => notifier.set(AlertKind.all[i].id, p),
              ).gsEnter(context, delay: Duration(milliseconds: 18 * i), slide: const Offset(0, 0.06)),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(GSSpacing.s4, GSSpacing.s4, GSSpacing.s4, 0),
            child: Text(
              'Estas preferencias son de este teléfono. Lo que ocultas no se '
              'borra: los demás lo siguen viendo.',
              style: text.bodySmall,
            ),
          ),
          const GSNavSpacer(),
        ],
      ),
    );
  }
}

/// Una fila por tipo: globo, nombre, para qué sirve y el interruptor de
/// "Ver en el mapa". Si se ve, debajo aparece "Avisarme" (con AnimatedSize).
class _KindRow extends StatelessWidget {
  const _KindRow({required this.kind, required this.pref, required this.onChanged});
  final AlertKind kind;
  final AlertPref pref;
  final ValueChanged<AlertPref> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final reduce = MediaQuery.of(context).disableAnimations;
    return Padding(
      padding: const EdgeInsets.fromLTRB(GSSpacing.s4, GSSpacing.s3, GSSpacing.s2, GSSpacing.s2),
      child: Column(
        children: [
          Row(
            children: [
              GSAlertBadge(kind: kind, size: 40, ring: false),
              const SizedBox(width: GSSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(kind.label, style: text.titleMedium),
                    Text(kind.hint, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.bodySmall),
                  ],
                ),
              ),
              Switch(
                value: pref.show,
                onChanged: (v) => onChanged(pref.copyWith(show: v)),
              ),
            ],
          ),
          AnimatedSize(
            duration: reduce ? const Duration(milliseconds: 1) : GSDuration.normal,
            curve: GSCurve.enter,
            child: pref.show
                ? Padding(
                    padding: const EdgeInsets.only(left: 52),
                    child: Row(
                      children: [
                        Icon(Icons.notifications_rounded, size: GSSize.iconSm, color: GSColors.textMuted),
                        const SizedBox(width: GSSpacing.s2),
                        Expanded(child: Text('Avisarme al acercarme', style: text.bodyMedium)),
                        Switch(
                          value: pref.warn,
                          onChanged: (v) => onChanged(pref.copyWith(warn: v)),
                        ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
