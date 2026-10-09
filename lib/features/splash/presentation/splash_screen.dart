import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/sketch_styles.dart';
import '../../../core/storage/app_prefs.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/doodles.dart';

/// Picks up from the native splash (same logo, same size, same paper), gives
/// the logo a little hand-drawn "pop", then moves on to onboarding or home.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  /// Matches the native splash image (512px at 4x = 128dp) for a seamless
  /// handoff.
  static const logoSize = 128.0;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  // Logo: quick squash-and-settle, as if just stamped onto the page.
  late final _logoScale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.08), weight: 30),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.08,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeOutBack)),
      weight: 70,
    ),
  ]).animate(_interval(0.0, 0.45));
  // In turns: a slight counter-clockwise tilt that settles upright.
  late final _logoTilt = Tween(
    begin: -0.008,
    end: 0.0,
  ).chain(CurveTween(curve: Curves.easeOutBack)).animate(_interval(0.0, 0.45));
  late final _doodles = _interval(0.3, 0.65, Curves.easeOutBack);
  late final _name = _interval(0.35, 0.75, Curves.easeOutCubic);
  late final _tagline = _interval(0.55, 0.95, Curves.easeOutCubic);

  Timer? _exitTimer;
  bool _started = false;

  CurvedAnimation _interval(
    double begin,
    double end, [
    Curve curve = Curves.linear,
  ]) => CurvedAnimation(
    parent: _controller,
    curve: Interval(begin, end, curve: curve),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      _exitTimer = Timer(const Duration(milliseconds: 700), _exit);
    } else {
      _controller.forward().whenComplete(() {
        if (!mounted) return;
        _exitTimer = Timer(const Duration(milliseconds: 450), _exit);
      });
    }
  }

  void _exit() {
    if (!mounted) return;
    context.go(
      AppPrefs.instance.onboardingDone ? AppRoutes.home : AppRoutes.onboarding,
    );
  }

  @override
  void dispose() {
    _exitTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const logo = SplashScreen.logoSize;

    // easeOutBack overshoots past 1, so opacity is clamped separately.
    Widget popIn(Widget child) => ScaleTransition(
      scale: _doodles,
      child: FadeTransition(opacity: _interval(0.3, 0.55), child: child),
    );

    Widget riseIn(Animation<double> a, Widget child) => FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: a.drive(Tween(begin: const Offset(0, 0.4), end: Offset.zero)),
        child: child,
      ),
    );

    return Scaffold(
      body: Semantics(
        label: 'Inkleaf. Ideas today, progress tomorrow.',
        container: true,
        excludeSemantics: true,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: logo * 1.9,
                height: logo * 1.5,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      child: popIn(const SparkRays(size: 48)),
                    ),
                    Positioned(
                      right: 6,
                      top: 10,
                      child: popIn(const LeafDoodle(size: 26, rotation: 0.5)),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 18,
                      child: popIn(
                        const SparkRays(size: 40, angle: -math.pi / 6),
                      ),
                    ),
                    Positioned(
                      left: 14,
                      bottom: 6,
                      child: popIn(
                        const LeafDoodle(
                          size: 20,
                          rotation: -0.7,
                          outlined: false,
                        ),
                      ),
                    ),
                    RotationTransition(
                      turns: _logoTilt,
                      child: ScaleTransition(
                        scale: _logoScale,
                        child: const AppLogo(size: logo),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              riseIn(
                _name,
                MarkerHighlight(
                  child: Text('Inkleaf', style: theme.textTheme.displayMedium),
                ),
              ),
              const SizedBox(height: 6),
              riseIn(
                _tagline,
                Column(
                  children: [
                    Text(
                      'Ideas today, progress tomorrow.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const SquiggleDoodle(width: 96, color: AppColors.sage),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
