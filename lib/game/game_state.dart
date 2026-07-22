import 'package:flutter/foundation.dart';
import '../models/take_card.dart';
import '../models/game_row.dart';
import '../models/take_player.dart';
import '../logic/deck.dart';
import '../logic/ai_strategy.dart';

typedef _Placement = ({TakePlayer player, TakeCard card});

/// A card in flight from a player's sidebar slot to a row slot. While this is
/// non-null the row is *not* yet mutated — the UI animates the card, then calls
/// [GameState.commitFlight] to apply the placement and advance.
typedef CardFlight = ({TakePlayer player, TakeCard card, int rowIdx, int slotIdx});

/// A row being taken. While non-null the row is *not* yet cleared — the UI flies
/// [takenCards] to [player], then calls [GameState.commitRowTake].
typedef RowTake = ({
  TakePlayer player,
  TakeCard newCard,
  int rowIdx,
  List<TakeCard> takenCards,
});

class GameState extends ChangeNotifier {
  late List<TakePlayer> players;
  late List<GameRow> rows;
  int round = 0;
  bool gameOver = false;

  TakeCard? selectedCard;

  bool revealPhase = false;
  List<_Placement> _placements = [];
  int _placementIdx = 0;

  bool choosingRow = false;
  TakeCard? _pendingHumanCard;

  // UI feedback for the currently-resolving placement
  TakePlayer? lastPlacingPlayer;
  int? lastAffectedRow;
  bool lastWasTake = false;

  // Non-null while a placed card is animating into its row slot.
  CardFlight? flight;

  // Non-null while a taken row's cards are animating to the taking player.
  RowTake? rowTake;

  // Bumped on every new game; delayed/flight callbacks captured under an old
  // generation become no-ops so a stale timer can't touch a fresh game.
  int generation = 0;

  bool _disposed = false;
  bool _paused = false;
  void Function()? _pendingAction;

  TakePlayer get human => players[0];
  List<TakePlayer> get aiPlayers => players.sublist(1);

  List<TakePlayer> get sortedByStars {
    final sorted = [...players];
    sorted.sort((a, b) => a.totalStars.compareTo(b.totalStars));
    return sorted;
  }

  void startGame(int playerCount, String playerName) {
    generation++;
    final deck = Deck.createShuffled();

    players = [
      TakePlayer(name: playerName, isHuman: true),
      for (int i = 1; i < playerCount; i++) TakePlayer(name: 'AI $i', isHuman: false),
    ];

    for (final p in players) {
      p.hand = deck.sublist(0, 10).toList();
      deck.removeRange(0, 10);
    }

    // Sorted once here rather than on every build; removal preserves order.
    // AI hands are left in deal order — sorting them would change how
    // AiStrategy.chooseCard breaks ties between equally-scored cards.
    human.hand.sort((a, b) => a.number.compareTo(b.number));

    rows = List.generate(4, (i) => GameRow([deck[i]]));

    round = 1;
    gameOver = false;
    revealPhase = false;
    choosingRow = false;
    selectedCard = null;
    _clearFeedback();
    notifyListeners();
  }

  void reset(int playerCount, String playerName) {
    _pendingAction = null;
    _paused = false;
    startGame(playerCount, playerName);
  }

  void pause() => _paused = true;

  void resume() {
    if (!_paused) return;
    _paused = false;
    final action = _pendingAction;
    _pendingAction = null;
    action?.call();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _delayed(Duration d, void Function() fn) {
    final gen = generation;
    Future.delayed(d, () {
      if (_disposed || gen != generation) return;
      if (_paused) {
        _pendingAction = fn;
        return;
      }
      fn();
    });
  }

  void _clearFeedback() {
    lastPlacingPlayer = null;
    lastAffectedRow = null;
    lastWasTake = false;
    flight = null;
    rowTake = null;
  }

  void selectCard(TakeCard card) {
    if (revealPhase || choosingRow || gameOver) return;
    selectedCard = selectedCard == card ? null : card;
    notifyListeners();
  }

  void confirmSelection() {
    if (selectedCard == null || revealPhase || choosingRow || gameOver) return;

    human.hand.remove(selectedCard);
    human.selectedCard = selectedCard;

    for (final ai in aiPlayers) {
      ai.selectedCard = AiStrategy.chooseCard(ai.hand, rows);
      ai.hand.remove(ai.selectedCard);
    }

    _placements = players
        .map((p) => (player: p, card: p.selectedCard!))
        .toList()
      ..sort((a, b) => a.card.number.compareTo(b.card.number));
    _placementIdx = 0;
    selectedCard = null;
    revealPhase = true;
    notifyListeners();

    _delayed(const Duration(milliseconds: 1400), _processNextPlacement);
  }

  void _processNextPlacement() {
    if (_placementIdx >= _placements.length) {
      _endRound();
      return;
    }

    final placement = _placements[_placementIdx];
    final player = placement.player;
    final card = placement.card;
    lastPlacingPlayer = player;

    final rowIdx = AiStrategy.targetRowIndex(card, rows);

    if (rowIdx == -1) {
      if (player.isHuman) {
        _pendingHumanCard = card;
        choosingRow = true;
        notifyListeners();
      } else {
        _announceTake(player, AiStrategy.chooseBestRow(rows), card);
      }
    } else if (rows[rowIdx].isFull) {
      _announceTake(player, rowIdx, card);
    } else {
      // Announce the flight; the UI animates the card and calls commitFlight,
      // which is what actually adds it to the row and advances the queue.
      lastAffectedRow = rowIdx;
      lastWasTake = false;
      flight = (player: player, card: card, rowIdx: rowIdx, slotIdx: rows[rowIdx].size);
      notifyListeners();
    }
  }

  /// Applies the pending [flight] (called by the UI when the card lands) and
  /// schedules the next placement. Ignored if the game moved on ([gen] stale)
  /// or was disposed.
  void commitFlight(int gen) {
    if (_disposed || gen != generation) return;
    final f = flight;
    if (f == null) return;
    flight = null;
    f.player.selectedCard = null; // the card has left the sidebar
    rows[f.rowIdx] = rows[f.rowIdx].withCard(f.card);
    lastAffectedRow = f.rowIdx;
    lastWasTake = false;
    notifyListeners();
    _delayed(const Duration(milliseconds: 350), () {
      _placementIdx++;
      _processNextPlacement();
    });
  }

  /// Announces a row take. Nothing is mutated yet: the UI flies the row's cards
  /// to [player] (via the pile animation), calls [commitRowTake] when they land,
  /// and that in turn stages [newCard]'s slide-in as a normal placement flight.
  void _announceTake(TakePlayer player, int rowIdx, TakeCard newCard) {
    lastPlacingPlayer = player;
    lastAffectedRow = rowIdx;
    lastWasTake = true;
    rowTake = (
      player: player,
      newCard: newCard,
      rowIdx: rowIdx,
      takenCards: List.of(rows[rowIdx].cards),
    );
    notifyListeners();
  }

  /// Applies the pending [rowTake] (called by the UI when the pile lands on the
  /// taker): credits the stars, empties the row, and stages the new card's
  /// flight into the now-empty slot 0.
  void commitRowTake(int gen) {
    if (_disposed || gen != generation) return;
    final t = rowTake;
    if (t == null) return;
    rowTake = null;
    t.player.totalStars += rows[t.rowIdx].totalStars;
    rows[t.rowIdx] = GameRow(const []); // emptied; new card flies in next
    lastAffectedRow = t.rowIdx;
    lastWasTake = true;
    flight = (player: t.player, card: t.newCard, rowIdx: t.rowIdx, slotIdx: 0);
    notifyListeners();
  }

  void pickRow(int rowIdx) {
    if (!choosingRow || _pendingHumanCard == null) return;
    final card = _pendingHumanCard!;
    _pendingHumanCard = null;
    choosingRow = false;
    _announceTake(human, rowIdx, card);
  }

  void _endRound() {
    for (final p in players) {
      p.selectedCard = null;
    }
    selectedCard = null;
    revealPhase = false;
    _clearFeedback();

    if (human.hand.isEmpty) {
      gameOver = true;
    } else {
      round++;
    }
    notifyListeners();
  }
}
