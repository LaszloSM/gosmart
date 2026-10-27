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
import '../../widgets/gs_brand_hero.dart';
import '../../widgets/gs_button.dart';
import '../../widgets/gs_list_row.dart';
import '../../widgets/gs_pressable.dart';
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

  Future<void> _confirmDeleteAccount() async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar tu cuenta?'),
        content: const Text(
            'Se borran tu perfil, tu billetera de prueba, tus contactos de '
            'emergencia y tus viajes. No se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await authService.deleteAccount();
      await authService.signOut();
    } catch (_) {
      GSToast.showWithMessenger(messenger,
          message: 'No pudimos eliminar tu cuenta. Revisa tu conexión '
              'e intenta de nuevo.',
          type: GSToastType.error);
    }
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      GSSpacing.s4, GSSpacing.s3, GSSpacing.s4, 0),
                  child: _Shortcuts(
                    isDriver: profile?.isDriver ?? false,
                  ),
                ),
                const GSSectionTitle('Tu cuenta'),
                GSGroup(children: [
                  GSListRow(
                    icon: Icons.badge_outlined,
                    title: 'Tus datos',
                    subtitle: _personalSummary(profile),
                    onTap: _showEditPersonalInfo,
                  ),
                  GSListRow(
                    icon: Icons.photo_camera_outlined,
                    title: 'Foto de perfil',
                    subtitle: 'La ve el conductor cuando pidas un viaje',
                    onTap: _uploadingPhoto ? null : _pickAndUploadPhoto,
                  ),
                  GSListRow(
                    icon: Icons.directions_walk_rounded,
                    title: 'Eco-puntos',
                    subtitle: 'Los sumas cuando eliges ir a pie',
                    value: profile?.formattedEcoPoints ?? '0',
                  ),
                ]),
                const GSSectionTitle('Conducir'),
                GSGroup(children: [
                  GSListRow(
                    icon: Icons.two_wheeler_rounded,
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
                    icon: Icons.group_outlined,
                    title: 'Contactos de emergencia',
                    subtitle: 'Reciben tu ubicación cuando pides ayuda',
                    onTap: () => context.push(AppRoutes.emergencyContacts),
                  ),
                  GSListRow(
                    icon: Icons.lock_outline_rounded,
                    title: 'Cambiar contraseña',
                    onTap: _showChangePassword,
                  ),
                ]),
                if (profile?.isAdmin ?? false) ...[
                  const GSSectionTitle('Administración'),
                  GSGroup(children: [
                    GSListRow(
                      icon: Icons.admin_panel_settings_outlined,
                      title: 'Panel admin',
                      subtitle: 'Conductores, reportes, métricas y ajustes',
                      onTap: () => context.push(AppRoutes.admin),
                    ),
                  ]),
                ],
                const GSSectionTitle('Tus datos y la ley'),
                GSGroup(children: [
                  GSListRow(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Cómo usamos tus datos',
                    onTap: () => context.push(AppRoutes.privacy),
                  ),
                  GSListRow(
                    icon: Icons.description_outlined,
                    title: 'Términos de uso',
                    onTap: () => context.push(AppRoutes.terms),
                  ),
                  GSListRow(
                    icon: Icons.delete_forever_outlined,
                    iconColor: GSColors.roadClosed,
                    title: 'Eliminar mi cuenta',
                    subtitle: 'Borra tu perfil, billetera, contactos y viajes',
                    onTap: _confirmDeleteAccount,
                  ),
                ]),
                if (kDebugMode) ...[
                  const GSSectionTitle('Desarrollo'),
                  GSGroup(children: [
                    GSListRow(
                      icon: Icons.nfc_rounded,
                      title: 'Simulador NFC',
                      subtitle: 'Solo en builds de depuración',
                      onTap: () => context.push(AppRoutes.nfcSimulator),
                    ),
                  ]),
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
                  height: MediaQuery.of(context).padding.bottom +
                      GSSpacing.s4 +
                      GSRadius.xl,
                ),
              ],
            ),
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
    return parts.isEmpty ? 'Completa tu cédula y tu ciudad' : parts.join(' · ');
  }
}

/// Tres accesos en una tarjeta blanca (DiDi/Nequi): lo que más se usa del
/// perfil a un toque.
class _Shortcuts extends StatelessWidget {
  const _Shortcuts({required this.isDriver});
  final bool isDriver;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: GSSpacing.s3),
      decoration: BoxDecoration(
        color: GSColors.surface,
        borderRadius: BorderRadius.circular(GSRadius.lg),
        boxShadow: GSShadow.md,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _Shortcut(
                icon: Icons.sos_rounded,
                label: 'Contactos SOS',
                onTap: () => context.push(AppRoutes.emergencyContacts),
              ),
            ),
            VerticalDivider(width: 1, color: GSColors.line),
            Expanded(
              child: _Shortcut(
                icon: Icons.two_wheeler_rounded,
                label: isDriver ? 'Modo conductor' : 'Conducir',
                onTap: () => context.push(AppRoutes.driver),
              ),
            ),
            VerticalDivider(width: 1, color: GSColors.line),
            Expanded(
              child: _Shortcut(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Billetera',
                onTap: () => context.go(AppRoutes.wallet),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: GSSpacing.s2, vertical: GSSpacing.s1),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: GSColors.brandTint,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: GSColors.brand, size: 22),
          ),
          const SizedBox(height: GSSpacing.s2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
              fontFamily: GSFonts.sans,
              fontFeatures: GSFonts.tabular,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              height: 1.2,
              color: GSColors.text,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) {
      return Semantics(label: label, excludeSemantics: true, child: body);
    }
    return GSPressable(onTap: onTap, semanticLabel: label, child: body);
  }
}
