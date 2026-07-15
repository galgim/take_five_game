import 'package:flutter/material.dart';
import '../game/game_state.dart';
import '../models/take_card.dart';
import '../models/game_row.dart';
import '../models/take_player.dart';
import '../widgets/app_button.dart';
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

    return Scaffold(
      backgroundColor: const Color(0xFF1B4332),
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _CrosshatchPainter(const Color(0xFF2D6A4F))),
          ),
          SafeArea(
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TopBar(
                      players: _gs.players,
                      onMenu: _openMenu,
                    ),
                    if (_gs.revealPhase || _gs.choosingRow)
                      _SelectionsRow(
                        players: _gs.players,
                        currentCard: _gs.lastPlacedCard,
                        currentPlayer: _gs.lastPlacingPlayer,
                      ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: _TableArea(
                          rows: _gs.rows,
                          lastAffectedRow: _gs.lastAffectedRow,
                          lastWasTake: _gs.lastWasTake,
                          choosingRow: _gs.choosingRow,
                          onPickRow: _gs.pickRow,
                        ),
                      ),
                    ),
                    _PlayerHand(
                      hand: _gs.human.hand,
                      selectedCard: _gs.selectedCard,
                      interactive: isSelecting,
                      onSelectCard: _gs.selectCard,
                    ),
                    if (isSelecting)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        child: AppButton(
                          label: _gs.selectedCard == null ? 'SELECT A CARD' : 'CONFIRM',
                          onTap: _gs.selectedCard != null ? _gs.confirmSelection : null,
                          backgroundColor: const Color(0xFFFFC107),
                          textColor: Colors.black,
                          borderColor: const Color(0xFFE65100),
                          verticalPadding: 14,
                          fontSize: 15,
                        ),
                      )
                    else
                      const SizedBox(height: 12),
                  ],
                ),
                Positioned(
                  top: 4,
                  right: 8,
                  child: _GearButton(onTap: _openMenu),
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
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════
// TOP BAR
// ═══════════════════════════════════════════

class _TopBar extends StatelessWidget {
  final List<TakePlayer> players;
  final VoidCallback onMenu;

  const _TopBar({required this.players, required this.onMenu});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 48, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: players.map((p) => _PlayerScore(player: p)).toList(),
        ),
      ),
    );
  }
}

class _PlayerScore extends StatelessWidget {
  final TakePlayer player;

  const _PlayerScore({required this.player});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: player.isHuman
            ? const Color(0xFFFFC107).withValues(alpha: 0.25)
            : Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            player.name,
            style: TextStyle(
              color: player.isHuman ? const Color(0xFFFFC107) : Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '${player.totalBulls}▲',
            style: TextStyle(
              color: player.isHuman ? const Color(0xFFFFC107) : Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════
// SELECTIONS ROW (shown during reveal/resolve)
// ═══════════════════════════════════════════

class _SelectionsRow extends StatelessWidget {
  final List<TakePlayer> players;
  final TakeCard? currentCard;
  final TakePlayer? currentPlayer;

  const _SelectionsRow({
    required this.players,
    required this.currentCard,
    required this.currentPlayer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: players.map((p) {
          final isCurrent = p == currentPlayer;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TakeCardWidget(
                card: p.selectedCard,
                width: 38,
                height: 52,
                highlighted: isCurrent,
                faceDown: p.selectedCard == null,
              ),
              const SizedBox(height: 3),
              Text(
                p.name,
                style: TextStyle(
                  color: p.isHuman ? const Color(0xFFFFC107) : Colors.white60,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ═══════════════════════════════════════════
// TABLE AREA (4 rows)
// ═══════════════════════════════════════════

class _TableArea extends StatelessWidget {
  final List<GameRow> rows;
  final int? lastAffectedRow;
  final bool lastWasTake;
  final bool choosingRow;
  final void Function(int) onPickRow;

  const _TableArea({
    required this.rows,
    required this.lastAffectedRow,
    required this.lastWasTake,
    required this.choosingRow,
    required this.onPickRow,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(rows.length, (i) {
        final isAffected = lastAffectedRow == i;
        return GestureDetector(
          onTap: choosingRow ? () => onPickRow(i) : null,
          child: _GameRowWidget(
            row: rows[i],
            rowIndex: i,
            isAffected: isAffected,
            wasTake: isAffected && lastWasTake,
            choosingRow: choosingRow,
          ),
        );
      }),
    );
  }
}

class _GameRowWidget extends StatelessWidget {
  final GameRow row;
  final int rowIndex;
  final bool isAffected;
  final bool wasTake;
  final bool choosingRow;

  const _GameRowWidget({
    required this.row,
    required this.rowIndex,
    required this.isAffected,
    required this.wasTake,
    required this.choosingRow,
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
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: choosingRow || isAffected ? 2 : 1),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text(
              '${rowIndex + 1}',
              style: TextStyle(
                color: choosingRow
                    ? const Color(0xFFFFC107)
                    : Colors.white.withValues(alpha: 0.5),
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Row(
              children: List.generate(5, (slot) {
                if (slot < row.cards.length) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 3),
                    child: TakeCardWidget(
                      card: row.cards[slot],
                      width: 56,
                      height: 78,
                    ),
                  );
                } else {
                  return Padding(
                    padding: const EdgeInsets.only(right: 3),
                    child: Container(
                      width: 56,
                      height: 78,
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
          ),
          Container(
            width: 36,
            alignment: Alignment.centerRight,
            child: Text(
              '${row.totalBulls}▲',
              style: TextStyle(
                color: row.isFull
                    ? Colors.redAccent
                    : Colors.white.withValues(alpha: 0.55),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
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
    const cardW = 64.0;
    const cardH = 89.0;
    const liftY = 8.0;
    const gap = 8.0;
    const hPad = 10.0;
    const fadeW = 28.0;
    const bg = Color(0xFF1B4332);

    return SizedBox(
      height: cardH + liftY + 12,
      child: Stack(
        children: [
          ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(hPad, liftY + 6, hPad, 6),
            itemCount: sorted.length,
            itemBuilder: (context, i) {
              final card = sorted[i];
              final isSelected = selectedCard == card;
              return Padding(
                padding: EdgeInsets.only(right: i < sorted.length - 1 ? gap : 0),
                child: GestureDetector(
                  onTap: interactive ? () => onSelectCard(card) : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    transform: Matrix4.translationValues(0, isSelected ? -liftY : 0, 0),
                    child: TakeCardWidget(
                      card: card,
                      width: cardW,
                      height: cardH,
                      highlighted: isSelected,
                      dimmed: !interactive,
                    ),
                  ),
                ),
              );
            },
          ),
          Positioned(
            left: 0, top: 0, bottom: 0,
            width: fadeW,
            child: IgnorePointer(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [bg, Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 0, top: 0, bottom: 0,
            width: fadeW,
            child: IgnorePointer(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, bg],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
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

  static Color _bgColor(int bulls) => switch (bulls) {
        1 => Colors.white,
        2 => const Color(0xFFFFF9C4),
        3 => const Color(0xFFFFCC80),
        5 => const Color(0xFFEF9A9A),
        7 => const Color(0xFF7B1FA2),
        _ => Colors.white,
      };

  static Color _textColor(int bulls) =>
      bulls == 7 ? Colors.white : Colors.black87;

  @override
  Widget build(BuildContext context) {
    if (faceDown || card == null) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFC62828),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white30, width: 1),
            ),
          ),
        ),
      );
    }

    final bg = highlighted ? const Color(0xFFFFC107) : _bgColor(card!.bulls);
    final textColor = highlighted ? Colors.black : _textColor(card!.bulls);
    final dimColor = dimmed ? Colors.black.withValues(alpha: 0.35) : Colors.transparent;

    return Stack(
      children: [
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: bg,
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
              Positioned(
                bottom: 3,
                left: 0,
                right: 0,
                child: Text(
                  _bullsDots(card!.bulls),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: width * 0.14,
                    color: textColor.withValues(alpha: 0.65),
                    letterSpacing: 0.5,
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

  static String _bullsDots(int bulls) {
    return switch (bulls) {
      1 => '●',
      2 => '●●',
      3 => '●●●',
      5 => '●●●●●',
      7 => '●●●●●●●',
      _ => '●',
    };
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
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                playerWon ? '🏆' : '📊',
                style: const TextStyle(fontSize: 44),
              ),
              const SizedBox(height: 8),
              Text(
                playerWon ? 'YOU WIN!' : '${winner.name} WINS!',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 16),
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
                        '${p.totalBulls} bulls',
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
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  label: 'PLAY AGAIN',
                  onTap: onPlayAgain,
                  backgroundColor: Colors.black,
                  textColor: Colors.white,
                  borderColor: Colors.black,
                  verticalPadding: 13,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  label: 'MENU',
                  onTap: onMenu,
                  backgroundColor: Colors.white,
                  textColor: Colors.black,
                  borderColor: Colors.black,
                  borderWidth: 1.5,
                  verticalPadding: 13,
                  fontSize: 13,
                ),
              ),
            ],
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
