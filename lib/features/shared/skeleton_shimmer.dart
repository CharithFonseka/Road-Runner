import 'package:flutter/material.dart';

/// Adds a subtle, horizontally sweeping highlight to loading placeholders.
///
/// The child remains visible without animation when reduced motion is enabled.
class SkeletonShimmer extends StatefulWidget {
  const SkeletonShimmer({super.key, required this.child});

  static const Duration sweepDuration = Duration(milliseconds: 1400);

  final Widget child;

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: SkeletonShimmer.sweepDuration,
  );
  bool _isAnimating = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateAnimation();
  }

  void _updateAnimation() {
    final bool shouldAnimate =
        !MediaQuery.disableAnimationsOf(context) && TickerMode.of(context);
    if (shouldAnimate == _isAnimating) return;
    _isAnimating = shouldAnimate;
    if (_isAnimating) {
      _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SkeletonShimmerScope(
      animation: _isAnimating ? _controller : null,
      child: widget.child,
    );
  }
}

/// Highlights a single placeholder using its nearest [SkeletonShimmer].
class SkeletonShimmerBlock extends StatelessWidget {
  const SkeletonShimmerBlock({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final Animation<double>? animation = _SkeletonShimmerScope.of(context);
    if (animation == null) return child;

    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final double offset = animation.value * 4;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(-3 + offset, 0),
            end: Alignment(-1 + offset, 0),
            colors: [
              Colors.transparent,
              Colors.white.withValues(alpha: 0.45),
              Colors.transparent,
            ],
            stops: const [0, 0.5, 1],
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }
}

class _SkeletonShimmerScope extends InheritedWidget {
  const _SkeletonShimmerScope({required this.animation, required super.child});

  final Animation<double>? animation;

  static Animation<double>? of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_SkeletonShimmerScope>()
      ?.animation;

  @override
  bool updateShouldNotify(_SkeletonShimmerScope oldWidget) =>
      animation != oldWidget.animation;
}
