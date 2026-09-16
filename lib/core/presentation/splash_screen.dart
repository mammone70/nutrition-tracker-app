import 'dart:async';

import 'package:flutter/material.dart';
import 'package:opennutritracker/core/presentation/widgets/dynamic_ont_logo.dart';
import 'package:opennutritracker/core/utils/navigation_options.dart';

/// First screen shown on launch: the Fitty Kitties mark, then routes to main.
///
/// The native launch screen (Android `launch_background`, iOS
/// `LaunchScreen.storyboard`) paints the same canvas colour behind the Flutter
/// engine while it boots, so the hand-off into this animated splash is seamless.
class SplashScreen extends StatefulWidget {
  /// Kept for call-site compatibility. First launch now seeds a default
  /// profile, so this is always treated as ready for [NavigationOptions.mainRoute].
  final bool userInitialized;

  const SplashScreen({super.key, required this.userInitialized});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _logoSize = 168.0;
  static const _startDelay = Duration(milliseconds: 250);
  static const _animDuration = Duration(milliseconds: 900);

  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;
  Timer? _startTimer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _animDuration);
    _scale = Tween<double>(
      begin: 0.86,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _opacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) _goNext();
    });

    final reduceMotion = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    if (reduceMotion) {
      _startTimer = Timer(const Duration(milliseconds: 400), _goNext);
    } else {
      _startTimer = Timer(_startDelay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  void _goNext() {
    if (_navigated || !mounted) return;
    _navigated = true;
    // Profile data is never required to use the app; first launch seeds a
    // default user during bootstrap so main is always reachable.
    Navigator.of(context).pushReplacementNamed(NavigationOptions.mainRoute);
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: FadeTransition(
          opacity: _opacity,
          child: ScaleTransition(
            scale: _scale,
            child: const SizedBox(
              width: _logoSize,
              height: _logoSize,
              child: DynamicOntLogo(),
            ),
          ),
        ),
      ),
    );
  }
}
