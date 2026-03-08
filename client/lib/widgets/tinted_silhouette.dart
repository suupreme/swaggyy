import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class TintedSilhouette extends StatelessWidget {
  /// The color to tint the t-shirt
  final Color shirtColor;

  /// The color to tint the pants
  final Color pantsColor;

  /// The overall visual scale of the outfit icon
  final double size;

  const TintedSilhouette({
    super.key,
    required this.shirtColor,
    required this.pantsColor,
    this.size = 120.0,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Top: T-Shirt
        SvgPicture.asset(
          'assets/images/shirt-svgrepo-com.svg',
          height: size * 0.55, // Proportional sizing for the top
          colorFilter: ColorFilter.mode(shirtColor, BlendMode.srcIn),
        ),
        // A minimal gap between the shirt and pants
        const SizedBox(height: 2),
        // Bottom: Pants
        SvgPicture.asset(
          'assets/images/pants-svgrepo-com.svg',
          height: size * 0.55, // Pants generally appear longer
          colorFilter: ColorFilter.mode(pantsColor, BlendMode.srcIn),
        ),
      ],
    );
  }
}
