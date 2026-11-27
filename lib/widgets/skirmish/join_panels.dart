// File: lib/widgets/skirmish/join_panels.dart
// Columns of the join screen: how a player gets their page onto their
// phone, and how to join the hotspot. Each card is a few steps above a QR
// code.

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app_theme.dart';
import '../hud.dart';

class _JoinCard extends StatelessWidget {
  const _JoinCard({
    required this.title,
    required this.lines,
    required this.qrData,
    this.status,
  });

  final String title;
  final List<String> lines;
  final String qrData;
  final Widget? status;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(title.toUpperCase(), style: HudText.sectionLabel),
        const SizedBox(height: 12),
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: SelectableText(
              line,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        const SizedBox(height: 16),
        Center(
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: QrImageView(
              data: qrData,
              size: 220,
              padding: EdgeInsets.zero,
            ),
          ),
        ),
        if (status != null) ...[
          const SizedBox(height: 16),
          Center(child: status!),
        ],
      ],
    );
  }
}

/// Step 2 for a player: open their page.
class PlayerJoinPanel extends StatelessWidget {
  const PlayerJoinPanel({
    super.key,
    required this.label,
    required this.lanceName,
    required this.url,
    required this.devices,
  });

  final String label;
  final String? lanceName;
  final Uri url;

  /// Phones connected to this player's page.
  final int devices;

  @override
  Widget build(BuildContext context) {
    final joined = devices > 0;
    return _JoinCard(
      title: '$label start',
      lines: [
        if (lanceName != null) 'Lance: $lanceName',
        '1. Join the game network.',
        '2. Scan the code below, or go to',
        '$url',
      ],
      qrData: '$url',
      status: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            joined ? Icons.check_circle : Icons.hourglass_empty,
            size: 18,
            color: joined ? AppColors.added : AppColors.textDim,
          ),
          const SizedBox(width: 8),
          Text(
            !joined
                ? 'Waiting for $label'
                : devices == 1
                ? '$label joined'
                : '$label joined on $devices devices',
            style: TextStyle(
              fontSize: 15,
              color: joined ? AppColors.added : AppColors.textDim,
            ),
          ),
        ],
      ),
    );
  }
}

/// Step 1 for everyone: join the hotspot.
class NetworkJoinPanel extends StatelessWidget {
  const NetworkJoinPanel({
    super.key,
    required this.ssid,
    required this.password,
    required this.qrData,
  });

  final String ssid;
  final String? password;
  final String qrData;

  @override
  Widget build(BuildContext context) {
    return _JoinCard(
      title: 'Join game network',
      lines: ['Network: $ssid', 'Password: ${password ?? 'ask the host'}'],
      qrData: qrData,
    );
  }
}
