import 'package:flutter/material.dart';

/// Per-bull-count styling for a card. The card face itself comes from
/// `assets/Card <bulls>.svg`; only the overlaid number is styled here.
class FishTier {
  final Color numberColor;

  const FishTier({required this.numberColor});
}

const Map<int, FishTier> fishTiers = {
  1: FishTier(numberColor: Colors.black87),
  2: FishTier(numberColor: Colors.black87),
  3: FishTier(numberColor: Colors.black87),
  5: FishTier(numberColor: Colors.white),
  7: FishTier(numberColor: Colors.white),
};

FishTier tierFor(int bulls) => fishTiers[bulls] ?? fishTiers[1]!;
