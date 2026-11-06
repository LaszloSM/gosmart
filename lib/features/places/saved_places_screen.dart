// lib/features/places/saved_places_screen.dart
// "Mis lugares": Casa, Trabajo y hasta [kMaxSavedPlaces] lugares con nombre.
// Tocar uno lo edita; "Agregar lugar" abre la hoja para guardar otro.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/favorite_place.dart';
import '../../providers/favorites_provider.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_button.dart';
import '../../widgets/gs_list_row.dart';
import 'saved_place_sheet.dart';

class SavedPlacesScreen extends ConsumerWidget {
  const SavedPlacesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final loading = ref.watch(favoritePlacesProvider).isLoading;
    final home = ref.watch(homePlaceProvider);
    final work = ref.watch(workPlaceProvider);
    final custom = ref.watch(customPlacesProvider);
    final full = custom.length >= kMaxSavedPlaces;

    Widget fixedRow(FavoritePlace? p, FavoritePlaceType type, String label,
            IconData icon) =>
        GSListRow(
          icon: icon,
          title: label,
          subtitle: p?.address ?? 'Toca para guardarla',
          onTap: () =>
              showSavedPlaceSheet(context, ref, type: type, existing: p),
        );

    return Scaffold(
      backgroundColor: GSColors.background,
      appBar: AppBar(title: const Text('Mis lugares')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(favoritePlacesProvider.future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              GSSpacing.s4, GSSpacing.s3, GSSpacing.s4, GSSpacing.s8),
          children: [
            GSGroup(children: [
              fixedRow(
                  home, FavoritePlaceType.home, 'Casa', Icons.home_rounded),
              fixedRow(
                  work, FavoritePlaceType.work, 'Trabajo', Icons.work_rounded),
            ]),
            const SizedBox(height: GSSpacing.s5),
            Row(
              children: [
                Expanded(
                    child: Text('Lugares con nombre', style: text.titleMedium)),
                Text(
                  '${custom.length} de $kMaxSavedPlaces',
                  style:
                      text.bodyMedium?.copyWith(fontFeatures: GSFonts.tabular),
                ),
              ],
            ),
            const SizedBox(height: GSSpacing.s2),
            if (loading && custom.isEmpty)
              const Padding(
                padding: EdgeInsets.all(GSSpacing.s6),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (custom.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: GSSpacing.s3),
                child: Text(
                  'Guarda los sitios a los que vas seguido (donde tu familia, el '
                  'colegio, el gimnasio) para pedir el viaje con un toque.',
                  style: text.bodyMedium,
                ),
              )
            else
              GSGroup(children: [
                for (final p in custom)
                  GSListRow(
                    icon: Icons.location_on_rounded,
                    title: p.name,
                    subtitle: p.address,
                    onTap: () => showSavedPlaceSheet(context, ref, existing: p),
                  ),
              ]),
            const SizedBox(height: GSSpacing.s4),
            GSButton(
              label: full
                  ? 'Llegaste al máximo de $kMaxSavedPlaces'
                  : 'Agregar lugar',
              leadingIcon: Icons.add_location_alt_rounded,
              isFullWidth: true,
              variant: GSButtonVariant.outline,
              onPressed: full ? null : () => showSavedPlaceSheet(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}
