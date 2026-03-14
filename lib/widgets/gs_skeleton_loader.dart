// lib/widgets/gs_skeleton_loader.dart
import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// Animated shimmer skeleton for loading states.
class GSSkeletonLoader extends StatefulWidget {
  const GSSkeletonLoader({
    super.key,
    required this.width,
    required this.height,
    this.radius = 8,
  });

  final double width;
  final double height;
  final double radius;

  @override
  State<GSSkeletonLoader> createState() => _GSSkeletonLoaderState();
}

class _GSSkeletonLoaderState extends State<GSSkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value + 1, 0),
              colors: const [
                Color(0xFFE8ECF2),
                Color(0xFFF5F6FA),
                Color(0xFFE8ECF2),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton for a transaction list item row.
class GSTransactionSkeleton extends StatelessWidget {
  const GSTransactionSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: GSSpacing.s4,
        vertical: GSSpacing.s3,
      ),
      child: Row(
        children: [
          const GSSkeletonLoader(width: 44, height: 44, radius: 22),
          const SizedBox(width: GSSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                GSSkeletonLoader(width: double.infinity, height: 14, radius: 4),
                SizedBox(height: GSSpacing.s2),
                GSSkeletonLoader(width: 100, height: 11, radius: 4),
              ],
            ),
          ),
          const SizedBox(width: GSSpacing.s3),
          const GSSkeletonLoader(width: 60, height: 14, radius: 4),
        ],
      ),
    );
  }
}

/// Skeleton for a full card shape (e.g., wallet physical card).
class GSCardSkeleton extends StatelessWidget {
  const GSCardSkeleton({super.key, this.height = 180});
  final double height;

  @override
  Widget build(BuildContext context) {
    return GSSkeletonLoader(
      width: double.infinity,
      height: height,
      radius: GSRadius.xl,
    );
  }
}
