// File: lib/screens/skirmish_play_screen.dart
// A confirmed skirmish. Opening it turns on hosting (hotspot plus the
// player pages) and shows the join screen: the network QR code in the
// middle and each player's page QR code at the sides. Start Now moves on
// to the game, still a stub that shows each player's units and the map;
// the join codes stay reachable for phones that reconnect. Quit (or Back)
// asks first, turns hosting off, saves, and returns to the main menu.
// Closing the app turns hosting off too.
//
// The stages here are local placeholders. The game state machine will
// replace them, with its initialization state owning the SkirmishHost.

import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_theme.dart';
import '../mech_library.dart';
import '../mech_library_loader.dart';
import '../server/hotspot.dart';
import '../server/skirmish_host.dart';
import '../skirmish/skirmish.dart';
import '../widgets/skirmish/join_panels.dart';
import '../widgets/skirmish/skirmish_autosave.dart';
import '../widgets/skirmish/skirmish_map_view.dart';
import '../widgets/skirmish/skirmish_panels.dart';
import '../widgets/skirmish/skirmish_scaffold.dart';

class SkirmishPlayScreen extends ConsumerStatefulWidget {
  const SkirmishPlayScreen({super.key, required this.skirmish});

  final Skirmish skirmish;

  @override
  ConsumerState<SkirmishPlayScreen> createState() => _SkirmishPlayScreenState();
}

class _SkirmishPlayScreenState extends ConsumerState<SkirmishPlayScreen>
    with SkirmishAutosave {
  late final SkirmishHost _host;
  late Future<HostSession> _hosting;
  late final AppLifecycleListener _exitListener;
  bool _leaving = false;

  /// True once Start Now was pressed.
  bool _started = false;

  /// Shows the join codes instead of the game.
  bool _showJoin = true;

  @override
  Skirmish get skirmish => widget.skirmish;

  @override
  void initState() {
    super.initState();
    _host = ref.read(skirmishHostFactoryProvider)(widget.skirmish);
    _hosting = _host.start();
    _exitListener = AppLifecycleListener(
      onExitRequested: () async {
        await _host.stop();
        return AppExitResponse.exit;
      },
    );
  }

  @override
  void dispose() {
    _exitListener.dispose();
    _host.stop();
    super.dispose();
  }

  Future<void> _retry() async {
    await _host.stop();
    if (!mounted) return;
    setState(() => _hosting = _host.start());
  }

  void _startNow() {
    if (!_started) _host.announcePlaying();
    setState(() {
      _started = true;
      _showJoin = false;
    });
  }

  Future<void> _quit() async {
    if (_leaving) return;
    _leaving = true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave the skirmish?'),
        content: const Text(
          'The game is saved and the hotspot is turned off. '
          'Resume it later from Load Skirmish.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('STAY'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('LEAVE'),
          ),
        ],
      ),
    );
    if (leave != true || !mounted) {
      _leaving = false;
      return;
    }
    await _host.stop();
    final error = await saveSkirmish();
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save the skirmish: $error')),
      );
      _leaving = false;
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _quit();
      },
      child: FutureBuilder<HostSession>(
        future: _hosting,
        builder: (context, snapshot) {
          final session = snapshot.data;
          if (snapshot.hasError) return _buildError(snapshot.error!);
          if (session == null) return _buildStarting();
          return StreamBuilder<List<int>>(
            stream: _host.presence,
            initialData: _host.connected,
            builder: (context, presence) => _showJoin
                ? _buildJoin(session, presence.data ?? _host.connected)
                : _buildGame(),
          );
        },
      ),
    );
  }

  Widget _buildFrame({required String status, required Widget body}) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.skirmish.name.toUpperCase()),
        automaticallyImplyLeading: false,
      ),
      body: Center(child: body),
      bottomNavigationBar: SkirmishBottomBar(
        status: status,
        children: [OutlinedButton(onPressed: _quit, child: const Text('QUIT'))],
      ),
    );
  }

  Widget _buildStarting() => _buildFrame(
    status: 'Starting the game network…',
    body: const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 20),
        Text(
          'Turning on the hotspot and the player pages.',
          style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
        ),
      ],
    ),
  );

  Widget _buildError(Object error) {
    final (message, details) = switch (error) {
      HotspotException e => (e.message, e.details),
      _ => ('Could not start the game network.', '$error'),
    };
    return _buildFrame(
      status: 'The game network is off.',
      body: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 40, color: AppColors.danger),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, color: AppColors.text),
            ),
            if (details != null && details.isNotEmpty) ...[
              const SizedBox(height: 12),
              SelectableText(
                details,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.textDim),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(onPressed: _retry, child: const Text('RETRY')),
          ],
        ),
      ),
    );
  }

  Widget _buildJoin(HostSession session, List<int> devices) {
    final s = widget.skirmish;
    final joined = devices.where((n) => n > 0).length;
    Widget player(int i) => PlayerJoinPanel(
      label: 'Player ${i + 1}',
      lanceName: s.player(i).lance?.name,
      url: session.playerUrl(i),
      devices: devices[i],
    );
    return SkirmishScaffold(
      eyebrow: 'Skirmish · Join the game',
      name: s.name,
      onRename: (name) => setState(() => s.name = name),
      columns: [
        (label: 'PLAYER 1', child: player(0)),
        (
          label: 'NETWORK',
          child: NetworkJoinPanel(
            ssid: session.network.ssid,
            password: session.network.password,
            qrData: session.network.qrPayload,
          ),
        ),
        (label: 'PLAYER 2', child: player(1)),
      ],
      bottomBar: SkirmishBottomBar(
        status: '$joined of ${devices.length} players joined.',
        children: [
          OutlinedButton(onPressed: _quit, child: const Text('QUIT')),
          FilledButton(
            onPressed: _startNow,
            child: Text(_started ? 'BACK TO GAME' : 'START NOW!'),
          ),
        ],
      ),
    );
  }

  Widget _buildGame() {
    final s = widget.skirmish;
    final library = ref.watch(mechLibraryProvider).value;
    final map = s.map;

    Widget units(int i) {
      final p = s.player(i);
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          SkirmishColumnHeader(label: 'Player ${i + 1}', help: p.lance?.name),
          const SizedBox(height: 16),
          if (p.units.isEmpty)
            const Text(
              'No units.',
              style: TextStyle(fontSize: 15, color: AppColors.textDim),
            ),
          for (final u in p.units) ...[
            _UnitCard(unit: u, library: library),
            const SizedBox(height: 10),
          ],
        ],
      );
    }

    return SkirmishScaffold(
      eyebrow: 'Skirmish · Turn ${s.turn}',
      name: s.name,
      onRename: (name) => setState(() => s.name = name),
      columns: [
        (label: 'PLAYER 1', child: units(0)),
        (
          label: 'MAP',
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: map == null
                ? const SizedBox.shrink()
                : MapPreview(
                    map: map.mergedSaved,
                    thumbnail: SkirmishMapThumbnail(map: map),
                  ),
          ),
        ),
        (label: 'PLAYER 2', child: units(1)),
      ],
      bottomBar: SkirmishBottomBar(
        status: 'Turn tracking is not built yet.',
        children: [
          OutlinedButton(
            onPressed: () => setState(() => _showJoin = true),
            child: const Text('JOIN CODES'),
          ),
        ],
      ),
    );
  }
}

class _UnitCard extends StatelessWidget {
  const _UnitCard({required this.unit, required this.library});

  final SkirmishUnit unit;
  final MechLibrary? library;

  @override
  Widget build(BuildContext context) {
    final mech = library?.byId(unit.mechId);
    final pilot = unit.pilot;
    const dim = TextStyle(fontSize: 13, color: AppColors.textDim);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.panelRaised,
        border: Border(
          left: BorderSide(color: AppColors.accent, width: 4),
          top: BorderSide(color: AppColors.border),
          right: BorderSide(color: AppColors.border),
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            mech == null
                ? unit.mechId
                : '${mech.name} ${mech.variant}'.toUpperCase(),
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${pilot.name.isEmpty ? 'Unnamed pilot' : pilot.name} · '
            'G${pilot.gunnery} / P${pilot.piloting}',
            style: dim,
          ),
          const SizedBox(height: 6),
          Text(
            'Armor ${unit.armorLeft}'
            '${mech == null ? '' : ' / ${mech.armorTotal}'} · '
            'Structure ${unit.structureLeft}'
            '${mech == null ? '' : ' / ${mech.structureTotal}'} · '
            'Heat ${unit.heat}',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
