import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_button.dart';
import '../../widgets/gs_card.dart';
import '../../widgets/gs_text_field.dart';
import '../../widgets/gs_toast.dart';
import '../../providers/profile_provider.dart';
import '../../services/auth_service.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: GSColors.bg,
      appBar: AppBar(
        title: const Text('Profile'),
        leading: const BackButton(),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            tooltip: 'Edit profile',
            onPressed: () => _showEditPersonalInfo(context, ref),
          ),
        ],
      ),
      body: profileState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: GSColors.error),
              const SizedBox(height: 12),
              Text('Error loading profile',
                  style: TextStyle(color: GSColors.textSecondary)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.read(profileProvider.notifier).load(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (profile) => ListView(
          padding: const EdgeInsets.all(GSSpacing.s5),
          children: [
            // ── Avatar & name ──────────────────────────────────────────────
            Center(
              child: Column(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: GSColors.primaryLight,
                        backgroundImage: profile.avatarUrl != null
                            ? NetworkImage(profile.avatarUrl!)
                            : null,
                        child: profile.avatarUrl == null
                            ? const Icon(Icons.person_rounded,
                                size: 48, color: GSColors.primary)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: GSColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt_rounded,
                              size: 14, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: GSSpacing.s3),
                  Text(
                    profile.name.isEmpty ? 'No name set' : profile.name,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: GSColors.textPrimary),
                  ),
                  Text(
                    profile.phone ?? profile.email,
                    style: const TextStyle(
                        fontSize: 14, color: GSColors.textSecondary),
                  ),
                  const SizedBox(height: GSSpacing.s3),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: GSSpacing.s4, vertical: GSSpacing.s2),
                    decoration: BoxDecoration(
                      color: GSColors.ecoLight,
                      borderRadius: BorderRadius.circular(GSRadius.full),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.eco_rounded,
                            size: 14, color: GSColors.eco),
                        const SizedBox(width: 4),
                        Text(
                          '${profile.formattedEcoPoints} Eco Points',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: GSColors.eco),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: GSSpacing.s6),

            // ── Account ────────────────────────────────────────────────────
            _Section(
              title: 'Account',
              items: [
                _SettingItem(
                  icon: Icons.person_outline_rounded,
                  label: 'Personal information',
                  onTap: () => _showEditPersonalInfo(context, ref),
                ),
                _SettingItem(
                  icon: Icons.notifications_outlined,
                  label: 'Notifications',
                  trailing: Switch(
                    value: true,
                    activeThumbColor: GSColors.primary,
                    onChanged: (_) {},
                  ),
                ),
                _SettingItem(
                  icon: Icons.language_rounded,
                  label: 'Language',
                  value: 'Spanish',
                ),
              ],
            ),
            const SizedBox(height: GSSpacing.s4),

            // ── Privacy & Security ─────────────────────────────────────────
            _Section(
              title: 'Privacy & Security',
              items: [
                _SettingItem(
                  icon: Icons.lock_outline_rounded,
                  label: 'Change password',
                  onTap: () => _showChangePassword(context, ref),
                ),
                _SettingItem(
                  icon: Icons.fingerprint_rounded,
                  label: 'Biometric login',
                  trailing: Switch(
                    value: false,
                    activeThumbColor: GSColors.primary,
                    onChanged: (_) {},
                  ),
                ),
                _SettingItem(
                  icon: Icons.privacy_tip_outlined,
                  label: 'Privacy policy',
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: GSSpacing.s4),

            // ── Card ───────────────────────────────────────────────────────
            _Section(
              title: 'Card',
              items: [
                _SettingItem(
                  icon: Icons.lock_rounded,
                  label: 'Block card',
                  iconColor: GSColors.error,
                  onTap: () => GSToast.show(
                    context,
                    message: 'Use the Wallet screen to lock your card',
                    type: GSToastType.info,
                  ),
                ),
                _SettingItem(
                  icon: Icons.report_problem_rounded,
                  label: 'Report lost/stolen',
                  iconColor: GSColors.warning,
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: GSSpacing.s4),

            // ── Support ────────────────────────────────────────────────────
            _Section(
              title: 'Support',
              items: [
                _SettingItem(
                  icon: Icons.help_outline_rounded,
                  label: 'Help center',
                  onTap: () {},
                ),
                _SettingItem(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Live chat',
                  onTap: () {},
                ),
                _SettingItem(
                  icon: Icons.star_outline_rounded,
                  label: 'Rate the app',
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: GSSpacing.s5),

            GSButton(
              label: 'Sign out',
              onPressed: () async {
                try {
                  await authService.signOut();
                } catch (e) {
                  if (context.mounted) {
                    GSToast.show(context,
                        message: 'Error signing out',
                        type: GSToastType.error);
                  }
                }
              },
              variant: GSButtonVariant.danger,
              leadingIcon: Icons.logout_rounded,
            ),
            const SizedBox(height: GSSpacing.s6),

            const Center(
              child: Text('GoSmart v1.0.0',
                  style:
                      TextStyle(fontSize: 12, color: GSColors.textDisabled)),
            ),
            const SizedBox(height: GSSpacing.s4),
          ],
        ),
      ),
    );
  }

  // ── Edit personal info sheet ─────────────────────────────────────────────
  void _showEditPersonalInfo(BuildContext context, WidgetRef ref) {
    final profile = ref.read(profileProvider).valueOrNull;
    if (profile == null) return;

    final nameCtrl = TextEditingController(text: profile.name);
    final phoneCtrl = TextEditingController(text: profile.phone ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditPersonalInfoSheet(
        nameCtrl: nameCtrl,
        phoneCtrl: phoneCtrl,
        onSave: (name, phone) async {
          await ref
              .read(profileProvider.notifier)
              .updateProfile(name: name, phone: phone);
        },
      ),
    );
  }

  // ── Change password sheet ────────────────────────────────────────────────
  void _showChangePassword(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChangePasswordSheet(
        onSave: (newPassword) async {
          await ref
              .read(profileProvider.notifier)
              .updatePassword(newPassword);
        },
      ),
    );
  }
}

// ── Edit personal info bottom sheet ─────────────────────────────────────────

class _EditPersonalInfoSheet extends StatefulWidget {
  const _EditPersonalInfoSheet({
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.onSave,
  });
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final Future<void> Function(String name, String phone) onSave;

  @override
  State<_EditPersonalInfoSheet> createState() => _EditPersonalInfoSheetState();
}

class _EditPersonalInfoSheetState extends State<_EditPersonalInfoSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(
            GSSpacing.s5, GSSpacing.s4, GSSpacing.s5, GSSpacing.s6),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: GSColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: GSSpacing.s4),
              const Text('Personal Information',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: GSColors.textPrimary)),
              const SizedBox(height: GSSpacing.s4),
              GSTextField(
                label: 'Full name',
                hint: 'Your full name',
                controller: widget.nameCtrl,
                prefixIcon: Icons.person_rounded,
                keyboardType: TextInputType.name,
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: GSSpacing.s3),
              GSTextField(
                label: 'Phone number',
                hint: '+57 300 000 0000',
                controller: widget.phoneCtrl,
                prefixIcon: Icons.phone_rounded,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: GSSpacing.s5),
              GSButton(
                label: 'Save changes',
                isLoading: _isLoading,
                leadingIcon: Icons.check_rounded,
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;
                  final nav = Navigator.of(context);
                  final scaffoldMsg = ScaffoldMessenger.of(context);
                  setState(() => _isLoading = true);
                  try {
                    await widget.onSave(
                        widget.nameCtrl.text, widget.phoneCtrl.text);
                    if (!mounted) return;
                    nav.pop();
                    GSToast.showWithMessenger(scaffoldMsg,
                        message: 'Profile updated',
                        type: GSToastType.success);
                  } catch (e) {
                    if (!mounted) return;
                    GSToast.showWithMessenger(scaffoldMsg,
                        message: 'Failed to save: ${e.toString()}',
                        type: GSToastType.error);
                  } finally {
                    if (mounted) setState(() => _isLoading = false);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Change password bottom sheet ─────────────────────────────────────────────

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet({required this.onSave});
  final Future<void> Function(String newPassword) onSave;

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(
            GSSpacing.s5, GSSpacing.s4, GSSpacing.s5, GSSpacing.s6),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: GSColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: GSSpacing.s4),
              const Text('Change Password',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: GSColors.textPrimary)),
              const SizedBox(height: GSSpacing.s4),
              GSTextField(
                label: 'New password',
                hint: '••••••••',
                controller: _newPassCtrl,
                obscureText: true,
                prefixIcon: Icons.lock_rounded,
                validator: (v) {
                  if (v == null || v.length < 8) {
                    return 'Minimum 8 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: GSSpacing.s3),
              GSTextField(
                label: 'Confirm new password',
                hint: '••••••••',
                controller: _confirmPassCtrl,
                obscureText: true,
                prefixIcon: Icons.lock_outline_rounded,
                validator: (v) {
                  if (v != _newPassCtrl.text) return 'Passwords do not match';
                  return null;
                },
              ),
              const SizedBox(height: GSSpacing.s5),
              GSButton(
                label: 'Update password',
                isLoading: _isLoading,
                leadingIcon: Icons.check_rounded,
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;
                  final nav = Navigator.of(context);
                  final scaffoldMsg = ScaffoldMessenger.of(context);
                  setState(() => _isLoading = true);
                  try {
                    await widget.onSave(_newPassCtrl.text);
                    if (!mounted) return;
                    nav.pop();
                    GSToast.showWithMessenger(scaffoldMsg,
                        message: 'Password updated successfully',
                        type: GSToastType.success);
                  } catch (e) {
                    if (!mounted) return;
                    GSToast.showWithMessenger(scaffoldMsg,
                        message: 'Failed to update password: ${e.toString()}',
                        type: GSToastType.error);
                  } finally {
                    if (mounted) setState(() => _isLoading = false);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Reusable widgets ──────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.items});
  final String title;
  final List<_SettingItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
              const EdgeInsets.only(left: GSSpacing.s1, bottom: GSSpacing.s2),
          child: Text(title,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: GSColors.textSecondary,
                  letterSpacing: 0.5)),
        ),
        GSCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: items.map((item) {
              final isLast = item == items.last;
              return Column(
                children: [
                  _SettingTile(item: item),
                  if (!isLast)
                    const Padding(
                      padding: EdgeInsets.only(left: 56),
                      child: Divider(height: 1),
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({required this.item});
  final _SettingItem item;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: item.onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: GSSpacing.s4, vertical: GSSpacing.s3),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: item.iconColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(GSRadius.sm),
              ),
              child: Icon(item.icon, size: 18, color: item.iconColor),
            ),
            const SizedBox(width: GSSpacing.s3),
            Expanded(
              child: Text(item.label,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: GSColors.textPrimary)),
            ),
            if (item.trailing != null)
              item.trailing!
            else if (item.value != null)
              Row(
                children: [
                  Text(item.value!,
                      style: const TextStyle(
                          fontSize: 13, color: GSColors.textSecondary)),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      size: 12, color: GSColors.textDisabled),
                ],
              )
            else
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: GSColors.textDisabled),
          ],
        ),
      ),
    );
  }
}

class _SettingItem {
  final IconData icon;
  final String label;
  final Color iconColor;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingItem({
    required this.icon,
    required this.label,
    this.iconColor = GSColors.primary,
    this.value,
    this.trailing,
    this.onTap,
  });
}
