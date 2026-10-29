// lib/features/profile/profile_screen.dart
// Perfil: la placa con tu nombre, tus datos y la seguridad de la cuenta.
// Solo muestra lo que funciona: nada de interruptores o enlaces de adorno.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../router/app_router.dart';
import '../../services/profile_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_bottom_nav.dart';
import '../../widgets/gs_bottom_sheet.dart';
import '../../widgets/gs_brand_hero.dart';
import '../../widgets/gs_list_row.dart';
import '../../widgets/gs_toast.dart';
import 'widgets/edit_personal_info_form.dart';
import 'widgets/profile_header.dart';
import '../../widgets/gs_nav_spacer.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _cedulaCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();

  DateTime? _birthDate;
  bool _uploadingPhoto = false;

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _phoneCtrl,
      _cedulaCtrl,
      _cityCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickAndUploadPhoto() async {
    final messenger = ScaffoldMessenger.of(context);
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (image == null) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _uploadingPhoto = true);
    try {
      final url = await ProfileService().uploadAvatar(user.id, image);
      if (url == null) throw StateError('upload');
      await ref.read(profileProvider.notifier).updateProfile(avatarUrl: url);
      GSToast.showWithMessenger(messenger,
          message: 'Foto actualizada', type: GSToastType.success);
    } catch (_) {
      GSToast.showWithMessenger(messenger,
          message: 'No pudimos subir la foto. Intenta de nuevo.',
          type: GSToastType.error);
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  void _showEditPersonalInfo() {
    final p = ref.read(profileProvider).valueOrNull;
    _nameCtrl.text = p?.name ?? '';
    _phoneCtrl.text = p?.phone ?? '';
    _cedulaCtrl.text = p?.cedula ?? '';
    _cityCtrl.text = p?.city ?? '';
    _birthDate = p?.birthDate;
    // La cédula no se cambia una vez guardada.
    final isCedulaLocked = (p?.cedula ?? '').isNotEmpty;

    GSBottomSheet.show(
      context: context,
      title: 'Tus datos',
      initialChildSize: 0.9,
      child: EditPersonalInfoForm(
        nameCtrl: _nameCtrl,
        phoneCtrl: _phoneCtrl,
        cedulaCtrl: _cedulaCtrl,
        cityCtrl: _cityCtrl,
        isCedulaLocked: isCedulaLocked,
        initialBirthDate: _birthDate,
        onBirthDateChanged: (d) => _birthDate = d,
        onSave: () async {
          final messenger = ScaffoldMessenger.of(context);
          final navigator = Navigator.of(context);
          try {
            await ref.read(profileProvider.notifier).updateProfile(
                  name: _nameCtrl.text.trim(),
                  phone: _phoneCtrl.text.trim(),
                  cedula: isCedulaLocked ? null : _cedulaCtrl.text.trim(),
                  city: _cityCtrl.text.trim(),
                  birthDate: _birthDate != null
                      ? DateFormat('yyyy-MM-dd').format(_birthDate!)
                      : null,
                );
            navigator.pop();
            GSToast.showWithMessenger(messenger,
                message: 'Datos guardados', type: GSToastType.success);
          } catch (_) {
            GSToast.showWithMessenger(messenger,
                message: 'No pudimos guardar tus datos. Revisa tu conexión '
                    'e intenta de nuevo.',
                type: GSToastType.error);
          }
        },
      ),
    );
  }







  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).valueOrNull;

    return Scaffold(
      extendBody: true,
      backgroundColor: GSColors.background,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          ProfileHeader(
            onEdit: _showEditPersonalInfo,
            onPhoto: _pickAndUploadPhoto,
            uploadingPhoto: _uploadingPhoto,
          ),
          GSHeroBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const GSSectionTitle('Conducir'),
                GSGroup(children: [
                  GSListRow(
                    icon: Icons.badge_rounded,
                    title: (profile?.isDriver ?? false)
                        ? 'Modo conductor'
                        : 'Quiero ser conductor',
                    subtitle: (profile?.isDriver ?? false)
                        ? 'Tu disponibilidad y tus datos'
                        : 'Mototaxi, taxi, colectivo o intermunicipal',
                    onTap: () => context.push(AppRoutes.driver),
                  ),
                ]),
                const GSSectionTitle('Seguridad'),
                GSGroup(children: [
                  GSListRow(
                    icon: Icons.group_rounded,
                    title: 'Contactos de emergencia',
                    subtitle: 'Reciben tu ubicación cuando pides ayuda',
                    onTap: () => context.push(AppRoutes.emergencyContacts),
                  ),
                ]),
                if (profile?.isAdmin ?? false) ...[
                  const GSSectionTitle('Administración'),
                  GSGroup(children: [
                    GSListRow(
                      icon: Icons.admin_panel_settings_rounded,
                      title: 'Panel admin',
                      subtitle: 'Conductores, reportes, métricas y ajustes',
                      onTap: () => context.push(AppRoutes.admin),
                    ),
                  ]),
                ],
                const GSSectionTitle('La app'),
                GSGroup(children: [
                  GSListRow(
                    icon: Icons.settings_rounded,
                    title: 'Configuración',
                    subtitle: 'Tema, alertas del mapa, contraseña, privacidad y salir',
                    onTap: () => context.push(AppRoutes.settings),
                  ),
                ]),
                const GSNavSpacer(extra: GSSpacing.s4 + GSRadius.xl),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const GSBottomNav(current: GSNavTab.profile),
    );
  }

}
