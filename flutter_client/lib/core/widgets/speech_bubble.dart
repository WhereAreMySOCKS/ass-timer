import 'package:ass_timer_flutter/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

enum SpeechBubbleTail { left, right, bottom }

class SpeechBubble extends StatelessWidget {
  const SpeechBubble({
    required this.child,
    required this.tail,
    super.key,
    this.width,
    this.height,
    this.onTap,
    this.semanticLabel,
    this.padding = const EdgeInsets.fromLTRB(14, 12, 14, 12),
  });

  final Widget child;
  final SpeechBubbleTail tail;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    const tailExtent = 10.0;
    final outerPadding = switch (tail) {
      SpeechBubbleTail.left => const EdgeInsets.only(left: tailExtent),
      SpeechBubbleTail.right => const EdgeInsets.only(right: tailExtent),
      SpeechBubbleTail.bottom => const EdgeInsets.only(bottom: tailExtent),
    };
    final card = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border, width: 1.2),
        borderRadius: BorderRadius.circular(context.visualTokens.bubbleRadius),
        boxShadow: context.visualTokens.floatingShadow,
      ),
      child: child,
    );
    final interactive = onTap == null
        ? card
        : Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius:
                  BorderRadius.circular(context.visualTokens.bubbleRadius),
              child: card,
            ),
          );
    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      child: Padding(
        padding: outerPadding,
        child: CustomPaint(
          painter: _BubbleTailPainter(tail: tail),
          child: interactive,
        ),
      ),
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  const _BubbleTailPainter({required this.tail});

  final SpeechBubbleTail tail;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = AppColors.surface
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final path = Path();
    switch (tail) {
      case SpeechBubbleTail.left:
        path
          ..moveTo(-9, size.height * 0.62)
          ..lineTo(1, size.height * 0.55)
          ..lineTo(1, size.height * 0.70)
          ..close();
      case SpeechBubbleTail.right:
        path
          ..moveTo(size.width + 9, size.height * 0.62)
          ..lineTo(size.width - 1, size.height * 0.55)
          ..lineTo(size.width - 1, size.height * 0.70)
          ..close();
      case SpeechBubbleTail.bottom:
        path
          ..moveTo(size.width * 0.5, size.height + 9)
          ..lineTo(size.width * 0.44, size.height - 1)
          ..lineTo(size.width * 0.56, size.height - 1)
          ..close();
    }
    canvas
      ..drawPath(path, fill)
      ..drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _BubbleTailPainter oldDelegate) =>
      oldDelegate.tail != tail;
}
