import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Animated startup screen shown while Supabase initializes.
///
/// Sequence:
///   1. Maroon gradient background with a soft gold glow
///   2. UM logo fades in while scaling 80% → 100%
///   3. "BORROW LOG" title slides up from below
///   4. Gold accent line draws across
///   5. A light "shimmer" sweeps diagonally across the logo
///   6. A thin gold progress bar fills at the bottom
///   7. Calls [onFinished] — the parent handles the transition to the
///      next screen (via AnimatedSwitcher).
///
/// If the device has "remove animations" turned on, the final frame is shown
/// briefly and [onFinished] is called without any motion.
class AnimatedSplashScreen extends StatefulWidget {
  final VoidCallback? onFinished;
  final Duration duration;

  const AnimatedSplashScreen({
    super.key,
    this.onFinished,
    this.duration = const Duration(milliseconds: 2500),
  });

  @override
  State<AnimatedSplashScreen> createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen>
    with TickerProviderStateMixin {
  static const _logoAsset = 'assets/images/um-splash-logo.png';

  late final AnimationController _controller;
  late final AnimationController _shimmerController;

  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;
  late final Animation<double> _titleOffset;
  late final Animation<double> _titleOpacity;
  late final Animation<double> _accentWidth;
  late final Animation<double> _progress;

  Timer? _warmUpTimer;
  Timer? _shimmerTimer;

  /// The logo is loaded into the image cache before the animation starts so
  /// it never "pops in" half-way through the fade. It is decoded at full
  /// resolution on purpose: downsizing at decode time made it look soft.
  bool _precached = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.30, curve: Curves.easeOut),
      ),
    );
    _logoScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.40, curve: Curves.easeOutBack),
      ),
    );

    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.20, 0.50, curve: Curves.easeOut),
      ),
    );
    _titleOffset = Tween<double>(begin: 20.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.20, 0.50, curve: Curves.easeOutCubic),
      ),
    );

    _accentWidth = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.40, 0.70, curve: Curves.easeInOut),
      ),
    );

    _progress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.50, 1.0, curve: Curves.easeInOut),
      ),
    );

    // Start after the first frame + a short warm-up so the opening
    // frames aren't dropped while the app is still initializing.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _warmUpTimer = Timer(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        _runSequence();
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_precached) return;
    _precached = true;
    precacheImage(const AssetImage(_logoAsset), context, onError: (_, _) {});
  }

  /// Logo diameter: about 38% of the screen width, kept within sensible
  /// limits so it is neither tiny on small phones nor huge on tablets.
  double _logoSizeFor(double screenWidth) =>
      (screenWidth * 0.38).clamp(120.0, 200.0);

  Future<void> _runSequence() async {
    // Respect the system "remove animations" accessibility setting.
    if (MediaQuery.of(context).disableAnimations) {
      _controller.value = 1.0;
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      widget.onFinished?.call();
      return;
    }

    _shimmerTimer = Timer(
      const Duration(milliseconds: 700),
      () {
        if (mounted) _shimmerController.forward();
      },
    );

    await _controller.forward();

    _shimmerTimer?.cancel();

    if (!mounted) return;
    widget.onFinished?.call();
  }

  @override
  void dispose() {
    _warmUpTimer?.cancel();
    _shimmerTimer?.cancel();
    _controller.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logoSize = _logoSizeFor(MediaQuery.of(context).size.width);

    return Scaffold(
      // Same colour as the end of the gradient so the transition to the
      // next screen is seamless — no black or white flash.
      backgroundColor: AppTheme.maroonDark,
      body: Semantics(
        container: true,
        label: 'BorrowLog, University of Mindanao. Loading.',
        // The label above says it all; hide the individual pieces so a
        // screen reader doesn't read the title and subtitle twice.
        child: ExcludeSemantics(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.maroon,
                  AppTheme.maroonDark,
                ],
              ),
            ),
            child: Stack(
              children: [
                _glow(logoSize),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _logo(logoSize),
                        SizedBox(height: logoSize * 0.2),
                        _title(),
                        const SizedBox(height: 10),
                        _accentLine(),
                        const SizedBox(height: 14),
                        _subtitle(),
                      ],
                    ),
                  ),
                ),
                _progressBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────── Pieces ─────────────────────────

  /// Soft gold glow behind the logo that fades in with it.
  Widget _glow(double logoSize) {
    final glowSize = logoSize * 2.4;
    return Align(
      alignment: const Alignment(0, -0.12),
      child: FadeTransition(
        opacity: _logoOpacity,
        child: IgnorePointer(
          child: Container(
            width: glowSize,
            height: glowSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppTheme.gold.withValues(alpha: 0.22),
                  AppTheme.gold.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _logo(double logoSize) {
    return FadeTransition(
      opacity: _logoOpacity,
      child: ScaleTransition(
        scale: _logoScale,
        filterQuality: FilterQuality.high,
        child: SizedBox(
          width: logoSize,
          height: logoSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: logoSize,
                height: logoSize,
                // No padding — the seal fills the white circle edge-to-edge.
                // A thin gold ring gives the seal a crisp edge on the maroon.
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.gold.withValues(alpha: 0.9),
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image(
                    image: const AssetImage(_logoAsset),
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                    isAntiAlias: true,
                    errorBuilder: (_, _, _) => Icon(
                      Icons.science_outlined,
                      size: logoSize * 0.5,
                      color: AppTheme.maroon,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: ClipOval(child: _shimmer(logoSize)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shimmer(double logoSize) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, _) {
        final t = _shimmerController.value;
        if (t == 0 || t == 1) return const SizedBox.shrink();
        return Transform.translate(
          offset: Offset((t * 3 - 1.5) * logoSize, 0),
          child: Transform.rotate(
            angle: 0.5,
            child: Container(
              width: logoSize * 0.25,
              height: logoSize * 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0),
                    Colors.white.withValues(alpha: 0.55),
                    Colors.white.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _title() {
    return FadeTransition(
      opacity: _titleOpacity,
      child: AnimatedBuilder(
        animation: _titleOffset,
        child: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'BORROW LOG',
            maxLines: 1,
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: 4,
            ),
          ),
        ),
        builder: (context, child) => Transform.translate(
          offset: Offset(0, _titleOffset.value),
          child: child,
        ),
      ),
    );
  }

  Widget _accentLine() {
    return FadeTransition(
      opacity: _titleOpacity,
      child: AnimatedBuilder(
        animation: _accentWidth,
        builder: (context, _) {
          return Container(
            height: 3,
            width: 80 * _accentWidth.value,
            decoration: BoxDecoration(
              color: AppTheme.gold,
              borderRadius: BorderRadius.circular(2),
            ),
          );
        },
      ),
    );
  }

  Widget _subtitle() {
    return FadeTransition(
      opacity: _titleOpacity,
      child: const Text(
        'University of Mindanao',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white70,
          fontSize: 13,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _progressBar() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 40),
          child: Center(
            child: SizedBox(
              width: 120,
              child: AnimatedBuilder(
                animation: _progress,
                builder: (context, _) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: _progress.value,
                      minHeight: 3,
                      color: AppTheme.gold,
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}