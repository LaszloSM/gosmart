// lib/features/home/widgets/quick_places_row.dart
// Fila horizontal de accesos rápidos: Casa, Trabajo y favoritos frecuentes
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/favorite_place.dart';
import '../../../models/geocode_suggestion.dart';
import '../../../providers/favorites_provider.dart';
import '../../../services/geocoding_service.dart';
import '../../../theme/design_tokens.dart';
import '../../../widgets/gs_button.dart';

class QuickPlacesRow extends ConsumerWidget {
  final Function(FavoritePlace) onPlaceSelected;

  const QuickPlacesRow({super.key, required this.onPlaceSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homePlaceProvider);
    final work = ref.watch(workPlaceProvider);
    final topPlaces = ref.watch(topFavoritePlacesProvider);

    final customPlaces = topPlaces
        .where((p) => p.type == FavoritePlaceType.custom)
        .take(3)
        .toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: GSSpacing.s4),
      child: Row(
        children: [
          // Casa
          _QuickChip(
            label: home != null ? 'Casa' : 'Agregar casa',
            icon: Icons.home_rounded,
            color: GSColors.accent,
            isSet: home != null,
            onTap: () {
              if (home != null) {
                ref.read(favoritesNotifierProvider.notifier)
                    .incrementUseCount(home.id);
                onPlaceSelected(home);
              } else {
                _showSetPlaceSheet(context, ref, FavoritePlaceType.home);
              }
            },
          ),
          const SizedBox(width: GSSpacing.s2),

          // Trabajo
          _QuickChip(
            label: work != null ? 'Trabajo' : 'Agregar trabajo',
            icon: Icons.work_rounded,
            color: GSColors.accentAlt,
            isSet: work != null,
            onTap: () {
              if (work != null) {
                ref.read(favoritesNotifierProvider.notifier)
                    .incrementUseCount(work.id);
                onPlaceSelected(work);
              } else {
                _showSetPlaceSheet(context, ref, FavoritePlaceType.work);
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
                  onTap: () {
                    ref.read(favoritesNotifierProvider.notifier)
                        .incrementUseCount(place.id);
                    onPlaceSelected(place);
                  },
                ),
              )),
        ],
      ),
    );
  }

  void _showSetPlaceSheet(
    BuildContext context,
    WidgetRef ref,
    FavoritePlaceType type,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: GSColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(GSRadius.xxl)),
      ),
      builder: (_) => _SetPlaceSheet(type: type),
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

  const _QuickChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSet,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: GSSpacing.s3,
          vertical: GSSpacing.s2,
        ),
        decoration: BoxDecoration(
          color: isSet
              ? color.withValues(alpha: 0.15)
              : GSColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(GSRadius.full),
          border: Border.all(
            color: isSet
                ? color.withValues(alpha: 0.35)
                : GSColors.border.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSet ? color : GSColors.textSecondary,
            ),
            const SizedBox(width: GSSpacing.s2),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSet ? color : GSColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bottom sheet para configurar casa/trabajo ────────────────────────────────

class _SetPlaceSheet extends ConsumerStatefulWidget {
  final FavoritePlaceType type;
  const _SetPlaceSheet({required this.type});

  @override
  ConsumerState<_SetPlaceSheet> createState() => _SetPlaceSheetState();
}

class _SetPlaceSheetState extends ConsumerState<_SetPlaceSheet> {
  final _ctrl = TextEditingController();
  List<GeocodeSuggestion> _suggestions = [];
  GeocodeSuggestion? _selected;
  bool _searching = false;
  bool _saving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.type == FavoritePlaceType.home
        ? 'Configurar Casa'
        : 'Configurar Trabajo';
    final icon = widget.type == FavoritePlaceType.home
        ? Icons.home_rounded
        : Icons.work_rounded;
    final color = widget.type == FavoritePlaceType.home
        ? GSColors.accent
        : GSColors.accentAlt;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(GSSpacing.s5),
        decoration: const BoxDecoration(
          color: GSColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(GSRadius.xxl),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: GSColors.border,
                  borderRadius: BorderRadius.circular(GSRadius.full),
                ),
              ),
            ),
            const SizedBox(height: GSSpacing.s4),
            // Título
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(GSRadius.sm),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: GSSpacing.s3),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: GSColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: GSSpacing.s4),
            // Campo de búsqueda
            Container(
              decoration: BoxDecoration(
                color: GSColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(GSRadius.md),
                border: Border.all(
                  color: GSColors.border.withValues(alpha: 0.5),
                ),
              ),
              child: TextField(
                controller: _ctrl,
                style: const TextStyle(
                  color: GSColors.textPrimary,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'Buscar dirección...',
                  hintStyle:
                      const TextStyle(color: GSColors.textSecondary, fontSize: 14),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: GSColors.textSecondary,
                    size: 20,
                  ),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: GSColors.accent,
                            ),
                          ),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: GSSpacing.s4,
                    vertical: GSSpacing.s3,
                  ),
                ),
                onChanged: _onSearch,
              ),
            ),
            // Sugerencias
            if (_suggestions.isNotEmpty) ...[
              const SizedBox(height: GSSpacing.s2),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                decoration: BoxDecoration(
                  color: GSColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(GSRadius.md),
                  border: Border.all(
                    color: GSColors.border.withValues(alpha: 0.4),
                  ),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _suggestions.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: GSColors.border.withValues(alpha: 0.3),
                  ),
                  itemBuilder: (_, i) {
                    final s = _suggestions[i];
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.location_on_outlined,
                        color: color,
                        size: 18,
                      ),
                      title: Text(
                        s.placeName,
                        style: const TextStyle(
                          fontSize: 13,
                          color: GSColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        s.fullAddress,
                        style: const TextStyle(
                          fontSize: 11,
                          color: GSColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        setState(() {
                          _selected = s;
                          _suggestions = [];
                          _ctrl.text = s.placeName;
                        });
                        FocusScope.of(context).unfocus();
                      },
                    );
                  },
                ),
              ),
            ],
            // Lugar seleccionado
            if (_selected != null) ...[
              const SizedBox(height: GSSpacing.s3),
              Container(
                padding: const EdgeInsets.all(GSSpacing.s3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(GSRadius.md),
                  border: Border.all(color: color.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Icon(icon, color: color, size: 18),
                    const SizedBox(width: GSSpacing.s2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selected!.placeName,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                          Text(
                            _selected!.fullAddress,
                            style: const TextStyle(
                              fontSize: 11,
                              color: GSColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: GSColors.textSecondary,
                        size: 16,
                      ),
                      onPressed: () => setState(() => _selected = null),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: GSSpacing.s5),
            // Botón guardar
            GSButton(
              label: _saving ? 'Guardando...' : 'Guardar',
              isLoading: _saving,
              onPressed: _selected != null && !_saving ? _save : null,
            ),
            const SizedBox(height: GSSpacing.s2),
          ],
        ),
      ),
    );
  }

  Future<void> _onSearch(String query) async {
    if (query.length < 2) {
      setState(() => _suggestions = []);
      return;
    }
    setState(() => _searching = true);
    final results = await geocodingService.search(query);
    if (mounted) {
      setState(() {
        _suggestions = results;
        _searching = false;
      });
    }
  }

  Future<void> _save() async {
    if (_selected == null) return;
    setState(() => _saving = true);

    final success = await ref.read(favoritesNotifierProvider.notifier)
        .addOrUpdatePlace(
          name: widget.type == FavoritePlaceType.home ? 'Casa' : 'Trabajo',
          address: _selected!.fullAddress,
          latitude: _selected!.latLng.latitude,
          longitude: _selected!.latLng.longitude,
          type: widget.type,
        );

    setState(() => _saving = false);

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '${widget.type.name == 'home' ? 'Casa' : 'Trabajo'} guardado'
                : 'Error al guardar. Intenta de nuevo.',
          ),
          backgroundColor: success ? GSColors.success : GSColors.error,
        ),
      );
    }
  }
}
