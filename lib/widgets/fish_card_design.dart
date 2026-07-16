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

/// Small inline fish glyph for use next to point totals (replaces the old ▲).
/// Uses the fish-icon.png asset (a solid silhouette), tinted per tier.
class FishGlyph extends StatelessWidget {
  final double size;
  final Color color;

  const FishGlyph({super.key, this.size = 11, required this.color});

  static const double _aspect = 577 / 539;
  static double widthFor(double size) => size * _aspect;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/fish-icon.png',
      width: size * _aspect,
      height: size,
      color: color,
      colorBlendMode: BlendMode.srcIn,
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
    final fishSize = switch (tier.fishCount) {
      <= 3 => width * 0.16,
      5 => width * 0.115,
      _ => width * 0.095,
    };
    final stripHeightFraction = switch (tier.fishCount) {
      <= 3 => 0.2,
      5 => 0.36,
      _ => 0.4,
    };
    final stripHeight = height * stripHeightFraction;
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
                left: pos.dx - FishGlyph.widthFor(fishSize) / 2,
                top: pos.dy - fishSize * 0.5,
                child: FishGlyph(size: fishSize, color: tier.fishColor),
              ),
          ],
        ),
      ),
    );
  }
}
