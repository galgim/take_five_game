import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../game/game_state.dart';
import '../models/take_card.dart';
import '../models/game_row.dart';
import '../models/take_player.dart';
import '../widgets/app_button.dart';
import '../widgets/fish_card_design.dart';
import 'menu_screen.dart';

class GameScreen extends StatefulWidget {
  final int playerCount;
  final String playerName;

  const GameScreen({
    super.key,
    required this.playerCount,
    required this.playerName,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final GameState _gs;

  // Measured to fly a card from a player's sidebar slot into a row slot.
  late final List<GlobalKey> _sidebarKeys =
      List.generate(widget.playerCount, (_) => GlobalKey());
  final List<List<GlobalKey>> _slotKeys =
      List.generate(4, (_) => List.generate(5, (_) => GlobalKey()));

  bool _flightInProgress = false;
  bool _takeInProgress = false;
  TakePlayer? _hiddenSidebarPlayer; // source card, hidden while its copy flies
  int? _takingRowHidden; // row whose cards are hidden while the pile flies

  static const _flightDuration = Duration(milliseconds: 450);
  static const _takePileDuration = Duration(milliseconds: 1400);

  @override
  void initState() {
    super.initState();
    _gs = GameState();
    _gs.startGame(widget.playerCount, widget.playerName);
    _gs.addListener(_rebuild);
  }

  void _rebuild() {
    setState(() {});
    // A row take runs first (pile flies to the taker); committing it stages the
    // new card's flight, which this same method then picks up on a later notify.
    final t = _gs.rowTake;
    if (t != null && !_takeInProgress) {
      _takeInProgress = true;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _runRowTake(t, _gs.generation));
      return;
    }
    final f = _gs.flight;
    if (f != null && !_flightInProgress) {
      _flightInProgress = true;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _runFlight(f, _gs.generation));
    }
  }

  Future<void> _runRowTake(RowTake t, int gen) async {
    if (!mounted) return;
    final fromRects = [
      for (var i = 0; i < t.takenCards.length; i++)
        _rectFor(_slotKeys[t.rowIdx][i]),
    ];
    final sidebarRect = _rectFor(_sidebarKeys[_gs.players.indexOf(t.player)]);

    if (sidebarRect != null && fromRects.every((r) => r != null)) {
      final entry = OverlayEntry(
        builder: (_) => _TakePile(
          cards: t.takenCards,
          fromRects: [for (final r in fromRects) r!],
          pileRect: fromRects[0]!,
          sidebarRect: sidebarRect,
          duration: _takePileDuration,
        ),
      );
      Overlay.of(context).insert(entry);
      setState(() => _takingRowHidden = t.rowIdx);
      await Future.delayed(_takePileDuration);
      if (!mounted) {
        entry.remove();
        return;
      }
      _takingRowHidden = null;
      _takeInProgress = false;
      _gs.commitRowTake(gen); // empties row + stages the new card's flight
      entry.remove();
    } else {
      _takingRowHidden = null;
      _takeInProgress = false;
      _gs.commitRowTake(gen);
    }
  }

  Future<void> _runFlight(CardFlight f, int gen) async {
    if (!mounted) return;
    final from = _rectFor(_sidebarKeys[_gs.players.indexOf(f.player)]);
    final to = _rectFor(_slotKeys[f.rowIdx][f.slotIdx]);

    if (from != null && to != null) {
      final entry = OverlayEntry(
        builder: (_) => _FlyingCard(
          card: f.card,
          from: from,
          to: to,
          duration: _flightDuration,
        ),
      );
      Overlay.of(context).insert(entry);
      setState(() => _hiddenSidebarPlayer = f.player);
      await Future.delayed(_flightDuration);
      if (!mounted) {
        entry.remove();
        return;
      }
      // Commit first so the row card is painted, then drop the overlay — the
      // two coincide at the destination, so there's no blank frame.
      _hiddenSidebarPlayer = null;
      _flightInProgress = false;
      _gs.commitFlight(gen);
      entry.remove();
    } else {
      // Couldn't measure (e.g. keys not laid out) — place without animating.
      _hiddenSidebarPlayer = null;
      _flightInProgress = false;
      _gs.commitFlight(gen);
    }
  }

  Rect? _rectFor(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  void dispose() {
    _gs.removeListener(_rebuild);
    _gs.dispose();
    super.dispose();
  }

  void _openMenu() {
    _gs.pause();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'MENU',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.5),
              ),
              const SizedBox(height: 20),
              _DialogButton(
                label: 'ABANDON GAME',
                filled: true,
                onTap: () {
                  Navigator.pop(context);
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const MenuScreen()),
                    );
                  }
                },
              ),
              const SizedBox(height: 10),
              _DialogButton(
                label: 'RESUME',
                filled: false,
                onTap: () {
                  Navigator.pop(context);
                  _gs.resume();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSelecting = !_gs.revealPhase && !_gs.choosingRow && !_gs.gameOver;
    final showSelections = _gs.revealPhase || _gs.choosingRow;

    return Scaffold(
      backgroundColor: const Color(0xFF1B4332),
      body: Stack(
        children: [
          // Isolated so game-state rebuilds don't drag the full-screen SVG
          // into the repaint path.
          Positioned.fill(
            child: RepaintBoundary(
              child: SvgPicture.asset('assets/Group 1.svg', fit: BoxFit.cover),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _GearButton(onTap: _openMenu),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 27),
                          child: _PlayerSidebar(
                            players: _gs.players,
                            currentPlayer: _gs.lastPlacingPlayer,
                            showSelections: showSelections,
                            cardKeys: _sidebarKeys,
                            hiddenPlayer: _hiddenSidebarPlayer,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: _TableGrid(
                                  rows: _gs.rows,
                                  lastAffectedRow: _gs.lastAffectedRow,
                                  lastWasTake: _gs.lastWasTake,
                                  choosingRow: _gs.choosingRow,
                                  onPickRow: _gs.pickRow,
                                  slotKeys: _slotKeys,
                                  hiddenRow: _takingRowHidden,
                                ),
                              ),
                              const SizedBox(height: 6),
                              _BottomBar(
                                hand: _gs.human.hand,
                                selectedCard: _gs.selectedCard,
                                interactive: isSelecting,
                                onSelectCard: _gs.selectCard,
                                onConfirm: isSelecting && _gs.selectedCard != null
                                    ? _gs.confirmSelection
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_gs.gameOver)
            _GameOverOverlay(
              players: _gs.sortedByBulls,
              onPlayAgain: () => _gs.reset(widget.playerCount, widget.playerName),
              onMenu: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const MenuScreen()),
                  );
                }
              },
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════
// PLAYER SIDEBAR (scores + selected cards)
// ═══════════════════════════════════════════

class _PlayerSidebar extends StatelessWidget {
  final List<TakePlayer> players;
  final TakePlayer? currentPlayer;
  final bool showSelections;
  final List<GlobalKey> cardKeys;
  final TakePlayer? hiddenPlayer;

  const _PlayerSidebar({
    required this.players,
    required this.currentPlayer,
    required this.showSelections,
    required this.cardKeys,
    required this.hiddenPlayer,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, p) in players.indexed)
            _PlayerSidebarRow(
              player: p,
              showCard: showSelections,
              isCurrent: p == currentPlayer,
              cardKey: cardKeys[i],
              hideCard: p == hiddenPlayer,
            ),
        ],
      ),
    );
  }
}

class _PlayerSidebarRow extends StatelessWidget {
  final TakePlayer player;
  final bool showCard;
  final bool isCurrent;
  final GlobalKey cardKey;
  final bool hideCard;

  const _PlayerSidebarRow({
    required this.player,
    required this.showCard,
    required this.isCurrent,
    required this.cardKey,
    required this.hideCard,
  });

  @override
  Widget build(BuildContext context) {
    final selected = player.selectedCard;
    // Any accrued penalty shows red; only a clean 0 keeps the normal color.
    final scoreColor = player.totalBulls > 0
        ? Colors.redAccent
        : (player.isHuman ? const Color(0xFFFFC107) : Colors.white54);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: player.isHuman
            ? const Color(0xFFFFC107).withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  player.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: player.isHuman ? const Color(0xFFFFC107) : Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 250),
                      style: TextStyle(
                        color: scoreColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      child: Text('${player.totalBulls}'),
                    ),
                    const SizedBox(width: 3),
                    SvgPicture.asset(
                      'assets/Star.svg',
                      width: 9,
                      height: 9,
                      colorFilter: ColorFilter.mode(scoreColor, BlendMode.srcIn),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            key: cardKey,
            width: 28,
            height: 39,
            child: (showCard && selected != null && !hideCard)
                ? TakeCardWidget(
                    card: selected,
                    width: 28,
                    height: 39,
                    highlighted: isCurrent,
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════
// TABLE GRID (4 rows arranged 2x2)
// ═══════════════════════════════════════════

class _TableGrid extends StatelessWidget {
  final List<GameRow> rows;
  final int? lastAffectedRow;
  final bool lastWasTake;
  final bool choosingRow;
  final void Function(int) onPickRow;
  final List<List<GlobalKey>> slotKeys;
  final int? hiddenRow;

  const _TableGrid({
    required this.rows,
    required this.lastAffectedRow,
    required this.lastWasTake,
    required this.choosingRow,
    required this.onPickRow,
    required this.slotKeys,
    required this.hiddenRow,
  });

  Widget _cell(int i, Alignment alignment) {
    final isAffected = lastAffectedRow == i;
    return GestureDetector(
      onTap: choosingRow ? () => onPickRow(i) : null,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const bullsW = 30.0;
          const hPad = 8.0;
          const cardGap = 1.5;
          const vPad = 6.0;
          const aspect = 50.0 / 70.0;
          const safetyMargin = 6.0;
          const maxCardW = 50.0;

          final overhead = bullsW + hPad + cardGap * 4 + safetyMargin;
          final maxCardWByWidth = (constraints.maxWidth - overhead) / 5;
          final maxCardHByHeight = constraints.maxHeight - vPad;
          final maxCardWByHeight = maxCardHByHeight * aspect;
          var cardW = maxCardWByWidth < maxCardWByHeight ? maxCardWByWidth : maxCardWByHeight;
          if (cardW > maxCardW) cardW = maxCardW;
          final cardH = cardW / aspect;

          return Align(
            alignment: alignment,
            child: _GameRowWidget(
              row: rows[i],
              isAffected: isAffected,
              wasTake: isAffected && lastWasTake,
              choosingRow: choosingRow,
              cardW: cardW < 0 ? 0 : cardW,
              cardH: cardH < 0 ? 0 : cardH,
              slotKeys: slotKeys[i],
              hideCards: hiddenRow == i,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _cell(0, Alignment.bottomCenter)),
              const SizedBox(width: 3),
              Expanded(child: _cell(1, Alignment.bottomCenter)),
            ],
          ),
        ),
        const SizedBox(height: 3),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _cell(2, Alignment.topCenter)),
              const SizedBox(width: 3),
              Expanded(child: _cell(3, Alignment.topCenter)),
            ],
          ),
        ),
      ],
    );
  }
}

class _GameRowWidget extends StatelessWidget {
  final GameRow row;
  final bool isAffected;
  final bool wasTake;
  final bool choosingRow;
  final double cardW;
  final double cardH;
  final List<GlobalKey> slotKeys;
  final bool hideCards; // cards flying to the taker are drawn in the overlay

  const _GameRowWidget({
    required this.row,
    required this.isAffected,
    required this.wasTake,
    required this.choosingRow,
    required this.cardW,
    required this.cardH,
    required this.slotKeys,
    required this.hideCards,
  });

  @override
  Widget build(BuildContext context) {
    Color borderColor;
    Color bgColor;
    if (choosingRow) {
      borderColor = const Color(0xFFFFC107);
      bgColor = const Color(0xFFFFC107).withValues(alpha: 0.15);
    } else if (wasTake) {
      borderColor = Colors.redAccent;
      bgColor = Colors.redAccent.withValues(alpha: 0.15);
    } else if (isAffected) {
      borderColor = const Color(0xFF52B788);
      bgColor = const Color(0xFF52B788).withValues(alpha: 0.12);
    } else {
      borderColor = Colors.white.withValues(alpha: 0.15);
      bgColor = Colors.white.withValues(alpha: 0.05);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: choosingRow || isAffected ? 2 : 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (slot) {
              final padRight = slot < 4 ? 1.5 : 0.0;
              if (slot < row.cards.length && !hideCards) {
                return Padding(
                  padding: EdgeInsets.only(right: padRight),
                  child: TakeCardWidget(
                    key: slotKeys[slot],
                    card: row.cards[slot],
                    width: cardW,
                    height: cardH,
                  ),
                );
              } else {
                return Padding(
                  padding: EdgeInsets.only(right: padRight),
                  child: Container(
                    key: slotKeys[slot],
                    width: cardW,
                    height: cardH,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                  ),
                );
              }
            }),
          ),
          const SizedBox(width: 2),
          SizedBox(
            width: 30,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '${row.totalBulls}',
                  style: TextStyle(
                    color: row.isFull
                        ? Colors.redAccent
                        : Colors.white.withValues(alpha: 0.55),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 2),
                SvgPicture.asset(
                  'assets/Star.svg',
                  width: 8,
                  height: 8,
                  colorFilter: ColorFilter.mode(
                    row.isFull ? Colors.redAccent : Colors.white.withValues(alpha: 0.55),
                    BlendMode.srcIn,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════
// BOTTOM BAR (hand + confirm button)
// ═══════════════════════════════════════════

class _BottomBar extends StatelessWidget {
  final List<TakeCard> hand;
  final TakeCard? selectedCard;
  final bool interactive;
  final void Function(TakeCard) onSelectCard;
  final VoidCallback? onConfirm;

  const _BottomBar({
    required this.hand,
    required this.selectedCard,
    required this.interactive,
    required this.onSelectCard,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: _PlayerHand(
            hand: hand,
            selectedCard: selectedCard,
            interactive: interactive,
            onSelectCard: onSelectCard,
          ),
        ),
        SizedBox(
          width: 100,
          child: AppButton(
            label: selectedCard != null ? 'CONFIRM' : 'SELECT',
            onTap: onConfirm,
            backgroundColor: const Color(0xFF52B788),
            textColor: Colors.white,
            borderColor: const Color(0xFF2D6A4F),
            verticalPadding: 12,
            horizontalPadding: 10,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════
// PLAYER HAND
// ═══════════════════════════════════════════

class _PlayerHand extends StatelessWidget {
  final List<TakeCard> hand;
  final TakeCard? selectedCard;
  final bool interactive;
  final void Function(TakeCard) onSelectCard;

  const _PlayerHand({
    required this.hand,
    required this.selectedCard,
    required this.interactive,
    required this.onSelectCard,
  });

  @override
  Widget build(BuildContext context) {
    // `hand` is kept sorted by GameState.startGame, so no copy/sort here.
    const cardW = 70.0;
    const cardH = 98.0;
    const minStep = 19.0;
    const hPad = 8.0;

    final selectedIndex = selectedCard == null ? -1 : hand.indexOf(selectedCard!);
    final order = List<int>.generate(hand.length, (i) => i);
    if (selectedIndex != -1) {
      order
        ..remove(selectedIndex)
        ..add(selectedIndex);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableW = constraints.maxWidth - hPad * 2;
        final n = hand.length;

        double step;
        if (n <= 1) {
          step = cardW;
        } else {
          step = (availableW - cardW) / (n - 1);
          if (step > cardW) step = cardW;
          if (step < minStep) step = minStep;
        }

        final stackWidth = n == 0 ? 0.0 : (n - 1) * step + cardW;
        final leftOffset = hPad + ((availableW - stackWidth) / 2).clamp(0.0, double.infinity);

        return SizedBox(
          height: cardH + 10,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final i in order)
                Positioned(
                  key: ValueKey(hand[i].number),
                  left: leftOffset + i * step,
                  top: 5,
                  child: GestureDetector(
                    onTap: interactive ? () => onSelectCard(hand[i]) : null,
                    child: AnimatedSlide(
                      offset: hand[i] == selectedCard
                          ? const Offset(0, -0.3)
                          : Offset.zero,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      child: TakeCardWidget(
                        card: hand[i],
                        width: cardW,
                        height: cardH,
                        dimmed: !interactive,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════
// CARD WIDGET
// ═══════════════════════════════════════════

class TakeCardWidget extends StatelessWidget {
  final TakeCard card;
  final double width;
  final double height;
  final bool highlighted;
  final bool dimmed;

  const TakeCardWidget({
    super.key,
    required this.card,
    required this.width,
    required this.height,
    this.highlighted = false,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = tierFor(card.bulls).numberColor;
    final dimColor = dimmed ? Colors.black.withValues(alpha: 0.35) : Colors.transparent;

    return Stack(
      children: [
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: highlighted
                  ? const Color(0xFFE65100)
                  : Colors.black.withValues(alpha: 0.25),
              width: highlighted ? 2 : 1,
            ),
            boxShadow: highlighted
                ? [const BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2))]
                : null,
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SvgPicture.asset(
                    'assets/Card ${card.bulls}.svg',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                top: width * 0.08,
                left: width * 0.1,
                child: Text(
                  '${card.number}',
                  style: TextStyle(
                    fontSize: width * 0.28,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                    height: 1,
                    // Without this the number picks up the yellow double
                    // underline when rendered in an Overlay (no Material
                    // ancestor supplies a default), i.e. the flying cards.
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (dimmed)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: dimColor,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════
// FLYING CARD (sidebar → row slot, in an Overlay)
// ═══════════════════════════════════════════

class _FlyingCard extends StatefulWidget {
  final TakeCard card;
  final Rect from;
  final Rect to;
  final Duration duration;

  const _FlyingCard({
    required this.card,
    required this.from,
    required this.to,
    required this.duration,
  });

  @override
  State<_FlyingCard> createState() => _FlyingCardState();
}

class _FlyingCardState extends State<_FlyingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration)..forward();
  late final Animation<Rect?> _rect = RectTween(
    begin: widget.from,
    end: widget.to,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _rect,
      builder: (context, _) {
        // Tweening the whole rect scales the card as it travels; the number
        // font tracks width inside TakeCardWidget, so it scales for free.
        final r = _rect.value!;
        return Positioned.fromRect(
          rect: r,
          child: TakeCardWidget(
            card: widget.card,
            width: r.width,
            height: r.height,
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════
// TAKE PILE (row cards → consolidate → fly to taker, in an Overlay)
// ═══════════════════════════════════════════

class _TakePile extends StatefulWidget {
  final List<TakeCard> cards;
  final List<Rect> fromRects; // each card's current row-slot rect
  final Rect pileRect; // where the cards stack up (slot 0)
  final Rect sidebarRect; // the taker's sidebar card slot
  final Duration duration;

  const _TakePile({
    required this.cards,
    required this.fromRects,
    required this.pileRect,
    required this.sidebarRect,
    required this.duration,
  });

  @override
  State<_TakePile> createState() => _TakePileState();
}

class _TakePileState extends State<_TakePile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration)..forward();

  // Fraction of the run spent gathering the cards into a stack before the whole
  // pile flies to the taker. Kept small so most of the (now slower) run is the
  // flight to the sidebar, where the penalty is registering.
  static const _gatherEnd = 0.35;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Small per-card offset so the gathered cards read as a stack, not one card.
  Offset _stackOffset(int i) => Offset(i * 1.5, -i * 1.5);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Stack(
          children: [
            for (var i = 0; i < widget.cards.length; i++) _card(i, t),
          ],
        );
      },
    );
  }

  Widget _card(int i, double t) {
    final stacked = widget.pileRect.shift(_stackOffset(i));
    Rect rect;
    double opacity = 1;
    if (t <= _gatherEnd) {
      final p = Curves.easeOut.transform(t / _gatherEnd);
      rect = Rect.lerp(widget.fromRects[i], stacked, p)!;
    } else {
      final p = Curves.easeIn.transform((t - _gatherEnd) / (1 - _gatherEnd));
      rect = Rect.lerp(stacked, widget.sidebarRect, p)!;
      opacity = 1 - p; // fade out as it reaches the taker
    }
    return Positioned.fromRect(
      rect: rect,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: TakeCardWidget(
          card: widget.cards[i],
          width: rect.width,
          height: rect.height,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
// GAME OVER OVERLAY
// ═══════════════════════════════════════════

class _GameOverOverlay extends StatelessWidget {
  final List<TakePlayer> players;
  final VoidCallback onPlayAgain;
  final VoidCallback onMenu;

  const _GameOverOverlay({
    required this.players,
    required this.onPlayAgain,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final winner = players.first;
    final playerWon = winner.isHuman;

    return Container(
      color: Colors.black.withValues(alpha: 0.78),
      child: Center(
        child: SingleChildScrollView(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 380),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  playerWon ? '🏆' : '📊',
                  style: const TextStyle(fontSize: 36),
                ),
                const SizedBox(height: 6),
                Text(
                  playerWon ? 'YOU WIN!' : '${winner.name} WINS!',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),
                ...players.asMap().entries.map((e) {
                  final rank = e.key + 1;
                  final p = e.value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Text(
                          '$rank.',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: rank == 1 ? const Color(0xFFE65100) : Colors.black54,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            p.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: p.isHuman ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                        Text(
                          '${p.totalBulls} fish',
                          style: TextStyle(
                            fontSize: 13,
                            color: rank == 1 ? const Color(0xFFE65100) : Colors.black54,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'PLAY AGAIN',
                        onTap: onPlayAgain,
                        backgroundColor: Colors.black,
                        textColor: Colors.white,
                        borderColor: Colors.black,
                        verticalPadding: 12,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppButton(
                        label: 'MENU',
                        onTap: onMenu,
                        backgroundColor: Colors.white,
                        textColor: Colors.black,
                        borderColor: Colors.black,
                        borderWidth: 1.5,
                        verticalPadding: 12,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
// GEAR / MENU BUTTON
// ═══════════════════════════════════════════

class _GearButton extends StatelessWidget {
  final VoidCallback onTap;

  const _GearButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.menu, color: Colors.white, size: 18),
      ),
    );
  }
}

// ─────────────────────────────────────────
// DIALOG BUTTON
// ─────────────────────────────────────────

class _DialogButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _DialogButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: label,
      onTap: onTap,
      backgroundColor: filled ? Colors.black : Colors.white,
      textColor: filled ? Colors.white : Colors.black,
      borderColor: Colors.black,
      borderWidth: 1.5,
      verticalPadding: 13,
      borderRadius: 10,
      fontSize: 13,
      letterSpacing: 1,
    );
  }
}

