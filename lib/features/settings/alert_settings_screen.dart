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
    // El nivel común si todos coinciden; si no, ninguno marcado.
    final levels = {for (final p in prefs.values) _level(p)};
    final allLevel = levels.length == 1 ? levels.first : null;

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
          const GSSectionTitle('Todas a la vez'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: GSSpacing.s4),
            child: _LevelPicker(
              level: allLevel,
              onChanged: (l) => notifier.setAll(show: l > 0, warn: l > 1),
            ),
          ),
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

int _level(AlertPref p) => !p.show ? 0 : (p.warn ? 2 : 1);

/// Ocultar / Ver / Ver y avisar: una sola decisión por tipo, sin interruptores
/// anidados (Waze lo separa en dos; aquí se lee de una vez).
class _LevelPicker extends StatelessWidget {
  const _LevelPicker({required this.level, required this.onChanged});
  final int? level;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget label(String s) => FittedBox(fit: BoxFit.scaleDown, child: Text(s, maxLines: 1));
    return SegmentedButton<int>(
      showSelectedIcon: false,
      emptySelectionAllowed: true,
      segments: [
        ButtonSegment(value: 0, icon: const Icon(Icons.visibility_off_rounded), label: label('Ocultar')),
        ButtonSegment(value: 1, icon: const Icon(Icons.visibility_rounded), label: label('Ver')),
        ButtonSegment(value: 2, icon: const Icon(Icons.notifications_active_rounded), label: label('Avisar')),
      ],
      selected: {if (level != null) level!},
      onSelectionChanged: (s) {
        if (s.isNotEmpty) onChanged(s.first);
      },
    );
  }
}

/// Una fila por tipo: globo, nombre, para qué sirve y su nivel.
class _KindRow extends StatelessWidget {
  const _KindRow({required this.kind, required this.pref, required this.onChanged});
  final AlertKind kind;
  final AlertPref pref;
  final ValueChanged<AlertPref> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(GSSpacing.s4, GSSpacing.s3, GSSpacing.s4, GSSpacing.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
            ],
          ),
          const SizedBox(height: GSSpacing.s2),
          _LevelPicker(
            level: _level(pref),
            onChanged: (l) => onChanged(AlertPref(show: l > 0, warn: l > 1)),
          ),
        ],
      ),
    );
  }
}
