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
    return const Padding(
      padding: EdgeInsets.symmetric(
        horizontal: GSSpacing.s4,
        vertical: GSSpacing.s3,
      ),
      child: Row(
        children: [
          GSSkeletonLoader(width: 44, height: 44, radius: 22),
          SizedBox(width: GSSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GSSkeletonLoader(width: double.infinity, height: 14, radius: 4),
                SizedBox(height: GSSpacing.s2),
                GSSkeletonLoader(width: 100, height: 11, radius: 4),
              ],
            ),
          ),
          SizedBox(width: GSSpacing.s3),
          GSSkeletonLoader(width: 60, height: 14, radius: 4),
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

/// Renders [itemCount] skeleton items with a staggered fade-in entrance.
/// Each item fades in [GSAnimDuration.skeletonStagger]ms after the previous.
///
/// Usage:
/// ```dart
/// StaggeredSkeletonList(
///   itemCount: 5,
///   itemBuilder: (_) => const GSTransactionSkeleton(),
/// )
/// ```
class StaggeredSkeletonList extends StatefulWidget {
  const StaggeredSkeletonList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
  });

  final int itemCount;
  final Widget Function(int index) itemBuilder;

  @override
  State<StaggeredSkeletonList> createState() => _StaggeredSkeletonListState();
}

class _StaggeredSkeletonListState extends State<StaggeredSkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final int _totalMs;

  @override
  void initState() {
    super.initState();
    _totalMs = 400 + widget.itemCount * GSAnimDuration.skeletonStagger;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _totalMs),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(widget.itemCount, (i) {
        final startFraction =
            (i * GSAnimDuration.skeletonStagger) / _totalMs;
        final endFraction =
            ((i * GSAnimDuration.skeletonStagger) + 400) / _totalMs;
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: _controller,
            curve: Interval(
              startFraction.clamp(0.0, 1.0),
              endFraction.clamp(0.0, 1.0),
              curve: Curves.easeOut,
            ),
          ),
          child: widget.itemBuilder(i),
        );
      }),
    );
  }
}
