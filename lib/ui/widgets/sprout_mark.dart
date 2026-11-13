import 'package:flutter/widgets.dart';

/// The morrow mark: the sprout from the launcher icon (Figma "icon/sprout",
/// a 24-unit glyph drawn with a round 1.66-unit stroke). Decorative, so it
/// has no semantics of its own; the text beside it carries the meaning.
///
/// Keep in step with tool/generate_launcher_icons.py and
/// android/app/src/main/res/drawable/ic_launcher_foreground.xml.
class SproutMark extends StatelessWidget {
  const SproutMark({required this.color, this.size = 24, super.key});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _SproutPainter(color)),
      ),
    );
  }
}

class _SproutPainter extends CustomPainter {
  const _SproutPainter(this.color);

  final Color color;

  static const _stroke = 1.6615;

  static final Path _glyph = Path()
    // Stem.
    ..moveTo(12, 21)
    ..lineTo(12, 12)
    // Right leaf.
    ..cubicTo(12, 8, 15, 6, 19, 6)
    ..cubicTo(19, 10, 16, 12, 12, 12)
    ..close()
    // Left leaf.
    ..moveTo(12, 14)
    ..cubicTo(12, 11, 10, 9, 6, 9)
    ..cubicTo(6, 12, 8, 14, 12, 14)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 24;
    canvas
      ..save()
      ..translate((size.width - 24 * scale) / 2, (size.height - 24 * scale) / 2)
      ..scale(scale);
    canvas.drawPath(
      _glyph,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SproutPainter oldDelegate) => oldDelegate.color != color;
}
