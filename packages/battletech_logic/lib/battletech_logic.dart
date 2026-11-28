/// Pure Dart game logic shared by the desktop game server and the phone
/// web client. No Flutter, dart:io, or dart:html here, so both can use it.
///
/// The settings model lives here too. AppSettings, HostConfig and
/// SkirmishSettings are server data (the hotspot password); only
/// PlayerSettings, GameplaySettings and the roll catalog go to the phones.
library;

export 'net/client_protocol.dart';
export 'settings/dice_rolls.dart';
export 'settings/player_settings.dart';
export 'settings/app_settings.dart';
export 'settings/host_config.dart';
export 'settings/hotspot_network.dart';
export 'settings/settings_draft.dart';
export 'settings/skirmish_settings.dart';
