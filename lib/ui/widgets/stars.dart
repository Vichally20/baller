import 'package:baller/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// "★★★★☆" strength rating, read out as "4 of 5 stars".
class Stars extends StatelessWidget {
  const Stars({
    super.key,
    required this.count,
    this.size = 13,
    this.color = AppColors.ink,
  });

  final int count;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
    '★' * count + '☆' * (5 - count),
    semanticsLabel: '$count of 5 stars',
    style: AppText.inter(size, letterSpacing: 1, color: color),
  );
}
