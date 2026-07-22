import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../widgets/app_button.dart';
import 'game_screen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B4332),
      body: Stack(
        children: [
          Positioned.fill(
            child: SvgPicture.asset('assets/Group 1.svg', fit: BoxFit.cover),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _StarfallTitle(),
                      const SizedBox(height: 8),
                      const Text(
                        "Place cards in rows. If you're forced to add the 6th card,\nyou take the row and collect star penalty points. Lowest score wins!",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFB7E4C7),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 18),
                      AppButton(
                        label: 'PLAY',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const GameScreen(
                              playerCount: 5,
                              playerName: 'You',
                            ),
                          ),
                        ),
                        backgroundColor: const Color(0xFFFFC107),
                        textColor: Colors.black,
                        borderColor: const Color(0xFFE65100),
                        verticalPadding: 12,
                        fontSize: 15,
                      ),
                      const SizedBox(height: 10),
                      _RulesButton(onTap: () => _showRules(context)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRules(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'HOW TO PLAY',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1),
        ),
        content: const SingleChildScrollView(
          child: Text(
            '104 cards, numbered 1–104.\n\n'
            'Each round, everyone simultaneously picks one card to play.\n\n'
            'Cards are played lowest first. Each card goes into the row whose top card is the closest number below it.\n\n'
            'If your card would be the 6th in a row, you must take those 5 cards as penalty stars.\n\n'
            'If your card is lower than all row tops, you must choose a row to take.\n\n'
            'After 10 rounds, the player with the fewest stars wins!\n\n'
            'Star counts per card:\n'
            '● 1 star — most cards\n'
            '● 2 stars — multiples of 5\n'
            '● 3 stars — multiples of 10\n'
            '● 5 stars — multiples of 11\n'
            '● 7 stars — card 55 (special!)',
            style: TextStyle(fontSize: 13, height: 1.6, color: Colors.black87),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('GOT IT', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _StarfallTitle extends StatelessWidget {
  const _StarfallTitle();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        Text(
          'STAR',
          style: TextStyle(
            color: Colors.white,
            fontSize: 40,
            fontWeight: FontWeight.w900,
            letterSpacing: 8,
            height: 1,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          'FALL',
          style: TextStyle(
            color: Color(0xFFFFC107),
            fontSize: 40,
            fontWeight: FontWeight.w900,
            letterSpacing: 8,
            height: 1,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _RulesButton extends StatelessWidget {
  final VoidCallback onTap;

  const _RulesButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: const Center(
        child: Text(
          'How to play',
          style: TextStyle(
            color: Color(0xFF95D5B2),
            fontSize: 13,
            decoration: TextDecoration.underline,
            decorationColor: Color(0xFF95D5B2),
          ),
        ),
      ),
    );
  }
}

