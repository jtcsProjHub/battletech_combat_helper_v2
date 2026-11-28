// File: lib/screens/settings_screen.dart
// The app's settings menu, opened from the gear on the main menu. Two tabs:
// Server Settings (the hotspot, whose network name and password are read
// from and saved to the NetworkManager profile) and Game Play (the defaults each player's
// settings start from in a new skirmish). Changes are kept as a draft until
// Save; leaving with unsaved changes asks first.
//
// Skirmishes already confirmed keep the settings they started with.

import 'package:battletech_logic/battletech_logic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_theme.dart';
import '../settings/settings_repository.dart';
import '../widgets/hud.dart';
import '../widgets/settings/host_config_form.dart';
import '../widgets/settings/roll_preferences_tree.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  /// Null until the saved settings are loaded.
  AppSettingsDraft? _draft;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    ref.read(appSettingsProvider.future).then((s) {
      if (!mounted) return;
      setState(() => _draft = AppSettingsDraft(s));
      _loadNetwork();
    });
  }

  /// Reads the network name and password from the saved hotspot profile.
  Future<void> _loadNetwork() async {
    final draft = _draft;
    if (draft == null) return;
    final connection = draft.saved.host.hotspotConnection;
    setState(() {
      draft.network = null;
      draft.networkError = null;
    });
    try {
      final network = await ref.read(hotspotProfilesProvider).read(connection);
      if (!mounted || draft.saved.host.hotspotConnection != connection) return;
      setState(() => draft.networkLoaded(network));
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => draft.networkFailed('$e'));
    }
  }

  bool get _dirty => _draft?.isDirty ?? false;

  bool get _canSave => !_saving && (_draft?.canSave ?? false);

  /// Writes a changed network to the profile first, then the settings.
  Future<void> _save() async {
    final draft = _draft;
    if (draft == null || !_canSave) return;
    final settings = draft.value;
    final network = draft.networkToSave;
    final renamed =
        settings.host.hotspotConnection != draft.saved.host.hotspotConnection;
    setState(() => _saving = true);
    try {
      if (network != null) {
        await ref
            .read(hotspotProfilesProvider)
            .write(draft.saved.host.hotspotConnection, network);
      }
      if (draft.settingsDirty) {
        await ref.read(appSettingsProvider.notifier).save(settings);
      }
      draft.markSaved(settings, network: network);
      _snack('Settings saved.');
      if (renamed) _loadNetwork();
    } on Object catch (e) {
      _snack('Could not save the settings: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _revert() => setState(() => _draft?.revert());

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmLeave() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your unsaved settings changes will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('KEEP EDITING'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('DISCARD'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('SETTINGS'),
            bottom: const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelStyle: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
              ),
              tabs: [
                Tab(text: 'SERVER SETTINGS'),
                Tab(text: 'GAME PLAY'),
              ],
            ),
          ),
          body: draft == null
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  children: [
                    _TabPage(
                      child: HostConfigForm(
                        draft: draft,
                        onChanged: () => setState(() {}),
                        onReloadNetwork: _loadNetwork,
                      ),
                    ),
                    _TabPage(
                      child: _GamePlayTab(
                        rolls: draft.gameplay.rolls,
                        onChanged: (r) => setState(() => draft.setRolls(r)),
                      ),
                    ),
                  ],
                ),
          bottomNavigationBar: _SaveBar(
            dirty: _dirty,
            onSave: _canSave ? _save : null,
            onRevert: _dirty && !_saving ? _revert : null,
          ),
        ),
      ),
    );
  }
}

/// Scrolling page body with the HUD screen padding.
class _TabPage extends StatelessWidget {
  const _TabPage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 960;
        return SingleChildScrollView(
          padding: wide
              ? const EdgeInsets.fromLTRB(40, 32, 40, 32)
              : const EdgeInsets.fromLTRB(16, 24, 16, 24),
          child: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class _GamePlayTab extends StatelessWidget {
  const _GamePlayTab({required this.rolls, required this.onChanged});

  final RollPreferences rolls;
  final ValueChanged<RollPreferences> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('DICE ROLLS', style: HudText.sectionLabel),
            ),
            TextButton(
              onPressed: rolls.isAllAutomated
                  ? null
                  : () => onChanged(RollPreferences.automated),
              child: const Text('CHECK ALL'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Checked rolls are made by the app. Unchecked rolls are rolled at '
          'the table and entered by the player. These are the defaults for '
          'new skirmishes; each player can change their own during play.',
          style: TextStyle(
            fontSize: 15,
            height: 1.45,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 20),
        RollPreferencesTree(preferences: rolls, onChanged: onChanged),
      ],
    );
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.dirty,
    required this.onSave,
    required this.onRevert,
  });

  final bool dirty;
  final VoidCallback? onSave;
  final VoidCallback? onRevert;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.panel,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Text(
                dirty ? 'Unsaved changes' : 'All changes saved',
                style: const TextStyle(fontSize: 14, color: AppColors.textDim),
              ),
            ),
            OutlinedButton(onPressed: onRevert, child: const Text('REVERT')),
            const SizedBox(width: 12),
            FilledButton(onPressed: onSave, child: const Text('SAVE')),
          ],
        ),
      ),
    );
  }
}
