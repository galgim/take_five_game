import 'package:flutter/material.dart';

/// A tier is keyed by the card's bull/fish point value (1, 2, 3, 5, or 7),
/// mirroring the game's existing penalty-point rules.
class FishTier {
  final Color backgroundColor;
  final Color numberColor;
  final Color fishColor;
  final int fishCount;

  const FishTier({
    required this.backgroundColor,
    required this.numberColor,
    required this.fishColor,
    required this.fishCount,
  });
}

const Map<int, FishTier> fishTiers = {
  1: FishTier(
    backgroundColor: Colors.white,
    numberColor: Colors.black87,
    fishColor: Colors.black87,
    fishCount: 1,
  ),
  2: FishTier(
    backgroundColor: Color(0xFFE0E0E0),
    numberColor: Colors.black87,
    fishColor: Colors.black87,
    fishCount: 2,
  ),
  3: FishTier(
    backgroundColor: Color(0xFF6C84C6),
    numberColor: Colors.black87,
    fishColor: Colors.black87,
    fishCount: 3,
  ),
  5: FishTier(
    backgroundColor: Color(0xFF3457A6),
    numberColor: Colors.white,
    fishColor: Colors.white70,
    fishCount: 5,
  ),
  7: FishTier(
    backgroundColor: Color(0xFF1B3766),
    numberColor: Colors.white,
    fishColor: Colors.white60,
    fishCount: 7,
  ),
};

FishTier tierFor(int bulls) => fishTiers[bulls] ?? fishTiers[1]!;

/// A minimalist outlined fish glyph, similar to the reference card art.
class FishIconPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const FishIconPainter({required this.color, this.strokeWidth = 1.2});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    final body = Path()..moveTo(0, h * 0.5);
    body.quadraticBezierTo(w * 0.38, 0, w * 0.72, h * 0.5);
    body.quadraticBezierTo(w * 0.38, h, 0, h * 0.5);
    canvas.drawPath(body, paint);

    final tail = Path()
      ..moveTo(w * 0.7, h * 0.5)
      ..lineTo(w, h * 0.12)
      ..moveTo(w * 0.7, h * 0.5)
      ..lineTo(w, h * 0.88);
    canvas.drawPath(tail, paint);
  }

  @override
  bool shouldRepaint(FishIconPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

/// Small inline fish glyph for use next to point totals (replaces the old ▲).
class FishGlyph extends StatelessWidget {
  final double size;
  final Color color;

  const FishGlyph({super.key, this.size = 11, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 1.4,
      height: size,
      child: CustomPaint(painter: FishIconPainter(color: color, strokeWidth: size * 0.14)),
    );
  }
}

/// Full card-face background: flat tier color + a cluster of fish icons along the bottom.
class FishCardBackground extends StatelessWidget {
  final int bulls;
  final double width;
  final double height;
  final double borderRadius;

  const FishCardBackground({
    super.key,
    required this.bulls,
    required this.width,
    required this.height,
    this.borderRadius = 6,
  });

  List<Offset> _fishPositions(int count, double w, double stripTop, double stripHeight) {
    final rows = count <= 3 ? [count] : (count <= 5 ? [2, count - 2] : [3, count - 3]);
    final positions = <Offset>[];
    final rowHeight = stripHeight / rows.length;
    for (var r = 0; r < rows.length; r++) {
      final n = rows[r];
      final rowY = stripTop + rowHeight * (r + 0.5);
      for (var c = 0; c < n; c++) {
        final colX = w * (c + 1) / (n + 1);
        positions.add(Offset(colX, rowY));
      }
    }
    return positions;
  }

  @override
  Widget build(BuildContext context) {
    final tier = tierFor(bulls);
    final fishSize = width * 0.15;
    final stripHeight = height * (tier.fishCount > 3 ? 0.34 : 0.2);
    final stripTop = height - stripHeight;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          children: [
            Positioned.fill(child: Container(color: tier.backgroundColor)),
            for (final pos in _fishPositions(tier.fishCount, width, stripTop, stripHeight))
              Positioned(
                left: pos.dx - fishSize * 0.7,
                top: pos.dy - fishSize * 0.5,
                child: FishGlyph(size: fishSize, color: tier.fishColor),
              ),
          ],
        ),
      ),
    );
  }
}
