import 'package:flutter/material.dart';
import 'package:opennutritracker/core/styles/dimens.dart';

/// App mark used in the app bar, settings banner, About dialog, etc.
///
/// Shows the Fitty Kitties cat silhouette (same asset as the launcher icon),
/// clipped to soft rounded corners so the red square does not read as a hard
/// tile against the title.
class DynamicOntLogo extends StatelessWidget {
  const DynamicOntLogo({super.key, this.borderRadius});

  /// Defaults to a radius proportional to typical toolbar usage (~40 px).
  final BorderRadius? borderRadius;

  static const assetPath = 'assets/icon/fitty_kitties_icon_1024.png';

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(Dimens.radiusS),
      child: Image.asset(assetPath, fit: BoxFit.contain),
    );
  }
}
