// File: lib/screens/seat_picker_screen.dart
// Shown when the URL names no player (someone opened the bare address).
// Each button loads that player's page, so the URL can be refreshed or
// bookmarked.

import 'package:flutter/material.dart';

import '../client_theme.dart';

class SeatPickerScreen extends StatelessWidget {
  const SeatPickerScreen({
    super.key,
    required this.playerCount,
    required this.onPick,
  });

  final int playerCount;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          children: [
            const Text('COMBAT HELPER', style: eyebrowStyle),
            const SizedBox(height: 4),
            const Text('PICK YOUR SEAT', style: titleStyle),
            const SizedBox(height: 24),
            for (var i = 0; i < playerCount; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                  ),
                  onPressed: () => onPick(i),
                  child: Text(
                    'PLAYER ${i + 1}',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
