import 'package:flutter/material.dart';

/// Per-star-count styling for a card. The card face itself comes from
/// `assets/Card <stars>.svg`; only the overlaid number is styled here.
class StarTier {
  final Color numberColor;

  const StarTier({required this.numberColor});
}

const Map<int, StarTier> starTiers = {
  1: StarTier(numberColor: Colors.black87),
  2: StarTier(numberColor: Colors.black87),
  3: StarTier(numberColor: Colors.black87),
  5: StarTier(numberColor: Colors.white),
  7: StarTier(numberColor: Colors.white),
};

StarTier tierFor(int stars) => starTiers[stars] ?? starTiers[1]!;
