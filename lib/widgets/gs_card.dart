import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// Base card with soft floating shadow and configurable padding/radius.
class GSCard extends StatelessWidget {
  const GSCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.radius,
    this.color = GSColors.surface,
    this.shadow,
    this.border,
    this.onTap,
    this.clip = Clip.antiAlias,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? radius;
  final Color color;
  final List<BoxShadow>? shadow;
  final Border? border;
  final VoidCallback? onTap;
  final Clip clip;

  @override
  Widget build(BuildContext context) {
    final r = radius ?? GSRadius.xl; // default 20px
    final content = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(r),
        boxShadow: shadow ?? GSShadow.card,
        border: border,
      ),
      clipBehavior: clip,
      child: padding != null ? Padding(padding: padding!, child: child) : child,
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: content);
    }
    return content;
  }
}

// ─── Transport mode chip ──────────────────────────────────────────────────────

class GSModeChip extends StatelessWidget {
  const GSModeChip({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: GSDuration.normal,
        padding: const EdgeInsets.symmetric(
          horizontal: GSSpacing.s4,
          vertical: GSSpacing.s2,
        ),
        decoration: BoxDecoration(
          color: isSelected ? color : GSColors.surfaceDark,
          borderRadius: BorderRadius.circular(GSRadius.full),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.30),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: GSSize.iconLg,
              color: isSelected ? Colors.white : color,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : GSColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Balance / info card ──────────────────────────────────────────────────────

class GSInfoCard extends StatelessWidget {
  const GSInfoCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.iconBgColor,
    this.subtitle,
    this.onTap,
    this.trailing,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color iconBgColor;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return GSCard(
      onTap: onTap,
      padding: const EdgeInsets.all(GSSpacing.s4),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBgColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(GSRadius.md),
            ),
            child: Icon(icon, color: iconBgColor, size: GSSize.iconLg),
          ),
          const SizedBox(width: GSSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                      fontSize: 12,
                      color: GSColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    )),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: GSColors.textPrimary,
                    )),
                if (subtitle != null)
                  Text(subtitle!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: GSColors.textDisabled,
                      )),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ─── Driver / Option card (route detail) ─────────────────────────────────────

class GSOptionCard extends StatelessWidget {
  const GSOptionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.imageUrl,
    required this.avatarUrl,
    required this.rating,
    this.onBook,
    this.isSelected = false,
  });

  final String title;
  final String subtitle;
  final String price;
  final String imageUrl;
  final String avatarUrl;
  final String rating;
  final VoidCallback? onBook;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return GSCard(
      shadow: isSelected ? GSShadow.accent : GSShadow.card,
      border: isSelected
          ? Border.all(color: GSColors.accent, width: 2)
          : Border.all(color: GSColors.border, width: 1),
      padding: const EdgeInsets.all(GSSpacing.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: NetworkImage(avatarUrl),
                backgroundColor: GSColors.surfaceDark,
              ),
              const SizedBox(width: GSSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: GSColors.textPrimary,
                        )),
                    Text(rating,
                        style: const TextStyle(
                          fontSize: 12,
                          color: GSColors.textSecondary,
                        )),
                  ],
                ),
              ),
              Text(price,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: GSColors.accent,
                  )),
            ],
          ),
          const SizedBox(height: GSSpacing.s3),
          ClipRRect(
            borderRadius: BorderRadius.circular(GSRadius.md),
            child: Image.network(
              imageUrl,
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 120,
                color: GSColors.surfaceDark,
                child: const Icon(Icons.directions_car,
                    size: 48, color: GSColors.textDisabled),
              ),
            ),
          ),
          const SizedBox(height: GSSpacing.s3),
          Row(
            children: [
              const Icon(Icons.access_time,
                  size: 14, color: GSColors.textSecondary),
              const SizedBox(width: 4),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 13, color: GSColors.textSecondary)),
              const Spacer(),
              if (onBook != null)
                ElevatedButton(
                  onPressed: onBook,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(100, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(GSRadius.full),
                    ),
                  ),
                  child: const Text('Reservar',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
