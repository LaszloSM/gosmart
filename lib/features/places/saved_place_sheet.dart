// lib/features/places/saved_place_sheet.dart
// Guardar un lugar: Casa, Trabajo o uno con nombre propio ("Donde mi mamá",
// "Gimnasio"), hasta [kMaxSavedPlaces]. La dirección sale del buscador o de
// donde estás ahora mismo. También edita (renombrar, cambiar la dirección) y
// borra.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../models/favorite_place.dart';
import '../../models/geocode_suggestion.dart';
import '../../providers/auth_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../router/app_router.dart';
import '../../services/geocoding_service.dart';
import '../../services/location_service.dart';
import '../../services/place_search.dart';
import '../routes/place_confirm_screen.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_button.dart';
import '../../widgets/gs_toast.dart';

/// Abre la hoja. [type] home/work fija el nombre; custom pide uno.
/// [existing] = editar ese lugar. Sin cuenta lleva a entrar (DS3).
Future<void> showSavedPlaceSheet(
  BuildContext context,
  WidgetRef ref, {
  FavoritePlaceType type = FavoritePlaceType.custom,
  FavoritePlace? existing,
}) async {
  if (ref.read(isGuestProvider)) {
    context.push(AppRoutes.login);
    return;
  }
  if (existing == null &&
      type == FavoritePlaceType.custom &&
      ref.read(customPlacesProvider).length >= kMaxSavedPlaces) {
    GSToast.show(context,
        message: 'Ya tienes $kMaxSavedPlaces lugares guardados. '
            'Borra uno para agregar otro.',
        type: GSToastType.warning);
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    sheetAnimationStyle: MediaQuery.of(context).disableAnimations
        ? AnimationStyle.noAnimation
        : null,
    backgroundColor: GSColors.surface,
    shape: RoundedRectangleBorder(borderRadius: GSRadius.sheetRadius),
    builder: (_) =>
        SavedPlaceSheet(type: existing?.type ?? type, existing: existing),
  );
}

class SavedPlaceSheet extends ConsumerStatefulWidget {
  const SavedPlaceSheet({super.key, required this.type, this.existing});
  final FavoritePlaceType type;
  final FavoritePlace? existing;

  @override
  ConsumerState<SavedPlaceSheet> createState() => _SavedPlaceSheetState();
}

class _SavedPlaceSheetState extends ConsumerState<SavedPlaceSheet> {
  late final _name = TextEditingController(text: _initialName);
  final _query = TextEditingController();
  Timer? _debounce;

  List<GeocodeSuggestion> _suggestions = const [];
  bool _searching = false;
  bool _locating = false;
  bool _saving = false;

  /// Dirección elegida (con coordenadas ya resueltas).
  String? _address;
  LatLng? _at;

  bool get _custom => widget.type == FavoritePlaceType.custom;

  String get _initialName => switch (widget.type) {
        FavoritePlaceType.home => 'Casa',
        FavoritePlaceType.work => 'Trabajo',
        FavoritePlaceType.custom => widget.existing?.name ?? '',
      };

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _address = e.address;
      _at = e.latLng;
    }
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _name.dispose();
    _query.dispose();
    super.dispose();
  }

  void _onQuery(String q) {
    _debounce?.cancel();
    if (q.trim().length < 3) {
      setState(() => _suggestions = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _searching = true);
      final r = await placeSearch.search(q.trim(), near: locationService.last);
      if (!mounted || _query.text.trim() != q.trim()) return;
      setState(() {
        _suggestions = r.items;
        _searching = false;
      });
    });
  }

  Future<void> _pick(GeocodeSuggestion s) async {
    FocusScope.of(context).unfocus();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _searching = true);
    final place = s.latLng != null ? s : await placeSearch.resolve(s);
    if (!mounted) return;
    setState(() => _searching = false);
    if (place?.latLng == null) {
      GSToast.showWithMessenger(messenger,
          message:
              'No pudimos ubicar ese lugar. Revisa tu conexión o elige otro.',
          type: GSToastType.error);
      return;
    }
    // Como en el planificador: el punto exacto se confirma en el mapa (la
    // entrada del edificio, no el centro de la manzana).
    final confirmed = await context.push<GeocodeSuggestion>(
      AppRoutes.placeConfirm,
      extra: PlaceConfirmRequest(place!,
          title: 'Confirma el punto', actionLabel: 'Guardar este punto'),
    );
    if (!mounted || confirmed?.latLng == null) return;
    setState(() {
      _at = confirmed!.latLng;
      _address = confirmed.fullAddress.isNotEmpty
          ? confirmed.fullAddress
          : confirmed.placeName;
      _suggestions = const [];
      _query.clear();
      if (_custom && _name.text.trim().isEmpty) {
        _name.text = place.placeName.length <= kSavedPlaceNameMax
            ? place.placeName
            : place.placeName.substring(0, kSavedPlaceNameMax);
      }
    });
  }

  /// "Estoy aquí": guarda el punto donde está el celular.
  Future<void> _useCurrent() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _locating = true);
    final pos = await locationService.getCurrentPosition();
    if (!mounted) return;
    if (pos == null) {
      setState(() => _locating = false);
      final issue = locationService.lastIssue ?? LocationIssue.noFix;
      GSToast.showWithMessenger(messenger,
          message: locationIssueText(issue),
          type: GSToastType.warning,
          actionLabel: issue == LocationIssue.noFix ? null : 'Activar',
          onAction: () => locationService.fix(issue));
      return;
    }
    final address = await geocodingService.reverse(pos);
    if (!mounted) return;
    setState(() {
      _locating = false;
      _at = pos;
      _address = address ?? 'Punto en el mapa';
    });
  }

  Future<void> _save() async {
    final at = _at;
    if (at == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() => _saving = true);
    final notifier = ref.read(favoritesNotifierProvider.notifier);
    String? error;
    if (_custom) {
      error = await notifier.saveNamedPlace(
        id: widget.existing?.id,
        name: _name.text,
        address: _address ?? 'Punto en el mapa',
        latitude: at.latitude,
        longitude: at.longitude,
      );
    } else {
      final ok = await notifier.addOrUpdatePlace(
        name: _initialName,
        address: _address ?? 'Punto en el mapa',
        latitude: at.latitude,
        longitude: at.longitude,
        type: widget.type,
      );
      if (!ok) {
        error = 'No se pudo guardar. Revisa tu conexión e intenta de nuevo.';
      }
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      GSToast.showWithMessenger(messenger,
          message: error, type: GSToastType.error);
      return;
    }
    nav.pop();
    GSToast.showWithMessenger(messenger,
        message: '${_custom ? _name.text.trim() : _initialName} guardado',
        type: GSToastType.success);
  }

  Future<void> _delete() async {
    final e = widget.existing;
    if (e == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Borrar "${e.name}"?'),
        content: const Text('Lo puedes volver a guardar cuando quieras.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Borrar')),
        ],
      ),
    );
    if (ok != true) return;
    final done =
        await ref.read(favoritesNotifierProvider.notifier).removePlace(e.id);
    if (!mounted) return;
    if (done) nav.pop();
    GSToast.showWithMessenger(messenger,
        message:
            done ? '${e.name} borrado' : 'No se pudo borrar. Intenta de nuevo.',
        type: done ? GSToastType.info : GSToastType.error);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final editing = widget.existing != null;
    final title = switch (widget.type) {
      FavoritePlaceType.home => editing ? 'Cambiar Casa' : 'Guardar Casa',
      FavoritePlaceType.work => editing ? 'Cambiar Trabajo' : 'Guardar Trabajo',
      FavoritePlaceType.custom => editing ? 'Editar lugar' : 'Guardar un lugar',
    };
    final canSave =
        _at != null && !_saving && (!_custom || _name.text.trim().isNotEmpty);

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
            GSSpacing.s5, GSSpacing.s3, GSSpacing.s5, GSSpacing.s4),
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
                Expanded(child: Text(title, style: text.titleLarge)),
                if (editing && _custom)
                  IconButton(
                    tooltip: 'Borrar lugar',
                    onPressed: _saving ? null : _delete,
                    icon: Icon(Icons.delete_outline_rounded,
                        color: GSColors.textMuted),
                  ),
              ],
            ),
            if (_custom) ...[
              const SizedBox(height: GSSpacing.s3),
              TextField(
                controller: _name,
                autofocus: !editing,
                textCapitalization: TextCapitalization.sentences,
                maxLength: kSavedPlaceNameMax,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(kSavedPlaceNameMax),
                ],
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  hintText: 'Ej.: Donde mi mamá, Gimnasio, Colegio',
                  prefixIcon: Icon(Icons.label_rounded),
                ),
              ),
            ],
            const SizedBox(height: GSSpacing.s2),
            // Dirección elegida.
            if (_address != null)
              Container(
                padding: const EdgeInsets.all(GSSpacing.s3),
                decoration: BoxDecoration(
                  color: GSColors.brandTint,
                  borderRadius: BorderRadius.circular(GSRadius.md),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on_rounded, color: GSColors.brand),
                    const SizedBox(width: GSSpacing.s2),
                    Expanded(
                      child: Text(
                        _address!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium?.copyWith(color: GSColors.text),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: GSSpacing.s3),
            TextField(
              controller: _query,
              onChanged: _onQuery,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText:
                    _address == null ? 'Dirección' : 'Cambiar la dirección',
                hintText: 'Busca una dirección o un sitio',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
            ),
            for (final s in _suggestions)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(s.icon, color: GSColors.textMuted),
                title: Text(s.placeName,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(s.fullAddress,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => _pick(s),
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: _locating
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.my_location_rounded, color: GSColors.brand),
              title: const Text('Usar mi ubicación actual'),
              subtitle: const Text('Guarda el punto donde estás ahora'),
              onTap: _locating ? null : _useCurrent,
            ),
            const SizedBox(height: GSSpacing.s3),
            GSButton(
              label: 'Guardar',
              isFullWidth: true,
              isLoading: _saving,
              onPressed: canSave ? _save : null,
            ),
          ],
        ),
      ),
    );
  }
}
