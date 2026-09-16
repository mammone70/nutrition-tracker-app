import 'package:flutter/material.dart';

/// App mark used in the app bar, settings banner, About dialog, etc.
///
/// Shows the Fitty Kitties cat silhouette (same asset as the launcher icon).
class DynamicOntLogo extends StatelessWidget {
  const DynamicOntLogo({super.key});

  static const assetPath = 'assets/icon/fitty_kitties_icon_1024.png';

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      fit: BoxFit.contain,
    );
  }
}
