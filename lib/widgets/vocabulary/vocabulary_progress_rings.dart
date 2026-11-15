import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Ring colors, outer to inner: reviewed, recognized, learned.
const List<Color> vocabularyRingColors = [
  Color(0xFFF2A93B),
  Color(0xFFE0674F),
  Color(0xFF3F6BE0),
];

/// Three concentric progress rings, each sweep in 0..1.
class VocabularyProgressRings extends StatelessWidget {
  const VocabularyProgressRings({
    super.key,
    required this.sweeps,
    this.size = 132,
    this.center,
  });

  final List<double> sweeps;
  final double size;
  final Widget? center;

  @override
  Widget build(BuildContext context) {
    final track = Theme.of(context).colorScheme.onSurface.withOpacity(0.08);
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _RingsPainter(sweeps: sweeps, track: track),
        child: center == null ? null : Center(child: center),
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  _RingsPainter({required this.sweeps, required this.track});

  final List<double> sweeps;
  final Color track;

  static const double _stroke = 11;
  static const double _gap = 5;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = size.shortestSide / 2 - _stroke / 2;
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..color = track;

    for (var i = 0; i < sweeps.length; i++) {
      final rect = Rect.fromCircle(
        center: center,
        radius: maxRadius - i * (_stroke + _gap),
      );
      canvas.drawArc(rect, 0, math.pi * 2, false, trackPaint);

      final sweep = sweeps[i].clamp(0.0, 1.0);
      if (sweep <= 0) continue;
      canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _stroke
          ..strokeCap = StrokeCap.round
          ..color = vocabularyRingColors[i % vocabularyRingColors.length],
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingsPainter oldDelegate) =>
      oldDelegate.track != track || !listEquals(oldDelegate.sweeps, sweeps);
}
