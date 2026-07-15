import 'take_card.dart';

class TakePlayer {
  final String name;
  final bool isHuman;
  List<TakeCard> hand;
  int totalBulls;
  TakeCard? selectedCard;

  TakePlayer({
    required this.name,
    required this.isHuman,
    List<TakeCard>? hand,
    this.totalBulls = 0,
    this.selectedCard,
  }) : hand = hand ?? [];
}
