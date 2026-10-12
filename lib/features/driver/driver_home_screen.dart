// lib/features/driver/driver_home_screen.dart
// Modo conductor (DS6): una mano, acciones en la mitad de abajo, botones de
// 72 dp y máximo dos acciones por pantalla. Según el estado del registro:
//   sin registro → invitación; pendiente → documentos que faltan;
//   rechazado → motivo y corregir; aprobado → Disponible / No disponible.
// Disponible y aprobado: DriverWorkPanel (solicitudes cercanas, viaje activo,
// salidas de colectivo).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/driver_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/driver_provider.dart';
import '../../router/app_router.dart';
import '../../services/driver_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_button.dart';
import '../../widgets/gs_empty_state.dart';
import '../../widgets/gs_inline_error.dart';
import '../../widgets/gs_list_row.dart';
import '../../widgets/gs_route_plate.dart';
import '../../widgets/gs_toast.dart';
import 'driver_work_panel.dart';

class DriverHomeScreen extends ConsumerWidget {
  const DriverHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driver = ref.watch(myDriverProvider);
    final d = driver.valueOrNull;
    final approved = d?.status == DriverStatus.approved;
    return Scaffold(
      backgroundColor: GSColors.background,
      // Lo secundario va arriba; la zona del pulgar queda para lo que toca ahora (DS6).
      appBar: AppBar(
        title: const Text('Modo conductor'),
        actions: [
          if (approved)
            IconButton(
              tooltip: 'Cobrar con QR',
              icon: const Icon(Icons.qr_code_2_rounded),
              onPressed: () => context.push(AppRoutes.driverCharge),
            ),
          if (d != null)
            IconButton(
              tooltip: 'Editar mis datos',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push(AppRoutes.driverSignup),
            ),
          if (approved && d!.available)
            TextButton(
              style: TextButton.styleFrom(foregroundColor: GSColors.onShell),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await driverService.setAvailable(d.userId, false);
                  ref.invalidate(myDriverProvider);
                } catch (_) {
                  GSToast.showWithMessenger(messenger,
                      message: 'No pudimos pausarte. Revisa tu conexión.',
                      type: GSToastType.error);
                }
              },
              child: const Text('Pausar'),
            ),
        ],
      ),
      body: driver.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Padding(
          padding: const EdgeInsets.all(GSSpacing.s4),
          child: GSInlineError(
            message: 'No pudimos cargar tu registro',
            onRetry: () => ref.invalidate(myDriverProvider),
          ),
        ),
        data: (d) => d == null
            ? ListView(children: [
                GSEmptyState(
                  icon: Icons.two_wheeler_rounded,
                  title: 'Maneja con GoSmart',
                  subtitle: 'Mototaxi, taxi, colectivo o intermunicipal. '
                      'Te registras, revisamos tus documentos y empiezas.',
                  actionLabel: 'Registrarme',
                  onAction: () => context.push(AppRoutes.driverSignup),
                ),
              ])
            : _DriverBody(driver: d),
      ),
    );
  }
}

class _DriverBody extends ConsumerStatefulWidget {
  const _DriverBody({required this.driver});
  final DriverProfile driver;

  @override
  ConsumerState<_DriverBody> createState() => _DriverBodyState();
}

class _DriverBodyState extends ConsumerState<_DriverBody> {
  String? _uploading;
  bool _toggling = false;

  Future<void> _upload(String kind) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final file = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      imageQuality: 80,
    );
    if (file == null) return;
    setState(() => _uploading = kind);
    try {
      await driverService.uploadDocument(user.id, kind, file);
      ref.invalidate(myDriverProvider);
    } catch (_) {
      GSToast.showWithMessenger(messenger,
          message: 'No se subió la foto. Intenta con mejor señal.',
          type: GSToastType.error);
    } finally {
      if (mounted) setState(() => _uploading = null);
    }
  }

  Future<void> _toggle() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _toggling = true);
    try {
      await driverService.setAvailable(
          widget.driver.userId, !widget.driver.available);
      ref.invalidate(myDriverProvider);
    } catch (_) {
      GSToast.showWithMessenger(messenger,
          message: 'No pudimos cambiar tu estado. Revisa tu conexión.',
          type: GSToastType.error);
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.driver;
    final text = Theme.of(context).textTheme;
    final approved = d.status == DriverStatus.approved;

    final (statusTitle, statusDetail) = switch (d.status) {
      DriverStatus.approved => d.available
          ? ('Disponible', 'Las solicitudes cercanas aparecen abajo mientras '
              'esta pantalla esté abierta.')
          : ('No disponible', 'Nadie te ve. Ponte disponible cuando '
              'quieras trabajar.'),
      DriverStatus.pending => d.isComplete
          ? ('En revisión', 'Revisamos tus documentos en uno o dos días.')
          : ('Faltan documentos',
              'Sube los que faltan para que revisemos tu registro.'),
      DriverStatus.rejected => ('Registro rechazado',
          d.reviewNote ?? 'Corrige tus datos o documentos y vuelve a enviar.'),
      DriverStatus.suspended => ('Cuenta suspendida',
          d.reviewNote ?? 'Escríbenos para saber cómo reactivarla.'),
    };

    final plate = Padding(
      padding: const EdgeInsets.fromLTRB(
          GSSpacing.s4, GSSpacing.s4, GSSpacing.s4, 0),
      child: GSRoutePlate(
        text: statusTitle,
        detail: statusDetail,
        detailMaxLines: 4,
        leading: approved && d.available
            ? Icons.radio_button_checked_rounded
            : Icons.radio_button_unchecked_rounded,
        isActive: approved && d.available,
        size: GSPlateSize.lg,
      ),
    );
    // Disponible: el panel de trabajo ocupa la pantalla y maneja la zona del pulgar.
    if (approved && d.available) {
      return DriverWorkPanel(driver: d, header: [plate]);
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: GSSpacing.s4),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    GSSpacing.s4, GSSpacing.s4, GSSpacing.s4, 0),
                child: GSRoutePlate(
                  text: statusTitle,
                  detail: statusDetail,
                  detailMaxLines: 4,
                  leading: approved && d.available
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  isActive: approved && d.available,
                  size: GSPlateSize.lg,
                ),
              ),
              const GSSectionTitle('Tu servicio'),
              GSListRow(
                icon: Icons.badge_outlined,
                title: d.fullName,
                subtitle:
                    '${driverServices[d.service]} · ${driverZones[d.zone]}',
              ),
              if (d.vehicle != null) ...[
                const Divider(indent: GSSpacing.s4),
                GSListRow(
                  icon: d.vehicle!.kind == 'moto'
                      ? Icons.two_wheeler_rounded
                      : Icons.directions_car_outlined,
                  title: 'Placa ${d.vehicle!.plate}',
                  subtitle: [
                    if ((d.vehicle!.brand ?? '').isNotEmpty) d.vehicle!.brand!,
                    if ((d.vehicle!.color ?? '').isNotEmpty) d.vehicle!.color!,
                    if (d.vehicle!.seats > 1) '${d.vehicle!.seats} puestos',
                  ].join(' · '),
                ),
              ],
              if (!approved) ...[
                const GSSectionTitle('Documentos'),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      GSSpacing.s4, 0, GSSpacing.s4, GSSpacing.s2),
                  child: Text(
                    'Toma la foto con buena luz y que se lea todo. Solo la '
                    've el equipo que verifica conductores.',
                    style: text.bodySmall,
                  ),
                ),
                for (final e in driverDocuments.entries) ...[
                  GSListRow(
                    icon: d.documents.contains(e.key)
                        ? Icons.check_circle_outline_rounded
                        : Icons.photo_camera_outlined,
                    title: e.value,
                    subtitle: d.documents.contains(e.key)
                        ? 'Subido · toca para cambiarlo'
                        : requiredDriverDocuments.contains(e.key)
                            ? 'Falta'
                            : 'Si tu vehículo la necesita',
                    trailing: _uploading == e.key
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child:
                                CircularProgressIndicator(strokeWidth: 2.5))
                        : null,
                    onTap: _uploading == null ? () => _upload(e.key) : null,
                  ),
                  const Divider(indent: GSSpacing.s4),
                ],
              ],
            ],
          ),
        ),
        // Zona del pulgar: una sola acción grande (DS6).
        if (approved)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  GSSpacing.s4, GSSpacing.s2, GSSpacing.s4, GSSpacing.s3),
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(minHeight: GSSize.touchTargetDriver),
                child: GSButton(
                  label: 'Ponerme disponible',
                  size: GSButtonSize.driver,
                  isLoading: _toggling,
                  onPressed: _toggling ? null : _toggle,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
