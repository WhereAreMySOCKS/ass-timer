import 'dart:math' as math;

import 'package:ass_timer_flutter/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class CircularIntervalPicker extends StatelessWidget {
  const CircularIntervalPicker({
    required this.seconds,
    required this.onChanged,
    super.key,
  });

  final int seconds;
  final ValueChanged<int> onChanged;

  double get _progress => (seconds.clamp(10, 7200) - 10) / 7190;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '提醒间隔',
        value: formatInterval(seconds),
        slider: true,
        child: SizedBox.square(
          dimension: 190,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanDown: (details) =>
                _update(details.localPosition, const Size.square(190)),
            onPanUpdate: (details) =>
                _update(details.localPosition, const Size.square(190)),
            child: CustomPaint(
              painter: _IntervalPainter(progress: _progress),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text('每', style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 6),
                    Text(
                      formatInterval(seconds),
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                        fontFeatures: <FontFeature>[
                          FontFeature.tabularFigures()
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  void _update(Offset point, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final delta = point - center;
    var angle = math.atan2(delta.dx, -delta.dy);
    if (angle < 0) angle += math.pi * 2;
    var ratio = angle / (math.pi * 2);
    if (_progress > 0.85 && ratio < 0.15) ratio = 1;
    if (_progress < 0.15 && ratio > 0.85) ratio = 0;
    final raw = 10 + ratio * 7190;
    onChanged(((raw / 5).round() * 5).clamp(10, 7200));
  }

  static String formatInterval(int value) {
    if (value < 60) return '$value 秒';
    final minutes = value ~/ 60;
    final remaining = value % 60;
    return remaining == 0 ? '$minutes 分钟' : '$minutes 分 $remaining 秒';
  }
}

class _IntervalPainter extends CustomPainter {
  const _IntervalPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const lineWidth = 14.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - lineWidth;
    final bounds = Rect.fromCircle(center: center, radius: radius);
    final background = Paint()
      ..color = AppColors.muted
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineWidth;
    final foreground = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineWidth
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawCircle(center, radius, background)
      ..drawArc(
        bounds,
        -math.pi / 2,
        math.pi * 2 * progress,
        false,
        foreground,
      );
    final angle = -math.pi / 2 + math.pi * 2 * progress;
    final knob = Offset(
      center.dx + math.cos(angle) * radius,
      center.dy + math.sin(angle) * radius,
    );
    canvas
      ..drawCircle(knob, 12, Paint()..color = Colors.white)
      ..drawCircle(
        knob,
        10,
        Paint()
          ..color = AppColors.accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      );
  }

  @override
  bool shouldRepaint(covariant _IntervalPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
