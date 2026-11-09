import 'package:baller/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Rounded square with a club's initials. [inverted] is for charcoal
/// backgrounds (white crest, dark letters).
class ClubCrest extends StatelessWidget {
  const ClubCrest({
    super.key,
    required this.initials,
    this.size = 44,
    this.inverted = false,
  });

  final String initials;
  final double size;
  final bool inverted;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: inverted ? Colors.white : AppColors.charcoal,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Text(
        initials,
        style: AppText.manrope(
          size * 0.32,
          weight: 800,
          letterSpacing: 0.5,
          color: inverted ? AppColors.ink : Colors.white,
        ),
      ),
    ),
  );
}
