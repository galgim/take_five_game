import 'package:flutter/material.dart';

class FishTier {
  final Color backgroundColor;
  final Color numberColor;

  const FishTier({
    required this.backgroundColor,
    required this.numberColor,
  });
}

const Map<int, FishTier> fishTiers = {
  1: FishTier(backgroundColor: Colors.white, numberColor: Colors.black87),
  2: FishTier(backgroundColor: Color(0xFFE0E0E0), numberColor: Colors.black87),
  3: FishTier(backgroundColor: Color(0xFF6C84C6), numberColor: Colors.black87),
  5: FishTier(backgroundColor: Color(0xFF3457A6), numberColor: Colors.white),
  7: FishTier(backgroundColor: Color(0xFF1B3766), numberColor: Colors.white),
};

FishTier tierFor(int bulls) => fishTiers[bulls] ?? fishTiers[1]!;
