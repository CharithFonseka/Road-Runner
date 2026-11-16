// Road Runner — Slide to Start control (UI kit Revision 5, mandatory).
// Owner: Tharushi
// SRS reference: Section 8.4, FR-01 (trigger), NFR-09, NFR-14
//
// A 72dp orange track with a white runner handle. It starts a run in ONE
// deliberate action, with no confirmation screen:
//
//   * Drag: the handle follows the finger. Releasing at 70% of the travel
//     or more starts the run; releasing earlier snaps the handle back.
//   * Press and hold anywhere on the track for [SlideToStart.holdDuration]
//     (1 s) without moving: for users who cannot drag.
//   * Screen readers, switch access and keyboards: the control is one button
//     named "Start run". A single activation (TalkBack double tap, a switch
//     press, Enter or Space) starts the run.
//
// An ordinary tap does nothing. After a start the control shows "Starting
// run" and ignores every further gesture, so [SlideToStart.onStart] runs
// exactly once. It re-arms when the parent turns [SlideToStart.starting]
// off, or when the screen becomes visible again after another route covered
// it (for example after returning from the Run or Permissions screen).

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_spacing.dart';
import '../../app_strings.dart';

class SlideToStart extends StatefulWidget {
  const SlideToStart({
    super.key,
    required this.onStart,
    this.enabled = true,
    this.starting = false,
    this.holdDuration = defaultHoldDuration,
    this.maxWidth,
  });

  /// Called once per activation. The parent checks permissions and opens
  /// the Run screen.
  final VoidCallback onStart;

  /// False greys the control out and ignores all input.
  final bool enabled;

  /// The parent's own "a run is starting" flag. While true the control shows
  /// the Starting state; switching it back to false re-arms the control.
  final bool starting;

  /// How long a press must be held to start.
  final Duration holdDuration;

  /// Optional maximum width constraint. When provided, the track does not
  /// stretch beyond this width, ensuring comfortable thumb travel distance.
  final double? maxWidth;

  static const double height = AppSpacing.heroButtonHeight; // 72
  static const double handleSize = 64;
  static const double inset = (height - handleSize) / 2; // 4

  /// Share of the travel the handle must reach before release starts a run.
  static const double threshold = 0.7;

  /// Recommended upper bound for landscape/wide screens.
  static const double defaultLandscapeMaxWidth = 340;

  static const Duration defaultHoldDuration = Duration(seconds: 1);
  static const Duration snapBackDuration = Duration(milliseconds: 200);

  static const Key handleKey = Key('slideToStart.handle');

  /// Track colour while starting (UI kit "startBg"). White on it: 8.9:1.
  static const Color startingTrackColor = Color(0xFF7E3A19);

  @override
  State<SlideToStart> createState() => _SlideToStartState();
}

class _SlideToStartState extends State<SlideToStart>
    with TickerProviderStateMixin {
  /// Handle position as a share of the travel (0 = start, 1 = end).
  late final AnimationController _position = AnimationController(
    vsync: this,
    duration: SlideToStart.snapBackDuration,
  );

  /// Press-and-hold progress. `preserve` keeps the real 1 s duration even
  /// when the system asks for reduced motion (that setting shortens normal
  /// animations, which would make an accidental touch start a run).
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: widget.holdDuration,
    animationBehavior: AnimationBehavior.preserve,
  )..addStatusListener(_onHoldStatus);

  /// Latched after an activation until the control re-arms.
  bool _fired = false;
  bool _dragging = false;
  int? _holdPointer;
  Offset? _holdOrigin;
  double _travel = 1;
  bool _visible = true;
  bool _focusHighlight = false;

  bool get _isStarting => _fired || widget.starting;
  bool get _canInteract => widget.enabled && !_isStarting;
  bool get _reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // TickerMode turns off while another route fully covers this screen and
    // back on when it is shown again: re-arm after the user returns.
    final bool visible = TickerMode.of(context);
    if (visible && !_visible && _fired && !widget.starting) _rearm();
    _visible = visible;
  }

  @override
  void didUpdateWidget(SlideToStart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.holdDuration != widget.holdDuration) {
      _hold.duration = widget.holdDuration;
    }
    if (oldWidget.starting && !widget.starting) _rearm();
    if (!widget.enabled && oldWidget.enabled) {
      _resetHold();
      _dragging = false;
      if (!_isStarting) _position.value = 0;
    }
  }

  @override
  void dispose() {
    _position.dispose();
    _hold.dispose();
    super.dispose();
  }

  /// Called only from lifecycle methods, which rebuild anyway.
  void _rearm() {
    _fired = false;
    _dragging = false;
    _resetHold();
    _position.value = 0;
  }

  /// The single place a run is started. Every path (drag, hold, screen
  /// reader, keyboard) goes through here, and the latch makes it one-shot.
  void _fire() {
    if (!_canInteract) return;
    setState(() {
      _fired = true;
      _dragging = false;
    });
    _cancelHold();
    if (_reduceMotion) {
      _position.value = 1;
    } else {
      _position.animateTo(1, curve: Curves.easeOut);
    }
    HapticFeedback.mediumImpact();
    widget.onStart();
  }

  // ─── Drag ───────────────────────────────────────────────────────────────────

  // The drag recognizer is alone in the gesture arena, so it "starts" on
  // touch-down. A press only stops counting as a hold once the finger
  // moves past the touch slop (see [_onPointerMove]).
  void _onDragStart(DragStartDetails details) {
    if (!_canInteract) return;
    _position.stop();
    setState(() => _dragging = true);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_dragging) return;
    final bool rtl = Directionality.of(context) == TextDirection.rtl;
    final double dx = rtl ? -details.delta.dx : details.delta.dx;
    _position.value = (_position.value + dx / _travel).clamp(0.0, 1.0);
  }

  void _onDragEnd([DragEndDetails? details]) {
    if (!_dragging) return;
    setState(() => _dragging = false);
    if (_position.value >= SlideToStart.threshold) {
      _fire();
    } else {
      _snapBack();
    }
  }

  void _snapBack() {
    if (_reduceMotion) {
      _position.value = 0;
    } else {
      _position.animateTo(0, curve: Curves.easeOutCubic);
    }
  }

  // ─── Press and hold ─────────────────────────────────────────────────────────

  void _onPointerDown(PointerDownEvent event) {
    if (!_canInteract || _holdPointer != null || _dragging) return;
    _holdPointer = event.pointer;
    _holdOrigin = event.position;
    _hold.forward(from: 0);
    setState(() {});
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _holdPointer) return;
    if ((event.position - _holdOrigin!).distance > kTouchSlop) _cancelHold();
  }

  void _onPointerEnd(PointerEvent event) {
    if (event.pointer == _holdPointer) _cancelHold();
  }

  void _onHoldStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _holdPointer != null) {
      _holdPointer = null;
      _fire();
    }
  }

  void _cancelHold() {
    final bool wasHolding = _holdPointer != null || _hold.value > 0;
    _resetHold();
    if (wasHolding && mounted) setState(() {});
  }

  void _resetHold() {
    _holdPointer = null;
    _holdOrigin = null;
    _hold.stop();
    _hold.value = 0;
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final bool starting = _isStarting;
    return Semantics(
      container: true,
      button: true,
      enabled: _canInteract,
      liveRegion: starting,
      label: starting
          ? AppStrings.slideStarting
          : AppStrings.startRunSemanticsLabel,
      hint: _canInteract ? AppStrings.startRunSemanticsHint : null,
      onTap: _canInteract ? _fire : null,
      excludeSemantics: true,
      child: FocusableActionDetector(
        enabled: _canInteract,
        onShowFocusHighlight: (v) => setState(() => _focusHighlight = v),
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _fire();
              return null;
            },
          ),
          ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
            onInvoke: (_) {
              _fire();
              return null;
            },
          ),
        },
        child: () {
          Widget control = Listener(
            onPointerDown: _onPointerDown,
            onPointerMove: _onPointerMove,
            onPointerUp: _onPointerEnd,
            onPointerCancel: _onPointerEnd,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              dragStartBehavior: DragStartBehavior.down,
              onHorizontalDragStart: _canInteract ? _onDragStart : null,
              onHorizontalDragUpdate: _canInteract ? _onDragUpdate : null,
              onHorizontalDragEnd: _canInteract ? _onDragEnd : null,
              onHorizontalDragCancel: _canInteract ? _onDragEnd : null,
              child: SizedBox(
                height: SlideToStart.height,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _travel = math.max(
                      1,
                      constraints.maxWidth -
                          SlideToStart.handleSize -
                          2 * SlideToStart.inset,
                    );
                    return AnimatedBuilder(
                      animation: Listenable.merge([_position, _hold]),
                      builder: (context, _) => Opacity(
                        opacity: widget.enabled || starting ? 1 : 0.5,
                        child: _buildTrack(starting, palette),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
          if (widget.maxWidth != null) {
            control = Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: widget.maxWidth!),
                child: control,
              ),
            );
          }
          return control;
        }(),
      ),
    );
  }

  Widget _buildTrack(bool starting, AppPalette palette) {
    const double inset = SlideToStart.inset;
    const double handle = SlideToStart.handleSize;
    final double t = widget.starting && !_fired ? 1 : _position.value;
    final double offset = t * _travel;
    final double labelOpacity = starting
        ? 1
        : (1 - t / SlideToStart.threshold).clamp(0.0, 1.0);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Track.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: starting ? palette.primaryFillActive : palette.primaryFill,
              borderRadius: const BorderRadius.all(
                Radius.circular(SlideToStart.height / 2),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x47A34A20),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
              border: _focusHighlight
                  ? Border.all(
                      color: palette.isDark
                          ? palette.accent
                          : AppColors.canyonBrownDeep,
                      width: 3,
                    )
                  : null,
            ),
          ),
        ),
        // Light fill behind the handle while it travels.
        if (t > 0 && !starting)
          PositionedDirectional(
            start: inset,
            top: inset,
            bottom: inset,
            width: handle + offset,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0x2EFFFFFF),
                borderRadius: BorderRadius.all(Radius.circular(handle / 2)),
              ),
            ),
          ),
        // Guidance text.
        PositionedDirectional(
          start: starting ? 16 : inset + handle + 8,
          end: starting ? inset + handle + 8 : 16,
          top: 0,
          bottom: 0,
          child: Opacity(
            opacity: labelOpacity,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: starting
                    ? const _StartingLabel()
                    : _GuidanceLabel(
                        holding: _hold.value > 0,
                        color: palette.onPrimaryFill,
                      ),
              ),
            ),
          ),
        ),
        // Hold progress ring around the handle.
        if (_hold.value > 0 && !starting)
          PositionedDirectional(
            start: inset + offset - 3,
            top: inset - 3,
            width: handle + 6,
            height: handle + 6,
            child: IgnorePointer(
              child: CustomPaint(painter: _HoldRingPainter(_hold.value)),
            ),
          ),
        // Handle.
        PositionedDirectional(
          start: inset + offset,
          top: inset,
          width: handle,
          height: handle,
          child: DecoratedBox(
            key: SlideToStart.handleKey,
            decoration: BoxDecoration(
              color: palette.onPrimaryFill,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.directions_run_rounded,
              size: 30,
              color: palette.primaryFill,
            ),
          ),
        ),
      ],
    );
  }
}

const TextStyle _mainLabelStyle = TextStyle(
  fontSize: 20,
  fontWeight: FontWeight.w700,
  height: 1.15,
  color: AppColors.white,
);

class _GuidanceLabel extends StatelessWidget {
  const _GuidanceLabel({required this.holding, required this.color});

  final bool holding;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
            text: '${AppStrings.slideToStart} ',
            children: [
              TextSpan(
                text: AppStrings.slideToStartArrows,
                style: TextStyle(
                  letterSpacing: -2,
                  color: color.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
          maxLines: 1,
          style: _mainLabelStyle.copyWith(color: color),
        ),
        Text(
          holding ? AppStrings.slideKeepHolding : AppStrings.slideOrHold,
          maxLines: 1,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 1.15,
            color: color.withValues(alpha: 230 / 255),
          ),
        ),
      ],
    );
  }
}

class _StartingLabel extends StatelessWidget {
  const _StartingLabel();

  @override
  Widget build(BuildContext context) {
    final Color color = AppPalette.of(context).onPrimaryFill;
    return Text(
      AppStrings.slideStarting,
      maxLines: 1,
      style: _mainLabelStyle.copyWith(color: color),
    );
  }
}

/// White arc that fills clockwise as the press is held.
class _HoldRingPainter extends CustomPainter {
  const _HoldRingPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = (Offset.zero & size).deflate(1.5);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = AppColors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_HoldRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
