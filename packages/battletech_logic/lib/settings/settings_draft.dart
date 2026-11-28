// File: lib/settings/settings_draft.dart
// Editing the app settings: a draft of the saved settings that the settings
// menu changes field by field, with validation, unsaved-change tracking,
// revert, and what to save. The menu only shows the draft and forwards
// input to it.
//
// The hotspot's network name and password come from the NetworkManager
// profile, not the settings file. The owner loads them into the draft
// (networkLoaded) and writes [AppSettingsDraft.networkToSave] back to the
// profile on Save.

import 'app_settings.dart';
import 'dice_rolls.dart';
import 'host_config.dart';
import 'hotspot_network.dart';
import 'player_settings.dart';

/// The hotspot profile name and port as typed, so half-typed or invalid
/// values can be shown and checked before they become a [HostConfig].
class HostConfigDraft {
  HostConfigDraft.from(HostConfig config)
    : connection = config.hotspotConnection,
      port = '${config.port}';

  String connection;
  String port;

  String? get connectionError =>
      connection.trim().isEmpty ? 'Enter the profile name.' : null;

  String? get portError {
    final p = int.tryParse(port.trim());
    return p != null && HostConfig.isValidPort(p)
        ? null
        : 'Use a port from 1024 to 65535.';
  }

  bool get isValid => connectionError == null && portError == null;

  /// [base] with the typed values. Not validated (see [isValid]): an
  /// unreadable port reads as 0.
  HostConfig toConfig(HostConfig base) => HostConfig(
    hotspotConnection: connection.trim(),
    port: int.tryParse(port.trim()) ?? 0,
    clientWebRoot: base.clientWebRoot,
  );
}

/// The profile's network name and password as typed.
class HotspotNetworkDraft {
  HotspotNetworkDraft.from(this.loaded)
    : ssid = loaded.ssid,
      password = loaded.password ?? '';

  /// As read from the profile.
  final HotspotNetwork loaded;

  String ssid;
  String password;

  String? get ssidError {
    final s = ssid.trim();
    if (s.isEmpty) return 'Enter the network name.';
    return HotspotNetwork.isValidSsid(s) ? null : 'At most 32 characters.';
  }

  /// A blank password keeps the profile's current one.
  String? get passwordError {
    final p = password.trim();
    return p.isEmpty || HotspotNetwork.isValidPassword(p)
        ? null
        : 'Use 8 to 63 characters.';
  }

  bool get isValid => ssidError == null && passwordError == null;

  HotspotNetwork get value {
    final p = password.trim();
    return HotspotNetwork(
      ssid: ssid.trim(),
      password: p.isEmpty ? loaded.password : p,
    );
  }

  bool get isDirty => value != loaded;
}

class AppSettingsDraft {
  AppSettingsDraft(AppSettings saved)
    : _saved = saved,
      host = HostConfigDraft.from(saved.host),
      gameplay = saved.gameplay;

  AppSettings _saved;

  /// The settings as last loaded or saved.
  AppSettings get saved => _saved;

  HostConfigDraft host;
  GameplaySettings gameplay;

  /// The saved profile's network, once loaded. Null while loading or when
  /// it could not be read (see [networkError]).
  HotspotNetworkDraft? network;

  /// Why the profile's network could not be read.
  String? networkError;

  /// Called with the network read from the saved profile.
  void networkLoaded(HotspotNetwork loaded) {
    network = HotspotNetworkDraft.from(loaded);
    networkError = null;
  }

  void networkFailed(String message) {
    network = null;
    networkError = message;
  }

  /// The network fields belong to the saved profile, so they are locked
  /// while a different profile name is typed (until it is saved and that
  /// profile is read).
  bool get profileRenamed =>
      host.connection.trim() != _saved.host.hotspotConnection;

  bool get networkEditable => network != null && !profileRenamed;

  /// The settings as edited. Only worth saving when [isValid].
  AppSettings get value =>
      _saved.copyWith(host: host.toConfig(_saved.host), gameplay: gameplay);

  bool get settingsDirty => value != _saved;

  /// The network to write to the profile on Save, or null when unchanged.
  HotspotNetwork? get networkToSave {
    final n = network;
    return n != null && networkEditable && n.isDirty ? n.value : null;
  }

  bool get isDirty => settingsDirty || networkToSave != null;

  bool get isValid =>
      host.isValid && (!networkEditable || (network?.isValid ?? true));

  bool get canSave => isDirty && isValid;

  void setRollChecked(String id, {required bool checked}) => gameplay = gameplay
      .copyWith(rolls: gameplay.rolls.withChecked(id, checked: checked));

  void setRolls(RollPreferences rolls) =>
      gameplay = gameplay.copyWith(rolls: rolls);

  /// Back to the saved settings and the profile's network as read.
  void revert() {
    _resetSettings(_saved);
    if (network case final n?) network = HotspotNetworkDraft.from(n.loaded);
  }

  /// Call after Save: [settings] become the new baseline, and [network]
  /// (when it was written) the profile's network. When the profile name
  /// changed, the network is cleared: read the new profile next.
  void markSaved(AppSettings settings, {HotspotNetwork? network}) {
    final renamed =
        settings.host.hotspotConnection != _saved.host.hotspotConnection;
    _resetSettings(settings);
    if (renamed) {
      this.network = null;
      networkError = null;
    } else if (network != null) {
      networkLoaded(network);
    }
  }

  void _resetSettings(AppSettings settings) {
    _saved = settings;
    host = HostConfigDraft.from(settings.host);
    gameplay = settings.gameplay;
  }
}
