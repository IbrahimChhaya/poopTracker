import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../ui/theme/morrow_colors.dart';

/// A small drawing of a Bristol stool form type (1–7). Decorative: the type
/// number and name always appear as text next to it.
class StoolFormIcon extends StatelessWidget {
  const StoolFormIcon({required this.type, this.size = 44, super.key});

  final int type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colour = MorrowColors.of(context).warmIcon;
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size(size, size * 0.5),
        painter: _StoolFormPainter(type, colour),
      ),
    );
  }
}

class _StoolFormPainter extends CustomPainter {
  _StoolFormPainter(this.type, this.colour);

  final int type;
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = colour;
    final w = size.width;
    final h = size.height;
    final cy = h / 2;

    void blob(double x, double y, double r) =>
        canvas.drawCircle(Offset(x * w, y * h), r * w, fill);

    void curvedLog({required double thickness, bool cracks = false}) {
      final path = Path()
        ..moveTo(0.08 * w, 0.62 * h)
        ..quadraticBezierTo(0.5 * w, 0.05 * h, 0.92 * w, 0.62 * h);
      final stroke = Paint()
        ..color = colour
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = thickness * w;
      canvas.drawPath(path, stroke);
      if (cracks) {
        final crack = Paint()
          ..color = Colors.white.withValues(alpha: 0.55)
          ..strokeWidth = 0.025 * w
          ..strokeCap = StrokeCap.round;
        for (final x in [0.3, 0.45, 0.6, 0.72]) {
          final y = 0.62 - 4 * 0.29 * (x - 0.08) * (0.92 - x) / 0.84;
          canvas.drawLine(
            Offset(x * w, (y - 0.08) * h),
            Offset((x + 0.02) * w, (y + 0.08) * h),
            crack,
          );
        }
      }
    }

    switch (type) {
      case 1:
        for (final (x, r) in [
          (0.14, 0.07),
          (0.32, 0.08),
          (0.5, 0.07),
          (0.68, 0.08),
          (0.86, 0.065),
        ]) {
          blob(x, 0.5, r);
        }
      case 2:
        for (var i = 0; i < 7; i++) {
          blob(0.16 + i * 0.113, 0.5 + (i.isEven ? -0.06 : 0.06), 0.095);
        }
      case 3:
        curvedLog(thickness: 0.17, cracks: true);
      case 4:
        curvedLog(thickness: 0.15);
      case 5:
        for (final (x, r) in [(0.2, 0.11), (0.5, 0.13), (0.8, 0.1)]) {
          blob(x, 0.52, r);
        }
      case 6:
        final rnd = math.Random(6);
        for (final (x, r) in [(0.16, 0.1), (0.44, 0.13), (0.74, 0.11)]) {
          for (var i = 0; i < 6; i++) {
            final a = i * math.pi / 3;
            blob(
              x + math.cos(a) * r * 0.5,
              0.52 + math.sin(a) * r,
              r * (0.45 + rnd.nextDouble() * 0.2),
            );
          }
        }
      default:
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(0.5 * w, cy + 0.08 * h),
            width: 0.6 * w,
            height: 0.36 * h,
          ),
          fill,
        );
        blob(0.12, 0.6, 0.025);
        blob(0.9, 0.55, 0.03);
    }
  }

  @override
  bool shouldRepaint(_StoolFormPainter old) =>
      old.type != type || old.colour != colour;
}

/// The rounded tile with a drawing and "TYPE 4" used in journal and
/// History cards (3.4, 4.3).
class StoolFormTile extends StatelessWidget {
  const StoolFormTile({required this.type, super.key});

  final int type;

  @override
  Widget build(BuildContext context) {
    final colors = MorrowColors.of(context);
    return Container(
      width: 58,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: colors.sand,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          StoolFormIcon(type: type, size: 40),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'TYPE $type',
              style: Theme.of(context).textTheme.labelSmall!.copyWith(
                color: colors.warmText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
