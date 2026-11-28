// File: lib/screens/player_screen.dart
// A player's page. Placeholder: shows whose page it is, the lance, the
// connection, and the game phase. The player controls come later.

import 'package:battletech_logic/battletech_logic.dart';
import 'package:flutter/material.dart';

import '../client_theme.dart';
import '../player_connection.dart';

class PlayerScreen extends StatelessWidget {
  const PlayerScreen({
    super.key,
    required this.player,
    required this.connection,
  });

  final int player;
  final PlayerConnection connection;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: connection,
          builder: (context, _) {
            final welcome = connection.welcome;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              children: [
                Text(
                  (welcome?.skirmishName ?? 'Combat Helper').toUpperCase(),
                  style: eyebrowStyle,
                ),
                const SizedBox(height: 4),
                Text('PLAYER ${player + 1}', style: titleStyle),
                const SizedBox(height: 16),
                _Card(
                  children: [
                    const Text(
                      'Lance',
                      style: TextStyle(
                        fontSize: 14,
                        color: ClientColors.textDim,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      welcome == null ? '—' : welcome.lanceName ?? 'No lance',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: ClientColors.text,
                      ),
                    ),
                  ],
                ),
                _Card(
                  children: [
                    _StatusLine(status: connection.status),
                    const SizedBox(height: 6),
                    Text(
                      switch (connection.phase) {
                        GamePhase.lobby =>
                          'Waiting for the host to start the game.',
                        GamePhase.playing => 'The game has started.',
                        null => '',
                      },
                      style: const TextStyle(
                        fontSize: 15,
                        color: ClientColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Placeholder page. The player controls come later.',
                  style: TextStyle(fontSize: 13, color: ClientColors.textDim),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.status});

  final ConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final on = status == ConnectionStatus.connected;
    return Row(
      children: [
        Icon(
          Icons.circle,
          size: 12,
          color: on ? ClientColors.ok : ClientColors.danger,
        ),
        const SizedBox(width: 8),
        Text(switch (status) {
          ConnectionStatus.connecting => 'Connecting…',
          ConnectionStatus.connected => 'Connected',
          ConnectionStatus.reconnecting => 'Reconnecting…',
        }, style: const TextStyle(fontSize: 17, color: ClientColors.text)),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: ClientColors.panelRaised,
        border: Border(
          left: BorderSide(color: ClientColors.accent, width: 4),
          top: BorderSide(color: ClientColors.border),
          right: BorderSide(color: ClientColors.border),
          bottom: BorderSide(color: ClientColors.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
