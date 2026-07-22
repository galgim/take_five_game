import 'take_card.dart';

class GameRow {
  final List<TakeCard> cards;

  const GameRow(this.cards);

  TakeCard get topCard => cards.last;
  int get size => cards.length;
  int get totalStars => cards.fold(0, (s, c) => s + c.stars);
  bool get isFull => cards.length >= 5;

  GameRow withCard(TakeCard c) => GameRow([...cards, c]);
}
