import 'package:flutter/foundation.dart';
import '../models/take_card.dart';
import '../models/game_row.dart';
import '../models/take_player.dart';
import '../logic/deck.dart';
import '../logic/ai_strategy.dart';

typedef _Placement = ({TakePlayer player, TakeCard card});

class GameState extends ChangeNotifier {
  late List<TakePlayer> players;
  late List<GameRow> rows;
  int round = 0;
  bool gameOver = false;
  String gameLog = '';

  TakeCard? selectedCard;

  bool revealPhase = false;
  List<_Placement> _placements = [];
  int _placementIdx = 0;

  bool choosingRow = false;
  TakeCard? _pendingHumanCard;

  // UI feedback for the currently-resolving placement
  TakePlayer? lastPlacingPlayer;
  TakeCard? lastPlacedCard;
  int? lastAffectedRow;
  bool lastWasTake = false;

  bool _disposed = false;
  bool _paused = false;
  void Function()? _pendingAction;

  TakePlayer get human => players[0];
  List<TakePlayer> get aiPlayers => players.sublist(1);

  List<TakePlayer> get sortedByBulls {
    final sorted = [...players];
    sorted.sort((a, b) => a.totalBulls.compareTo(b.totalBulls));
    return sorted;
  }

  void startGame(int playerCount, String playerName) {
    final deck = Deck.createShuffled();

    players = [
      TakePlayer(name: playerName, isHuman: true),
      for (int i = 1; i < playerCount; i++) TakePlayer(name: 'AI $i', isHuman: false),
    ];

    for (final p in players) {
      p.hand = deck.sublist(0, 10).toList();
      deck.removeRange(0, 10);
    }

    rows = List.generate(4, (i) => GameRow([deck[i]]));

    round = 1;
    gameOver = false;
    revealPhase = false;
    choosingRow = false;
    selectedCard = null;
    _clearFeedback();
    gameLog = 'Round $round — pick a card to play.';
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
    Future.delayed(d, () {
      if (_disposed) return;
      if (_paused) {
        _pendingAction = fn;
        return;
      }
      fn();
    });
  }

  void _clearFeedback() {
    lastPlacingPlayer = null;
    lastPlacedCard = null;
    lastAffectedRow = null;
    lastWasTake = false;
  }

  void selectCard(TakeCard card) {
    if (revealPhase || choosingRow || gameOver) return;
    selectedCard = card;
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
    gameLog = 'Cards revealed — lowest plays first.';
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
    lastPlacedCard = card;

    final rowIdx = AiStrategy.targetRowIndex(card, rows);

    if (rowIdx == -1) {
      if (player.isHuman) {
        _pendingHumanCard = card;
        choosingRow = true;
        gameLog = '${card.number} is lower than all rows — choose a row to take!';
        notifyListeners();
      } else {
        final chosen = AiStrategy.chooseBestRow(rows);
        final bulls = rows[chosen].totalBulls;
        _takeRow(player, chosen, card);
        gameLog = '${player.name} plays ${card.number} — takes Row ${chosen + 1} ($bulls bulls).';
        notifyListeners();
        _delayed(const Duration(milliseconds: 900), () {
          _placementIdx++;
          _processNextPlacement();
        });
      }
    } else if (rows[rowIdx].isFull) {
      final bulls = rows[rowIdx].totalBulls;
      _takeRow(player, rowIdx, card);
      final who = player.isHuman ? 'You place' : '${player.name} places';
      gameLog = '$who ${card.number} — takes Row ${rowIdx + 1} ($bulls bulls)!';
      notifyListeners();
      _delayed(const Duration(milliseconds: 900), () {
        _placementIdx++;
        _processNextPlacement();
      });
    } else {
      rows[rowIdx] = rows[rowIdx].withCard(card);
      lastAffectedRow = rowIdx;
      lastWasTake = false;
      final who = player.isHuman ? 'You play' : '${player.name} plays';
      gameLog = '$who ${card.number} → Row ${rowIdx + 1}.';
      notifyListeners();
      _delayed(const Duration(milliseconds: 700), () {
        _placementIdx++;
        _processNextPlacement();
      });
    }
  }

  void _takeRow(TakePlayer player, int rowIdx, TakeCard newCard) {
    final takenBulls = rows[rowIdx].totalBulls;
    player.totalBulls += takenBulls;
    lastAffectedRow = rowIdx;
    lastWasTake = true;
    rows[rowIdx] = GameRow([newCard]);
  }

  void pickRow(int rowIdx) {
    if (!choosingRow || _pendingHumanCard == null) return;
    final card = _pendingHumanCard!;
    final bulls = rows[rowIdx].totalBulls;
    _takeRow(human, rowIdx, card);
    gameLog = 'You take Row ${rowIdx + 1} ($bulls bulls) and play ${card.number}.';
    _pendingHumanCard = null;
    choosingRow = false;
    notifyListeners();
    _delayed(const Duration(milliseconds: 900), () {
      _placementIdx++;
      _processNextPlacement();
    });
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
      final winner = sortedByBulls.first;
      gameLog = winner.isHuman
          ? 'Game over! You win with ${winner.totalBulls} bulls!'
          : 'Game over! ${winner.name} wins with ${winner.totalBulls} bulls.';
    } else {
      round++;
      gameLog = 'Round $round — pick a card to play.';
    }
    notifyListeners();
  }
}
