import 'dart:math';

import 'package:baller/ui/theme/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A prize-style wheel with a fixed pointer at the top.
///
/// The wheel does not pick outcomes. Whenever [spinId] changes it animates to
/// land on [targetIndex], then calls [onSpinEnd].
class SpinWheel extends StatefulWidget {
  const SpinWheel({
    super.key,
    required this.labels,
    required this.targetIndex,
    required this.spinId,
    this.onSpinEnd,
    this.duration = const Duration(milliseconds: 3200),
  });

  final List<String> labels;
  final int targetIndex;
  final int spinId;
  final VoidCallback? onSpinEnd;
  final Duration duration;

  @override
  State<SpinWheel> createState() => _SpinWheelState();
}

class _SpinWheelState extends State<SpinWheel>
    with SingleTickerProviderStateMixin {
  static const _fullTurns = 5;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..addStatusListener(_onStatus);
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  final Random _jitter = Random();

  double _from = 0;
  double _to = 0;

  double get _rotation => _from + (_to - _from) * _curve.value;

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) widget.onSpinEnd?.call();
  }

  @override
  void didUpdateWidget(SpinWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.spinId != oldWidget.spinId) _spinTo(widget.targetIndex);
  }

  void _spinTo(int index) {
    const turn = 2 * pi;
    final sweep = turn / widget.labels.length;
    final current = _rotation;
    // Cosmetic: don't always stop dead-centre on the segment.
    final jitter = (_jitter.nextDouble() - 0.5) * sweep * 0.6;
    // Rotation that puts the centre of segment [index] under the pointer.
    final landing = (-(index + 0.5) * sweep + jitter) % turn;
    _from = current;
    _to = current - current % turn + turn * _fullTurns + landing;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        painter: _WheelPainter(labels: widget.labels, rotation: _rotation),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter({required this.labels, required this.rotation});

  static const _fills = [AppColors.charcoal, AppColors.surface];
  static const _inks = [Colors.white, AppColors.ink];
  static const _rim = 6.0;

  final List<String> labels;
  final double rotation;

  @override
  void paint(Canvas canvas, Size size) {
    // Leave room for the pointer above and the shadow around.
    final radius = min(size.width, size.height) / 2 - 20;
    if (radius <= 0) return;
    final center = size.center(Offset.zero);
    final sweep = 2 * pi / labels.length;
    final fontSize = (radius * 0.15).clamp(10.0, 24.0);

    // Lifted shadow + white rim.
    canvas.drawCircle(
      center.translate(0, radius * 0.08),
      radius + _rim,
      Paint()
        ..color = AppColors.charcoal.withValues(alpha: 0.16)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.12),
    );
    canvas.drawCircle(center, radius + _rim, Paint()..color = Colors.white);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    final rect = Rect.fromCircle(center: Offset.zero, radius: radius);
    for (var i = 0; i < labels.length; i++) {
      final start = -pi / 2 + i * sweep;
      canvas.drawArc(
        rect,
        start,
        sweep,
        true,
        Paint()..color = _fills[i % _fills.length],
      );

      final label = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: AppText.manrope(
            fontSize,
            weight: 600,
            color: _inks[i % _inks.length],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.save();
      canvas.rotate(start + sweep / 2);
      canvas.translate(radius * 0.74, 0);
      canvas.rotate(pi / 2); // reads along the rim, top facing outward
      label.paint(canvas, Offset(-label.width / 2, -label.height / 2));
      canvas.restore();
    }
    canvas.restore();

    // Hub: white disc with a charcoal dot.
    final hub = radius * 0.2;
    canvas.drawCircle(
      center.translate(0, 4),
      hub,
      Paint()
        ..color = AppColors.charcoal.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(center, hub, Paint()..color = Colors.white);
    canvas.drawCircle(center, hub * 0.25, Paint()..color = AppColors.charcoal);

    // Pointer: charcoal triangle with a white stroke, fixed at the top.
    final top = center.dy - radius - _rim;
    final pointer = Path()
      ..moveTo(center.dx, top + 22)
      ..lineTo(center.dx - 13, top - 8)
      ..lineTo(center.dx + 13, top - 8)
      ..close();
    canvas.drawPath(
      pointer,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(pointer, Paint()..color = AppColors.charcoal);
  }

  @override
  bool shouldRepaint(_WheelPainter old) =>
      old.rotation != rotation || !listEquals(old.labels, labels);
}
