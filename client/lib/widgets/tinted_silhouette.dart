import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class TintedSilhouette extends StatelessWidget {
  /// The color to tint the t-shirt
  final Color shirtColor;

  /// The color to tint the pants
  final Color pantsColor;

  const TintedSilhouette({
    super.key,
    required this.shirtColor,
    required this.pantsColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100.0, // Max width of the wider item (shirt)
      height: 190.0, // Combined height with gap
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SvgPicture.asset(
              'assets/images/shirt-svgrepo-com.svg',
              width: 100.0,
              height: 100.0,
              colorFilter: ColorFilter.mode(shirtColor, BlendMode.srcIn),
            ),
          ),
          Positioned(
            top: 110.0, // Positioned after shirt + gap
            left:
                (100 - 80) /
                2, // Center the smaller pants under the wider shirt
            child: SvgPicture.asset(
              'assets/images/pants-svgrepo-com.svg',
              width: 80.0,
              height: 80.0,
              colorFilter: ColorFilter.mode(pantsColor, BlendMode.srcIn),
            ),
          ),
        ],
      ),
    );
  }
}
