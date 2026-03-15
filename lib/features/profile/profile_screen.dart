import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../router/app_router.dart';
import '../../services/auth_service.dart';
import '../../theme/design_tokens.dart';
import '../../providers/profile_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../widgets/gs_bottom_nav.dart';
import '../../widgets/gs_bottom_sheet.dart';
import '../../widgets/gs_button.dart';
import '../../widgets/gs_card.dart';
import '../../widgets/gs_skeleton_loader.dart';
import '../../widgets/gs_text_field.dart';
import '../../widgets/gs_toast.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ProfileScreen
// ─────────────────────────────────────────────────────────────────────────────

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _newPassCtrl;
  late TextEditingController _confirmPassCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _newPassCtrl = TextEditingController();
    _confirmPassCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  void _onNavTap(int i) {
    switch (i) {
      case 0:
        context.go(AppRoutes.home);
        break;
      case 1:
        context.go(AppRoutes.history);
        break;
      case 2:
        context.go(AppRoutes.wallet);
        break;
      case 3:
        context.go(AppRoutes.profile);
        break;
    }
  }

  // ── Edit personal info sheet ───────────────────────────────────────────────

  void _showEditPersonalInfoSheet() {
    final profile = ref.read(profileProvider).valueOrNull;
    _nameCtrl.text = profile?.name ?? '';
    _phoneCtrl.text = profile?.phone ?? '';

    GSBottomSheet.show(
      context: context,
      title: 'Información personal',
      initialChildSize: 0.6,
      child: _EditPersonalInfoContent(
        nameCtrl: _nameCtrl,
        phoneCtrl: _phoneCtrl,
        onSave: () async {
          final messenger = ScaffoldMessenger.of(context);
          try {
            await ref.read(profileProvider.notifier).updateProfile(
                  name: _nameCtrl.text.trim(),
                  phone: _phoneCtrl.text.trim(),
                );
            if (!mounted) return;
            Navigator.pop(context);
            GSToast.showWithMessenger(
              messenger,
              message: 'Perfil actualizado correctamente',
              type: GSToastType.success,
            );
          } catch (e) {
            if (!mounted) return;
            GSToast.showWithMessenger(
              messenger,
              message: 'Error al guardar: ${e.toString()}',
              type: GSToastType.error,
            );
          }
        },
      ),
    );
  }

  // ── Change password sheet ──────────────────────────────────────────────────

  void _showChangePasswordSheet() {
    _newPassCtrl.clear();
    _confirmPassCtrl.clear();

    GSBottomSheet.show(
      context: context,
      title: 'Cambiar contraseña',
      initialChildSize: 0.6,
      child: _ChangePasswordContent(
        newPassCtrl: _newPassCtrl,
        confirmPassCtrl: _confirmPassCtrl,
        onSave: () async {
          final messenger = ScaffoldMessenger.of(context);
          try {
            await ref
                .read(profileProvider.notifier)
                .updatePassword(_newPassCtrl.text);
            if (!mounted) return;
            Navigator.pop(context);
            GSToast.showWithMessenger(
              messenger,
              message: 'Contraseña actualizada correctamente',
              type: GSToastType.success,
            );
          } catch (e) {
            if (!mounted) return;
            GSToast.showWithMessenger(
              messenger,
              message: 'Error al cambiar contraseña: ${e.toString()}',
              type: GSToastType.error,
            );
          }
        },
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GSColors.bg,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stats row
                _buildStatsRow(),

                // Settings sections
                _SettingsSection(
                  'Mi cuenta',
                  [
                    _SettingsTile(
                      Icons.person_outline_rounded,
                      'Información personal',
                      onTap: _showEditPersonalInfoSheet,
                    ),
                    _SettingsTile(
                      Icons.notifications_outlined,
                      'Notificaciones',
                      trailing: Switch(
                        value: false,
                        onChanged: (_) {},
                        activeThumbColor: GSColors.accent,
                      ),
                    ),
                    const _SettingsTile(
                      Icons.language_rounded,
                      'Idioma',
                      trailing: Text(
                        'Español',
                        style: TextStyle(
                          color: GSColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),

                _SettingsSection(
                  'Seguridad',
                  [
                    _SettingsTile(
                      Icons.lock_outline_rounded,
                      'Cambiar contraseña',
                      onTap: _showChangePasswordSheet,
                    ),
                    _SettingsTile(
                      Icons.fingerprint_rounded,
                      'Login biométrico',
                      trailing: Switch(
                        value: false,
                        onChanged: (_) {},
                        activeThumbColor: GSColors.accent,
                      ),
                    ),
                    const _SettingsTile(
                      Icons.privacy_tip_outlined,
                      'Política de privacidad',
                    ),
                  ],
                ),

                _SettingsSection(
                  'Tarjeta',
                  [
                    _SettingsTile(
                      Icons.credit_card_rounded,
                      'Bloquear tarjeta',
                      onTap: () => context.go(AppRoutes.wallet),
                    ),
                    const _SettingsTile(
                      Icons.report_problem_outlined,
                      'Reportar pérdida',
                      iconColor: GSColors.error,
                      textColor: GSColors.error,
                    ),
                  ],
                ),

                _SettingsSection(
                  'Soporte',
                  [
                    const _SettingsTile(
                      Icons.help_outline_rounded,
                      'Centro de ayuda',
                    ),
                    const _SettingsTile(
                      Icons.chat_bubble_outline_rounded,
                      'Chat en vivo',
                    ),
                    const _SettingsTile(
                      Icons.star_outline_rounded,
                      'Calificar la app',
                    ),
                    if (kDebugMode)
                      _SettingsTile(
                        Icons.nfc_rounded,
                        'Simulador NFC (Debug)',
                        iconColor: Colors.orange,
                        onTap: () => context.push(AppRoutes.nfcSimulator),
                      ),
                  ],
                ),

                // Sign out
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: GSSpacing.s4,
                    vertical: GSSpacing.s2,
                  ),
                  child: GSButton(
                    label: 'Cerrar sesión',
                    variant: GSButtonVariant.danger,
                    leadingIcon: Icons.logout_rounded,
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await authService.signOut();
                        // GoRouter redirects to login via auth stream automatically
                      } catch (e) {
                        GSToast.showWithMessenger(
                          messenger,
                          message: 'Error al cerrar sesión',
                          type: GSToastType.error,
                        );
                      }
                    },
                  ),
                ),

                // Version label
                const Center(
                  child: Text(
                    'GoSmart v1.0.0',
                    style: TextStyle(
                      fontSize: 12,
                      color: GSColors.textDisabled,
                    ),
                  ),
                ),
                const SizedBox(height: GSSpacing.s6),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: GSBottomNav(
        currentIndex: 3,
        onTap: _onNavTap,
      ),
    );
  }

  // ── SliverAppBar ───────────────────────────────────────────────────────────

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: const Color(0xFF1A1A2E),
      elevation: 0,
      automaticallyImplyLeading: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_rounded, color: Colors.white),
          onPressed: _showEditPersonalInfoSheet,
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            // Gradient background
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1A1A2E), Color(0xFF6C63FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            // Avatar + name at bottom
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: ref.watch(profileProvider).when(
                loading: () => const Column(
                  children: [
                    GSSkeletonLoader(width: 88, height: 88, radius: 44),
                    SizedBox(height: 8),
                    GSSkeletonLoader(width: 120, height: 18, radius: 4),
                    SizedBox(height: 4),
                    GSSkeletonLoader(width: 160, height: 14, radius: 4),
                  ],
                ),
                error: (_, __) => const Column(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: GSColors.accentLight,
                      child: Icon(
                        Icons.person_rounded,
                        size: 44,
                        color: GSColors.accent,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Error',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                data: (p) => Column(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: GSColors.accentLight,
                      backgroundImage: p.avatarUrl != null
                          ? NetworkImage(p.avatarUrl!)
                          : null,
                      child: p.avatarUrl == null
                          ? const Icon(
                              Icons.person_rounded,
                              size: 44,
                              color: GSColors.accent,
                            )
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      p.name.isEmpty ? 'Usuario' : p.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      p.email,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Stats row ──────────────────────────────────────────────────────────────

  Widget _buildStatsRow() {
    final tripCount = ref.watch(tripCountProvider).when(
          data: (n) => n,
          loading: () => 0,
          error: (_, __) => 0,
        );
    final ecoPoints =
        ref.watch(profileProvider).valueOrNull?.ecoPoints ?? 0;

    return GSCard(
      margin: const EdgeInsets.fromLTRB(
        GSSpacing.s4,
        GSSpacing.s4,
        GSSpacing.s4,
        0,
      ),
      padding: const EdgeInsets.all(GSSpacing.s4),
      child: Row(
        children: [
          _StatChip(
            label: '$tripCount Viajes',
            icon: Icons.route_rounded,
          ),
          Container(
            width: 1,
            height: 40,
            color: GSColors.border,
            margin:
                const EdgeInsets.symmetric(horizontal: GSSpacing.s4),
          ),
          _StatChip(
            label: '$ecoPoints Pts Eco',
            icon: Icons.eco_rounded,
            color: GSColors.eco,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom sheet content widgets
// ─────────────────────────────────────────────────────────────────────────────

class _EditPersonalInfoContent extends StatefulWidget {
  const _EditPersonalInfoContent({
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.onSave,
  });

  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final Future<void> Function() onSave;

  @override
  State<_EditPersonalInfoContent> createState() =>
      _EditPersonalInfoContentState();
}

class _EditPersonalInfoContentState extends State<_EditPersonalInfoContent> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GSTextField(
            label: 'Nombre',
            hint: 'Tu nombre completo',
            controller: widget.nameCtrl,
            prefixIcon: Icons.person_outline_rounded,
            keyboardType: TextInputType.name,
            textCapitalization: TextCapitalization.words,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'El nombre es requerido' : null,
          ),
          const SizedBox(height: GSSpacing.s3),
          GSTextField(
            label: 'Teléfono',
            hint: '+57 300 000 0000',
            controller: widget.phoneCtrl,
            prefixIcon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: GSSpacing.s5),
          GSButton(
            label: 'Guardar',
            isLoading: _isLoading,
            leadingIcon: Icons.check_rounded,
            onPressed: () async {
              if (!_formKey.currentState!.validate()) return;
              setState(() => _isLoading = true);
              try {
                await widget.onSave();
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _ChangePasswordContent extends StatefulWidget {
  const _ChangePasswordContent({
    required this.newPassCtrl,
    required this.confirmPassCtrl,
    required this.onSave,
  });

  final TextEditingController newPassCtrl;
  final TextEditingController confirmPassCtrl;
  final Future<void> Function() onSave;

  @override
  State<_ChangePasswordContent> createState() => _ChangePasswordContentState();
}

class _ChangePasswordContentState extends State<_ChangePasswordContent> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GSTextField(
            label: 'Nueva contraseña',
            hint: '••••••••',
            controller: widget.newPassCtrl,
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: true,
            validator: (v) {
              if (v == null || v.length < 8) {
                return 'Mínimo 8 caracteres';
              }
              return null;
            },
          ),
          const SizedBox(height: GSSpacing.s3),
          GSTextField(
            label: 'Confirmar contraseña',
            hint: '••••••••',
            controller: widget.confirmPassCtrl,
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: true,
            validator: (v) {
              if (v != widget.newPassCtrl.text) {
                return 'Las contraseñas no coinciden';
              }
              return null;
            },
          ),
          const SizedBox(height: GSSpacing.s5),
          GSButton(
            label: 'Cambiar contraseña',
            isLoading: _isLoading,
            leadingIcon: Icons.check_rounded,
            onPressed: () async {
              if (!_formKey.currentState!.validate()) return;
              setState(() => _isLoading = true);
              try {
                await widget.onSave();
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private helper widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsSection extends StatelessWidget {
  const _SettingsSection(this.title, this.tiles);

  final String title;
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            GSSpacing.s4,
            GSSpacing.s4,
            GSSpacing.s4,
            GSSpacing.s2,
          ),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: GSColors.textSecondary,
              letterSpacing: 1.2,
            ),
          ),
        ),
        GSCard(
          margin: const EdgeInsets.symmetric(horizontal: GSSpacing.s4),
          padding: EdgeInsets.zero,
          child: Column(children: tiles),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile(
    this.icon,
    this.label, {
    this.trailing,
    this.onTap,
    this.iconColor,
    this.textColor,
  });

  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: iconColor ?? GSColors.textSecondary,
        size: 22,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          color: textColor ?? GSColors.textPrimary,
          fontWeight: FontWeight.w400,
        ),
      ),
      trailing: trailing ??
          const Icon(
            Icons.chevron_right_rounded,
            color: GSColors.textDisabled,
            size: 18,
          ),
      onTap: onTap,
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.icon,
    this.color = GSColors.accent,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: GSColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
