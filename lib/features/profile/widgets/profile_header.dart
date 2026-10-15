// lib/features/profile/widgets/profile_header.dart
// Cabecera del perfil como en Uber/Nequi: nombre grande, correo y "Editar
// perfil" a la izquierda; la foto grande a la derecha.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/profile_provider.dart';
import '../../../theme/design_tokens.dart';
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          GSSpacing.s4, GSSpacing.s4, GSSpacing.s4, 0),
      child: profileAsync.when(
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        loading: () => const GSSkeletonLoader(
            width: double.infinity, height: 96, radius: GSRadius.lg),
        error: (_, __) => GSInlineError(
          message: 'No pudimos cargar tu perfil',
          onRetry: () => ref.read(profileProvider.notifier).load(),
        ),
        data: (p) {
          final name = p.name.trim().isEmpty ? 'Tu nombre' : p.name.trim();
          final text = Theme.of(context).textTheme;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: GSPressable(
                  onTap: onEdit,
                  semanticLabel: 'Tu perfil: $name. Toca para editar tus datos',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: text.headlineMedium?.copyWith(
                          color: p.name.trim().isEmpty
                              ? GSColors.textMuted
                              : GSColors.text,
                        ),
                      ),
                      if (p.email.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(p.email,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodyMedium),
                      ],
                      const SizedBox(height: GSSpacing.s2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: GSColors.brandTint,
                          borderRadius: BorderRadius.circular(GSRadius.full),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_outlined,
                                size: 16, color: GSColors.brand),
                            const SizedBox(width: 6),
                            Text(
                              'Editar perfil',
                              style: TextStyle(
                                fontFamily: GSFonts.sans,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: GSColors.brand,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: GSSpacing.s3),
              _Avatar(
                url: p.avatarUrl,
                uploading: uploadingPhoto,
                onTap: onPhoto,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.uploading, required this.onTap});

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
              CircleAvatar(
                radius: _size / 2,
                backgroundColor: GSColors.brandTint,
                backgroundImage: url != null ? NetworkImage(url!) : null,
                child: url == null
                    ? Icon(Icons.person_rounded,
                        size: 40, color: GSColors.brand)
                    : null,
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
                    border: Border.all(color: GSColors.surface, width: 2),
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
