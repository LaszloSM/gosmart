// lib/features/profile/profile_screen.dart
// Perfil: la placa con tu nombre, tus datos y la seguridad de la cuenta.
// Solo muestra lo que funciona: nada de interruptores o enlaces de adorno.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../models/profile_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../router/app_router.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_bottom_nav.dart';
import '../../widgets/gs_bottom_sheet.dart';
import '../../widgets/gs_button.dart';
import '../../widgets/gs_list_row.dart';
import '../../widgets/gs_toast.dart';
import 'widgets/change_password_form.dart';
import 'widgets/edit_personal_info_form.dart';
import 'widgets/profile_header.dart';

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
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  DateTime? _birthDate;
  bool _uploadingPhoto = false;

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _phoneCtrl,
      _cedulaCtrl,
      _cityCtrl,
      _newPassCtrl,
      _confirmPassCtrl,
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

  void _showChangePassword() {
    _newPassCtrl.clear();
    _confirmPassCtrl.clear();
    GSBottomSheet.show(
      context: context,
      title: 'Cambiar contraseña',
      initialChildSize: 0.65,
      child: ChangePasswordForm(
        newPassCtrl: _newPassCtrl,
        confirmPassCtrl: _confirmPassCtrl,
        onSave: () async {
          final messenger = ScaffoldMessenger.of(context);
          final navigator = Navigator.of(context);
          try {
            await ref
                .read(profileProvider.notifier)
                .updatePassword(_newPassCtrl.text);
            navigator.pop();
            GSToast.showWithMessenger(messenger,
                message: 'Contraseña cambiada', type: GSToastType.success);
          } catch (_) {
            GSToast.showWithMessenger(messenger,
                message: 'No pudimos cambiar la contraseña. Intenta de nuevo.',
                type: GSToastType.error);
          }
        },
      ),
    );
  }

  Future<void> _signOut() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      // El router lleva al login solo, con el evento de auth.
      await authService.signOut();
    } catch (_) {
      GSToast.showWithMessenger(messenger,
          message: 'No pudimos cerrar sesión. Intenta de nuevo.',
          type: GSToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).valueOrNull;

    return Scaffold(
      extendBody: true,
      backgroundColor: GSColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Perfil'),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          ProfileHeader(
            onEdit: _showEditPersonalInfo,
            onPhoto: _pickAndUploadPhoto,
            uploadingPhoto: _uploadingPhoto,
          ),
          const GSSectionTitle('Tu cuenta'),
          GSListRow(
            icon: Icons.badge_outlined,
            title: 'Tus datos',
            subtitle: _personalSummary(profile),
            onTap: _showEditPersonalInfo,
          ),
          const Divider(indent: GSSpacing.s4),
          GSListRow(
            icon: Icons.photo_camera_outlined,
            title: 'Foto de perfil',
            subtitle: 'La ve el conductor cuando pidas un viaje',
            onTap: _uploadingPhoto ? null : _pickAndUploadPhoto,
          ),
          const Divider(indent: GSSpacing.s4),
          GSListRow(
            icon: Icons.directions_walk_rounded,
            title: 'Eco-puntos',
            subtitle: 'Los sumas cuando eliges ir a pie',
            value: profile?.formattedEcoPoints ?? '0',
          ),
          const GSSectionTitle('Seguridad'),
          GSListRow(
            icon: Icons.lock_outline_rounded,
            title: 'Cambiar contraseña',
            onTap: _showChangePassword,
          ),
          if (kDebugMode) ...[
            const GSSectionTitle('Desarrollo'),
            GSListRow(
              icon: Icons.nfc_rounded,
              title: 'Simulador NFC',
              subtitle: 'Solo en builds de depuración',
              onTap: () => context.push(AppRoutes.nfcSimulator),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(
                GSSpacing.s4, GSSpacing.s8, GSSpacing.s4, GSSpacing.s3),
            child: GSButton(
              label: 'Cerrar sesión',
              variant: GSButtonVariant.outline,
              leadingIcon: Icons.logout_rounded,
              onPressed: _signOut,
            ),
          ),
          Center(
            child: Text('GoSmart 1.0.0',
                style: Theme.of(context).textTheme.bodySmall),
          ),
          SizedBox(
            height: GSSize.bottomNav +
                MediaQuery.of(context).padding.bottom +
                GSSpacing.s4,
          ),
        ],
      ),
      bottomNavigationBar: const GSBottomNav(current: GSNavTab.profile),
    );
  }

  String _personalSummary(ProfileModel? p) {
    if (p == null) return 'Nombre, cédula, ciudad y fecha de nacimiento';
    final parts = [
      if ((p.cedula ?? '').isNotEmpty) 'Cédula ${p.cedula}',
      if ((p.city ?? '').isNotEmpty) p.city!,
    ];
    return parts.isEmpty
        ? 'Completa tu cédula y tu ciudad'
        : parts.join(' · ');
  }
}
