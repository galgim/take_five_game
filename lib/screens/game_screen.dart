import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _gs = GameState();
    _gs.startGame(widget.playerCount, widget.playerName);
    _gs.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

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
          Positioned.fill(
            child: CustomPaint(painter: _CrosshatchPainter(const Color(0xFF2D6A4F))),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.45),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.all(6),
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
                          _PlayerSidebar(
                            players: _gs.players,
                            currentPlayer: _gs.lastPlacingPlayer,
                            showSelections: showSelections,
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
                                  ),
                                ),
                                const SizedBox(height: 6),
                                _BottomBar(
                                  hand: _gs.human.hand,
                                  selectedCard: _gs.selectedCard,
                                  interactive: isSelecting,
                                  onSelectCard: _gs.selectCard,
                                  hasSelectedCard: _gs.selectedCard != null,
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
          ),
          if (_gs.gameOver)
            _GameOverOverlay(
              players: _gs.sortedByBulls,
              humanName: _gs.human.name,
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

  const _PlayerSidebar({
    required this.players,
    required this.currentPlayer,
    required this.showSelections,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: players
            .map((p) => _PlayerSidebarRow(
                  player: p,
                  showCard: showSelections,
                  isCurrent: p == currentPlayer,
                ))
            .toList(),
      ),
    );
  }
}

class _PlayerSidebarRow extends StatelessWidget {
  final TakePlayer player;
  final bool showCard;
  final bool isCurrent;

  const _PlayerSidebarRow({
    required this.player,
    required this.showCard,
    required this.isCurrent,
  });

  @override
  Widget build(BuildContext context) {
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
                    Text(
                      '${player.totalBulls}',
                      style: TextStyle(
                        color: player.isHuman ? const Color(0xFFFFC107) : Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: player.isHuman ? const Color(0xFFFFC107) : Colors.white54,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 28,
            height: 39,
            child: (showCard && player.selectedCard != null)
                ? TakeCardWidget(
                    card: player.selectedCard,
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

  const _TableGrid({
    required this.rows,
    required this.lastAffectedRow,
    required this.lastWasTake,
    required this.choosingRow,
    required this.onPickRow,
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

  const _GameRowWidget({
    required this.row,
    required this.isAffected,
    required this.wasTake,
    required this.choosingRow,
    required this.cardW,
    required this.cardH,
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
              if (slot < row.cards.length) {
                return Padding(
                  padding: EdgeInsets.only(right: padRight),
                  child: TakeCardWidget(
                    card: row.cards[slot],
                    width: cardW,
                    height: cardH,
                  ),
                );
              } else {
                return Padding(
                  padding: EdgeInsets.only(right: padRight),
                  child: Container(
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
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: row.isFull ? Colors.redAccent : Colors.white.withValues(alpha: 0.55),
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
  final bool hasSelectedCard;
  final VoidCallback? onConfirm;

  const _BottomBar({
    required this.hand,
    required this.selectedCard,
    required this.interactive,
    required this.onSelectCard,
    required this.hasSelectedCard,
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
            label: hasSelectedCard ? 'CONFIRM' : 'SELECT',
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
    final sorted = [...hand]..sort((a, b) => a.number.compareTo(b.number));
    const cardW = 70.0;
    const cardH = 98.0;
    const minStep = 19.0;
    const hPad = 8.0;

    final selectedIndex = selectedCard == null ? -1 : sorted.indexOf(selectedCard!);
    final order = List<int>.generate(sorted.length, (i) => i);
    if (selectedIndex != -1) {
      order
        ..remove(selectedIndex)
        ..add(selectedIndex);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableW = constraints.maxWidth - hPad * 2;
        final n = sorted.length;

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
                  key: ValueKey(sorted[i].number),
                  left: leftOffset + i * step,
                  top: 5,
                  child: GestureDetector(
                    onTap: interactive ? () => onSelectCard(sorted[i]) : null,
                    child: AnimatedSlide(
                      offset: sorted[i] == selectedCard
                          ? const Offset(0, -0.3)
                          : Offset.zero,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      child: TakeCardWidget(
                        card: sorted[i],
                        width: cardW,
                        height: cardH,
                        highlighted: selectedCard == sorted[i],
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
  final TakeCard? card;
  final double width;
  final double height;
  final bool highlighted;
  final bool faceDown;
  final bool dimmed;

  const TakeCardWidget({
    super.key,
    required this.card,
    required this.width,
    required this.height,
    this.highlighted = false,
    this.faceDown = false,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    if (faceDown || card == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: width,
          height: height,
          child: Image.asset('assets/2.png', fit: BoxFit.cover),
        ),
      );
    }

    final tier = tierFor(card!.bulls);
    final textColor = tier.numberColor;
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
                child: FishCardBackground(bulls: card!.bulls, width: width, height: height),
              ),
              Center(
                child: Text(
                  '${card!.number}',
                  style: TextStyle(
                    fontSize: width * 0.36,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                    height: 1,
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
// GAME OVER OVERLAY
// ═══════════════════════════════════════════

class _GameOverOverlay extends StatelessWidget {
  final List<TakePlayer> players;
  final String humanName;
  final VoidCallback onPlayAgain;
  final VoidCallback onMenu;

  const _GameOverOverlay({
    required this.players,
    required this.humanName,
    required this.onPlayAgain,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final winner = players.first;
    final playerWon = winner.name == humanName;

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

// ─────────────────────────────────────────
// CROSSHATCH BACKGROUND
// ─────────────────────────────────────────

class _CrosshatchPainter extends CustomPainter {
  final Color color;

  const _CrosshatchPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.7
      ..style = PaintingStyle.stroke;

    const spacing = 28.0;
    for (double a = -size.height; a <= size.width; a += spacing) {
      canvas.drawLine(Offset(a, 0), Offset(a + size.height, size.height), paint);
    }
    for (double a = 0; a <= size.width + size.height; a += spacing) {
      canvas.drawLine(Offset(a, 0), Offset(a - size.height, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_CrosshatchPainter old) => old.color != color;
}
