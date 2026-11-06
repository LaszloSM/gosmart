// lib/features/home/widgets/quick_places_row.dart
// Fila horizontal de accesos rápidos: Casa, Trabajo, tus lugares con nombre
// (hasta 10, los más usados primero) y "Agregar". Mantener presionado un
// lugar lo edita.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/favorite_place.dart';
import '../../../providers/favorites_provider.dart';
import '../../../theme/design_tokens.dart';
import '../../../widgets/gs_pressable.dart';
import '../../places/saved_place_sheet.dart';

class QuickPlacesRow extends ConsumerWidget {
  final Function(FavoritePlace) onPlaceSelected;

  const QuickPlacesRow({super.key, required this.onPlaceSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homePlaceProvider);
    final work = ref.watch(workPlaceProvider);
    final customPlaces = ref.watch(customPlacesProvider);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: GSSpacing.s4),
      child: Row(
        children: [
          // Casa
          _QuickChip(
            label: 'Casa',
            icon: Icons.home_rounded,
            color: GSColors.accent,
            isSet: home != null,
            onLongPress: home == null
                ? null
                : () => showSavedPlaceSheet(context, ref, existing: home),
            onTap: () {
              if (home != null) {
                ref
                    .read(favoritesNotifierProvider.notifier)
                    .incrementUseCount(home.id);
                onPlaceSelected(home);
              } else {
                showSavedPlaceSheet(context, ref, type: FavoritePlaceType.home);
              }
            },
          ),
          const SizedBox(width: GSSpacing.s2),

          // Trabajo
          _QuickChip(
            label: 'Trabajo',
            icon: Icons.work_rounded,
            color: GSColors.accentAlt,
            isSet: work != null,
            onLongPress: work == null
                ? null
                : () => showSavedPlaceSheet(context, ref, existing: work),
            onTap: () {
              if (work != null) {
                ref
                    .read(favoritesNotifierProvider.notifier)
                    .incrementUseCount(work.id);
                onPlaceSelected(work);
              } else {
                showSavedPlaceSheet(context, ref, type: FavoritePlaceType.work);
              }
            },
          ),

          // Favoritos personalizados frecuentes
          ...customPlaces.map((place) => Padding(
                padding: const EdgeInsets.only(left: GSSpacing.s2),
                child: _QuickChip(
                  label: place.name,
                  icon: place.iconData,
                  color: GSColors.textSecondary,
                  isSet: true,
                  onLongPress: () =>
                      showSavedPlaceSheet(context, ref, existing: place),
                  onTap: () {
                    ref
                        .read(favoritesNotifierProvider.notifier)
                        .incrementUseCount(place.id);
                    onPlaceSelected(place);
                  },
                ),
              )),

          // Guardar otro lugar con nombre (hasta kMaxSavedPlaces).
          if (customPlaces.length < kMaxSavedPlaces)
            Padding(
              padding: const EdgeInsets.only(left: GSSpacing.s2),
              child: _QuickChip(
                label: 'Lugar',
                icon: Icons.add_rounded,
                color: GSColors.textSecondary,
                isSet: false,
                onTap: () => showSavedPlaceSheet(context, ref),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Chip individual ──────────────────────────────────────────────────────────

class _QuickChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSet;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _QuickChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSet,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    // Píldora con el ícono en un círculo y el nombre (accesos de Uber/Google
    // Maps). Sin lugar guardado, el círculo es gris con "+" y dice "Agregar".
    return GestureDetector(
      onLongPress: onLongPress,
      child: GSPressable(
        onTap: onTap,
        semanticLabel: isSet ? label : 'Agregar ${label.toLowerCase()}',
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.fromLTRB(6, 6, GSSpacing.s4, 6),
          decoration: BoxDecoration(
            color: GSColors.surface,
            borderRadius: BorderRadius.circular(GSRadius.full),
            border: Border.all(color: GSColors.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isSet ? GSColors.brandTint : GSColors.surfaceSunken,
                  shape: BoxShape.circle,
                ),
                child: Icon(isSet ? icon : Icons.add_rounded,
                    size: GSSize.iconMd,
                    color: isSet ? GSColors.brand : GSColors.text),
              ),
              const SizedBox(width: GSSpacing.s2),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: GSFonts.sans,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: GSColors.text,
                      ),
                    ),
                    if (!isSet)
                      Text(
                        'Agregar',
                        style: TextStyle(
                          fontFamily: GSFonts.sans,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: GSColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
