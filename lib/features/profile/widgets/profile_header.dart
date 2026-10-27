// lib/features/profile/widgets/profile_header.dart
// Cabecera del perfil como en Nequi/DiDi: banda azul honda con la foto en
// anillo blanco, el nombre, el correo, "Editar perfil" y el rol.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/profile_provider.dart';
import '../../../theme/design_tokens.dart';
import '../../../widgets/gs_brand_hero.dart';
import '../../../widgets/gs_inline_error.dart';
import '../../../widgets/gs_pressable.dart';
import '../../../widgets/gs_skeleton_loader.dart';

class ProfileHeader extends ConsumerWidget {
  const ProfileHeader({
    super.key,
    required this.onEdit,
    required this.onPhoto,
    this.uploadingPhoto = false,
  });

  final VoidCallback onEdit;
  final VoidCallback onPhoto;
  final bool uploadingPhoto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final on = GSColors.onBrandDeep;
    final onMuted = GSColors.onBrandDeepMuted;

    return GSBrandHero(
      title: 'Perfil',
      child: profileAsync.when(
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        loading: () => const GSSkeletonLoader(
            width: double.infinity, height: 96, radius: GSRadius.lg),
        error: (_, __) => Container(
          padding: const EdgeInsets.all(GSSpacing.s3),
          decoration: BoxDecoration(
            color: GSColors.surface,
            borderRadius: BorderRadius.circular(GSRadius.md),
          ),
          child: GSInlineError(
            message: 'No pudimos cargar tu perfil',
            onRetry: () => ref.read(profileProvider.notifier).load(),
          ),
        ),
        data: (p) {
          final name = p.name.trim().isEmpty ? 'Tu nombre' : p.name.trim();
          final role = p.isAdmin
              ? 'Admin'
              : p.isDriver
                  ? 'Conductor'
                  : 'Pasajero';
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Avatar(
                url: p.avatarUrl,
                uploading: uploadingPhoto,
                onTap: onPhoto,
              ),
              const SizedBox(width: GSSpacing.s4),
              Expanded(
                child: GSPressable(
                  onTap: onEdit,
                  semanticLabel: 'Tu perfil: $name. Toca para editar tus datos',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: GSFonts.sans,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          height: 1.15,
                          color: on,
                        ),
                      ),
                      if (p.email.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(p.email,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: GSFonts.sans,
                              fontSize: 14,
                              color: onMuted,
                            )),
                      ],
                      const SizedBox(height: GSSpacing.s3),
                      Wrap(
                        spacing: GSSpacing.s2,
                        runSpacing: GSSpacing.s2,
                        children: [
                          const _HeroPill(
                              icon: Icons.edit_rounded,
                              label: 'Editar perfil',
                              filled: true),
                          _HeroPill(
                              icon: Icons.verified_user_outlined, label: role),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill(
      {required this.icon, required this.label, this.filled = false});
  final IconData icon;
  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final on = GSColors.onBrandDeep;
    final fg = filled ? GSColors.brandDeep : on;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: filled ? on : on.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(GSRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: GSFonts.sans,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar(
      {required this.url, required this.uploading, required this.onTap});

  final String? url;
  final bool uploading;
  final VoidCallback onTap;

  static const _size = 76.0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Cambiar foto de perfil',
      child: InkResponse(
        onTap: uploading ? null : onTap,
        radius: _size / 2 + 4,
        child: SizedBox(
          width: _size,
          height: _size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: GSColors.onBrandDeep, width: 3),
                ),
                child: CircleAvatar(
                  radius: _size / 2 - 3,
                  backgroundColor: GSColors.brandTint,
                  backgroundImage: url != null ? NetworkImage(url!) : null,
                  child: url == null
                      ? Icon(Icons.person_rounded,
                          size: 40, color: GSColors.brand)
                      : null,
                ),
              ),
              if (uploading)
                Positioned.fill(
                  child: CircleAvatar(
                    backgroundColor: const Color(0x99111827),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: GSColors.onBrand),
                    ),
                  ),
                ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: GSColors.brand,
                    shape: BoxShape.circle,
                    border: Border.all(color: GSColors.onBrandDeep, width: 2),
                  ),
                  child: Icon(Icons.photo_camera_rounded,
                      size: 16, color: GSColors.onBrand),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
