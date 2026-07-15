import '../models/take_card.dart';

class Deck {
  static List<TakeCard> createShuffled() {
    final cards = List.generate(104, (i) => TakeCard.fromNumber(i + 1));
    cards.shuffle();
    return cards;
  }
}
