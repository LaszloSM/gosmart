// lib/features/safety/sos_sheet.dart
// Ayuda inmediata. Lo primero y más grande: llamar al 123. Después, avisar a
// tus contactos por WhatsApp o SMS con tu ubicación. El aviso sale de tu
// teléfono (no depende de nuestro servidor); el registro en `sos_events` es
// solo constancia y se intenta una vez por hoja abierta.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../core/safety_links.dart';
import '../../models/emergency_contact.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/safety_provider.dart';
import '../../router/app_router.dart';
import '../../services/location_service.dart';
import '../../services/safety_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_bottom_sheet.dart';
import '../../widgets/gs_button.dart';
import '../../widgets/gs_list_row.dart';
import '../../widgets/gs_toast.dart';

Future<void> showSosSheet(BuildContext context) {
  return GSBottomSheet.show(
    context: context,
    title: 'Ayuda',
    initialChildSize: 0.75,
    child: const SosSheetContent(),
  );
}

class SosSheetContent extends ConsumerStatefulWidget {
  const SosSheetContent({super.key, this.locate});

  /// Inyectable en pruebas; por defecto, el GPS del teléfono.
  final Future<LatLng?> Function()? locate;

  @override
  ConsumerState<SosSheetContent> createState() => _SosSheetContentState();
}

class _SosSheetContentState extends ConsumerState<SosSheetContent> {
  // Una llave por hoja: si el usuario toca varios canales, queda un solo SOS.
  final _key = const Uuid().v4();
  LatLng? _at;
  bool _locating = true;
  bool _recorded = false;

  @override
  void initState() {
    super.initState();
    _locate();
  }

  Future<void> _locate() async {
    final at = await (widget.locate ?? locationService.getCurrentPosition)();
    if (!mounted) return;
    setState(() {
      _at = at;
      _locating = false;
    });
  }

  String get _message {
    final name = ref.read(profileProvider).valueOrNull?.name;
    return sosMessage(at: _at, name: name);
  }

  Future<void> _open(Uri uri, String channel) async {
    final messenger = ScaffoldMessenger.of(context);
    _record(channel);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication)
        .catchError((_) => false);
    if (!ok) {
      GSToast.showWithMessenger(messenger,
          message: channel == 'call'
              ? 'No pudimos abrir el teléfono. Marca 123.'
              : 'No pudimos abrir la app. Llama al 123.',
          type: GSToastType.error);
    }
  }

  void _record(String channel) {
    final user = ref.read(currentUserProvider);
    if (user == null || _recorded) return;
    _recorded = true;
    safetyService.recordSos(
      userId: user.id,
      idempotencyKey: _key,
      at: _at,
      channels: [channel],
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final isGuest = ref.watch(isGuestProvider);
    final contacts = ref.watch(emergencyContactsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GSButton(
          label: 'Llamar al 123',
          size: GSButtonSize.lg,
          leadingIcon: Icons.call_rounded,
          semanticLabel: 'Llamar a la línea de emergencias 123',
          onPressed: () => _open(emergencyCallUri, 'call'),
        ),
        const SizedBox(height: GSSpacing.s2),
        Text('Policía, ambulancia y bomberos. La llamada es gratis.',
            style: text.bodySmall),
        const SizedBox(height: GSSpacing.s5),
        _LocationLine(locating: _locating, at: _at),
        const SizedBox(height: GSSpacing.s2),
        if (isGuest) ...[
          GSListRow(
            icon: Icons.chat_rounded,
            title: 'Avisar por WhatsApp',
            subtitle: 'Eliges a quién se lo mandas',
            onTap: () => _open(whatsappUri(_message), 'whatsapp'),
          ),
          const Divider(indent: GSSpacing.s4),
          GSListRow(
            icon: Icons.person_add_alt_rounded,
            title: 'Guarda tus contactos de emergencia',
            subtitle: 'Con una cuenta, el aviso les llega con un toque',
            onTap: () {
              Navigator.of(context).pop();
              context.push(AppRoutes.login);
            },
          ),
        ] else
          contacts.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(GSSpacing.s4),
              child: Center(child: CircularProgressIndicator()),
            ),
            // Sin señal no hay lista, pero WhatsApp sigue sirviendo.
            error: (_, __) => GSListRow(
              icon: Icons.chat_rounded,
              title: 'Avisar por WhatsApp',
              subtitle: 'No cargamos tus contactos; eliges a quién',
              onTap: () => _open(whatsappUri(_message), 'whatsapp'),
            ),
            data: (list) => _ContactActions(
              contacts: list,
              onWhatsApp: (c) =>
                  _open(whatsappUri(_message, phone: c?.phone), 'whatsapp'),
              onSmsAll: () => _open(
                  smsUri(_message, [for (final c in list) c.phone]), 'sms'),
              onManage: () {
                Navigator.of(context).pop();
                context.push(AppRoutes.emergencyContacts);
              },
            ),
          ),
      ],
    );
  }
}

class _LocationLine extends StatelessWidget {
  const _LocationLine({required this.locating, required this.at});
  final bool locating;
  final LatLng? at;

  @override
  Widget build(BuildContext context) {
    final (icon, label) = locating
        ? (Icons.my_location_rounded, 'Buscando tu ubicación…')
        : at == null
            ? (Icons.location_disabled_rounded,
                'Sin ubicación: el mensaje lo dirá. Activa el GPS si puedes.')
            : (Icons.location_on_rounded,
                'Tu ubicación va en el mensaje');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: GSSize.iconMd, color: GSColors.brand),
        const SizedBox(width: GSSpacing.s2),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}

class _ContactActions extends StatelessWidget {
  const _ContactActions({
    required this.contacts,
    required this.onWhatsApp,
    required this.onSmsAll,
    required this.onManage,
  });

  final List<EmergencyContact> contacts;
  final void Function(EmergencyContact?) onWhatsApp;
  final VoidCallback onSmsAll;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    if (contacts.isEmpty) {
      return Column(children: [
        GSListRow(
          icon: Icons.chat_rounded,
          title: 'Avisar por WhatsApp',
          subtitle: 'Eliges a quién se lo mandas',
          onTap: () => onWhatsApp(null),
        ),
        const Divider(indent: GSSpacing.s4),
        GSListRow(
          icon: Icons.person_add_alt_rounded,
          title: 'Agrega contactos de emergencia',
          subtitle: 'Así el aviso les llega con un toque',
          onTap: onManage,
        ),
      ]);
    }
    return Column(children: [
      for (final c in contacts) ...[
        GSListRow(
          icon: Icons.chat_rounded,
          title: 'WhatsApp a ${c.name}',
          subtitle: c.displayPhone,
          onTap: () => onWhatsApp(c),
        ),
        const Divider(indent: GSSpacing.s4),
      ],
      GSListRow(
        icon: Icons.sms_rounded,
        title: contacts.length == 1
            ? 'SMS a ${contacts.first.name}'
            : 'SMS a tus ${contacts.length} contactos',
        subtitle: 'Sirve aunque no tengas datos',
        onTap: onSmsAll,
      ),
      const Divider(indent: GSSpacing.s4),
      GSListRow(
        icon: Icons.group_rounded,
        title: 'Editar contactos',
        onTap: onManage,
      ),
    ]);
  }
}
