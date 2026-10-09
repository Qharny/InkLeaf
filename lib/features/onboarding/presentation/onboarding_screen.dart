import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/sketch_styles.dart';
import '../../../core/storage/app_prefs.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/doodles.dart';

class _OnboardingPage {
  const _OnboardingPage({
    required this.lead,
    required this.highlight,
    required this.body,
    required this.marker,
    this.icon,
    this.fill,
  });

  /// Title is "[lead][highlight]", with [highlight] drawn over in marker.
  final String lead;
  final String highlight;
  final String body;
  final Color marker;

  /// Feature pages show an icon on a pastel blob; the intro shows the logo.
  final IconData? icon;
  final Color? fill;
}

const _pages = [
  _OnboardingPage(
    lead: 'Your thoughts, ',
    highlight: 'in ink',
    body: 'Inkleaf is a warm little notebook for everything on your mind.',
    marker: AppColors.markerYellow,
  ),
  _OnboardingPage(
    lead: 'Capture ',
    highlight: 'anything',
    body:
        'Jot a quick thought, or snap a page and turn it into text you can '
        'edit.',
    marker: AppColors.markerYellow,
    icon: Icons.document_scanner_outlined,
    fill: AppColors.noteYellow,
  ),
  _OnboardingPage(
    lead: 'Connect your ',
    highlight: 'ideas',
    body: 'Drop notes on a canvas, draw arrows, and see the bigger picture.',
    marker: AppColors.markerBlue,
    icon: Icons.hub_outlined,
    fill: AppColors.noteBlue,
  ),
  _OnboardingPage(
    lead: 'Find it ',
    highlight: 'again',
    body:
        'Search every note, even the words inside your scans. Works offline, '
        'too.',
    marker: AppColors.markerGreen,
    icon: Icons.manage_search_rounded,
    fill: AppColors.noteGreen,
  ),
];

/// Four-page intro: what Inkleaf is, then capture, connect and find.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  bool get _isLast => _index == _pages.length - 1;

  Duration get _pageDuration => MediaQuery.disableAnimationsOf(context)
      ? const Duration(milliseconds: 1)
      : const Duration(milliseconds: 380);

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      _controller.nextPage(duration: _pageDuration, curve: Curves.easeOutCubic);
    }
  }

  Future<void> _finish() async {
    await AppPrefs.instance.completeOnboarding();
    if (mounted) context.go(AppRoutes.home);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return PopScope(
      // Android back steps through the pages before leaving.
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _controller.previousPage(
            duration: _pageDuration,
            curve: Curves.easeOutCubic,
          );
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              SizedBox(
                height: 56,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: AnimatedOpacity(
                    opacity: _isLast ? 0 : 1,
                    duration: const Duration(milliseconds: 200),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: TextButton(
                        onPressed: _isLast ? null : _finish,
                        child: const Text('Skip'),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) => AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      final page =
                          _controller.hasClients &&
                              _controller.position.haveDimensions
                          ? _controller.page ?? _index.toDouble()
                          : _index.toDouble();
                      return _PageContent(
                        page: _pages[i],
                        // -1..1: how far this page is from the center.
                        offset: reduceMotion ? 0 : (page - i).clamp(-1.0, 1.0),
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  children: [
                    _PageDots(count: _pages.length, index: _index),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _next,
                        child: Text(_isLast ? 'Get started' : 'Next'),
                      ),
                    ),
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

class _PageContent extends StatelessWidget {
  const _PageContent({required this.page, required this.offset});

  final _OnboardingPage page;
  final double offset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fade = 1 - offset.abs() * 0.7;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Expanded(
            child: Center(
              // The art drifts a little slower than the page for depth.
              child: Transform.translate(
                offset: Offset(offset * 90, 0),
                child: Opacity(
                  opacity: fade.clamp(0.0, 1.0),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: page.icon == null
                        ? const _IntroArt()
                        : _FeatureArt(icon: page.icon!, fill: page.fill!),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              children: [
                Semantics(
                  header: true,
                  label: '${page.lead}${page.highlight}',
                  excludeSemantics: true,
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        page.lead,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineLarge,
                      ),
                      MarkerHighlight(
                        color: page.marker,
                        child: Text(
                          page.highlight,
                          style: theme.textTheme.headlineLarge,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  page.body,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Intro page: the logo surrounded by sparks and leaves.
class _IntroArt extends StatelessWidget {
  const _IntroArt();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 300,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(left: 20, top: 6, child: SparkRays(size: 56)),
          Positioned(
            right: 34,
            top: 14,
            child: LeafDoodle(size: 34, rotation: 0.5),
          ),
          Positioned(
            right: 18,
            top: 56,
            child: LeafDoodle(size: 22, rotation: 1.1, outlined: false),
          ),
          Positioned(
            right: 10,
            bottom: 40,
            child: SparkRays(size: 44, angle: -math.pi / 6),
          ),
          Positioned(left: 30, bottom: 10, child: SquiggleDoodle(width: 110)),
          AppLogo(size: 170),
        ],
      ),
    );
  }
}

/// Feature pages: a big icon on a sketched pastel blob, with doodles.
class _FeatureArt extends StatelessWidget {
  const _FeatureArt({required this.icon, required this.fill});

  final IconData icon;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Offset outline sheet behind, like the green one on the logo.
          Transform.translate(
            offset: const Offset(14, 14),
            child: Transform.rotate(
              angle: 0.06,
              child: Container(
                width: 196,
                height: 196,
                decoration: ShapeDecoration(
                  shape: SketchBorder(
                    side: BorderSide(
                      color: AppColors.ink.withValues(alpha: 0.35),
                      width: 1.4,
                    ),
                    radius: 64,
                    seed: icon.codePoint + 1,
                    passes: 1,
                  ),
                ),
              ),
            ),
          ),
          Transform.rotate(
            angle: -0.05,
            child: Container(
              width: 196,
              height: 196,
              decoration: ShapeDecoration(
                color: fill,
                shape: SketchBorder(radius: 64, seed: icon.codePoint),
              ),
            ),
          ),
          ExcludeSemantics(child: Icon(icon, size: 96, color: AppColors.ink)),
          const Positioned(left: 18, top: 4, child: SparkRays(size: 52)),
          const Positioned(
            right: 22,
            bottom: 12,
            child: LeafDoodle(size: 32, rotation: 0.7),
          ),
          const Positioned(
            right: 8,
            top: 30,
            child: SparkRays(size: 40, angle: -math.pi / 5),
          ),
        ],
      ),
    );
  }
}

/// Hand-drawn page dots: the current page is a filled ink pill.
class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).colorScheme.onSurface;
    return Semantics(
      label: 'Page ${index + 1} of $count',
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: i == index ? 26 : 10,
              height: 10,
              decoration: BoxDecoration(
                color: i == index ? ink : Colors.transparent,
                border: Border.all(color: ink, width: 1.6),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
        ],
      ),
    );
  }
}
