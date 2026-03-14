import 'package:flutter/material.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_card.dart';
import '../../widgets/gs_button.dart';
import '../../widgets/gs_toast.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GSColors.bg,
      appBar: AppBar(
        title: const Text('Profile'),
        leading: const BackButton(),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () {},
            tooltip: 'Edit profile',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(GSSpacing.s5),
        children: [
          // ── Avatar & name ─────────────────────────────────────────────────
          Center(
            child: Column(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: GSColors.primaryLight,
                      child: const Icon(Icons.person_rounded,
                          size: 48, color: GSColors.primary),
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
                const Text('Muhammad Ali',
                    style: TextStyle(
                        
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: GSColors.textPrimary)),
                const Text('+1 555 000 0000',
                    style: TextStyle(
                        fontSize: 14, color: GSColors.textSecondary)),
                const SizedBox(height: GSSpacing.s3),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: GSSpacing.s4, vertical: GSSpacing.s2),
                  decoration: BoxDecoration(
                    color: GSColors.ecoLight,
                    borderRadius: BorderRadius.circular(GSRadius.full),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.eco_rounded,
                          size: 14, color: GSColors.eco),
                      SizedBox(width: 4),
                      Text('1,240 Eco Points',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: GSColors.eco)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: GSSpacing.s6),

          // ── Settings sections ─────────────────────────────────────────────
          _Section(
            title: 'Account',
            items: [
              _SettingItem(
                icon: Icons.person_outline_rounded,
                label: 'Personal information',
                onTap: () {},
              ),
              _SettingItem(
                icon: Icons.notifications_outlined,
                label: 'Notifications',
                onTap: () {},
                trailing: Switch(
                  value: true,
                  activeColor: GSColors.primary,
                  onChanged: (_) {},
                ),
              ),
              _SettingItem(
                icon: Icons.language_rounded,
                label: 'Language',
                value: 'English',
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: GSSpacing.s4),

          _Section(
            title: 'Privacy & Security',
            items: [
              _SettingItem(
                icon: Icons.lock_outline_rounded,
                label: 'Change password',
                onTap: () {},
              ),
              _SettingItem(
                icon: Icons.fingerprint_rounded,
                label: 'Biometric login',
                onTap: () {},
                trailing: Switch(
                  value: true,
                  activeColor: GSColors.primary,
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

          _Section(
            title: 'Card',
            items: [
              _SettingItem(
                icon: Icons.lock_rounded,
                label: 'Block card',
                iconColor: GSColors.error,
                onTap: () => GSToast.show(
                  context,
                  message: 'Card has been blocked',
                  type: GSToastType.warning,
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
            onPressed: () {},
            variant: GSButtonVariant.danger,
            leadingIcon: Icons.logout_rounded,
          ),
          const SizedBox(height: GSSpacing.s6),

          const Center(
            child: Text('GoSmart v1.0.0',
                style: TextStyle(fontSize: 12, color: GSColors.textDisabled)),
          ),
          const SizedBox(height: GSSpacing.s4),
        ],
      ),
    );
  }
}

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
          padding: const EdgeInsets.only(
              left: GSSpacing.s1, bottom: GSSpacing.s2),
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
