import 'take_card.dart';

class GameRow {
  final List<TakeCard> cards;

  const GameRow(this.cards);

  TakeCard get topCard => cards.last;
  int get size => cards.length;
  int get totalBulls => cards.fold(0, (s, c) => s + c.bulls);
  bool get isFull => cards.length >= 5;

  GameRow withCard(TakeCard c) => GameRow([...cards, c]);
  GameRow resetWith(TakeCard c) => GameRow([c]);
}
