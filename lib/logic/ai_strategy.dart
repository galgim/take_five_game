import '../models/take_card.dart';
import '../models/game_row.dart';

class AiStrategy {
  // Returns the row index where [card] should be placed, or -1 if none qualify.
  static int targetRowIndex(TakeCard card, List<GameRow> rows) {
    int best = -1;
    int bestTop = -1;
    for (int i = 0; i < rows.length; i++) {
      final top = rows[i].topCard.number;
      if (top < card.number && top > bestTop) {
        bestTop = top;
        best = i;
      }
    }
    return best;
  }

  static TakeCard chooseCard(List<TakeCard> hand, List<GameRow> rows) {
    TakeCard? best;
    int bestScore = 999999;

    for (final card in hand) {
      final idx = targetRowIndex(card, rows);
      int score;
      if (idx == -1) {
        // Will need to take a row — cost = cheapest row's bulls
        final minBulls =
            rows.map((r) => r.totalBulls).reduce((a, b) => a < b ? a : b);
        score = 1000 + minBulls;
      } else {
        final row = rows[idx];
        if (row.isFull) {
          // Will trigger 6th-card rule — pay that row's bulls
          score = 500 + row.totalBulls;
        } else {
          // Safe placement — prefer rows with fewer existing cards
          score = card.bulls + row.size * 10;
        }
      }
      if (score < bestScore) {
        bestScore = score;
        best = card;
      }
    }
    return best ?? hand.first;
  }

  static int chooseBestRow(List<GameRow> rows) {
    int bestIdx = 0;
    int minBulls = rows[0].totalBulls;
    for (int i = 1; i < rows.length; i++) {
      if (rows[i].totalBulls < minBulls) {
        minBulls = rows[i].totalBulls;
        bestIdx = i;
      }
    }
    return bestIdx;
  }
}
