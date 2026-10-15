// lib/features/safety/trip_share_section.dart
// "Compartir mi viaje" y "Ayuda" dentro del detalle de la ruta. Compartir crea
// un link que expira (4 h) y lo manda por WhatsApp; sin página pública
// configurada, manda el punto de salida en Google Maps y lo dice.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/env.dart';
import '../../core/safety_links.dart';
import '../../providers/auth_provider.dart';
import '../../providers/safety_provider.dart';
import '../../router/app_router.dart';
import '../../services/location_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_list_row.dart';
import '../../widgets/gs_toast.dart';
import 'sos_sheet.dart';

class TripShareSection extends ConsumerStatefulWidget {
  const TripShareSection({
    super.key,
    required this.destination,
    required this.mode,
  });

  final String destination;
  final String mode;

  @override
  ConsumerState<TripShareSection> createState() => _TripShareSectionState();
}

class _TripShareSectionState extends ConsumerState<TripShareSection> {
  bool _busy = false;

  Future<void> _share() async {
    if (ref.read(isGuestProvider)) {
      context.push(AppRoutes.login);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final String text;
      if (Env.shareBaseUrl.isEmpty) {
        // Sin página pública un link no sirve: va el punto de salida.
        final at = await locationService.getCurrentPosition();
        text = tripShareMessage(
            destination: widget.destination, mode: widget.mode, at: at);
      } else {
        final share = await ref
            .read(tripShareProvider.notifier)
            .start(destination: widget.destination, mode: widget.mode);
        text = tripShareMessage(
          destination: widget.destination,
          mode: widget.mode,
          link: tripShareLink(Env.shareBaseUrl, share.token),
          until: share.expiresAt,
        );
      }
      await launchUrl(whatsappUri(text), mode: LaunchMode.externalApplication)
          .catchError((_) => false);
    } catch (_) {
      GSToast.showWithMessenger(messenger,
          message: 'No pudimos crear el link. Revisa tu conexión.',
          type: GSToastType.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(tripShareProvider.notifier).stop();
      GSToast.showWithMessenger(messenger, message: 'Dejaste de compartir');
    } catch (_) {
      GSToast.showWithMessenger(messenger,
          message: 'Sin conexión: el link vence solo a la hora indicada.',
          type: GSToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final share = ref.watch(tripShareProvider);
    final active = share != null && share.isActive;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GSSectionTitle('Seguridad'),
        GSGroup(children: [
          if (active)
            GSListRow(
              icon: Icons.share_location_rounded,
              iconColor: GSColors.brand,
              title: 'Compartiendo tu viaje',
              subtitle: 'Hasta las ${clock12(share.expiresAt)}. '
                  'Se actualiza cada minuto con la app abierta.',
              trailing:
                  TextButton(onPressed: _stop, child: const Text('Detener')),
            )
          else
            GSListRow(
              icon: Icons.share_location_rounded,
              title: 'Compartir mi viaje',
              subtitle: Env.shareBaseUrl.isEmpty
                  ? 'Manda a dónde vas y desde dónde sales por WhatsApp'
                  : 'Un link por WhatsApp que vence en 4 horas',
              trailing: _busy
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5))
                  : null,
              onTap: _busy ? null : _share,
            ),
          GSListRow(
            icon: Icons.health_and_safety_outlined,
            title: 'Ayuda',
            subtitle: 'Llamar al 123 o avisar a tus contactos',
            onTap: () => showSosSheet(context),
          ),
        ]),
      ],
    );
  }
}
