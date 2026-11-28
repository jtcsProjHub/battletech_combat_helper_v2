// File: lib/widgets/settings/host_config_form.dart
// The Server Settings tab's hotspot fields. Shows an AppSettingsDraft's
// hotspot parts and writes each keystroke into the draft; validation and
// the rules for when the network can be edited live in the draft. When the
// owner swaps in new draft parts (load, revert, save), the fields reload.

import 'package:battletech_logic/battletech_logic.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_theme.dart';
import '../hud.dart';

class HostConfigForm extends StatefulWidget {
  const HostConfigForm({
    super.key,
    required this.draft,
    required this.onChanged,
    required this.onReloadNetwork,
  });

  final AppSettingsDraft draft;

  /// Runs after a field changed the draft.
  final VoidCallback onChanged;

  /// Reads the network from the saved profile again.
  final VoidCallback onReloadNetwork;

  @override
  State<HostConfigForm> createState() => _HostConfigFormState();
}

class _HostConfigFormState extends State<HostConfigForm> {
  final _connection = TextEditingController();
  final _port = TextEditingController();
  final _ssid = TextEditingController();
  final _password = TextEditingController();
  bool _showPassword = false;

  HostConfigDraft? _shownHost;
  HotspotNetworkDraft? _shownNetwork;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(HostConfigForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  /// Reloads the fields of any draft part that was replaced.
  void _sync() {
    final host = widget.draft.host;
    if (!identical(host, _shownHost)) {
      _shownHost = host;
      _connection.text = host.connection;
      _port.text = host.port;
    }
    final network = widget.draft.network;
    if (!identical(network, _shownNetwork)) {
      _shownNetwork = network;
      _ssid.text = network?.ssid ?? '';
      _password.text = network?.password ?? '';
    }
  }

  @override
  void dispose() {
    for (final c in [_connection, _port, _ssid, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  void _edit(void Function() change) {
    change();
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    final host = d.host;
    final network = d.network;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('HOTSPOT PROFILE', style: HudText.sectionLabel),
        const SizedBox(height: 6),
        const _Explanation(
          'The players\' phones join this laptop\'s WiFi hotspot. On Linux '
          'it is a NetworkManager connection profile.',
        ),
        const SizedBox(height: 20),
        _field(
          controller: _connection,
          label: 'Hotspot profile',
          helper: 'Name of the NetworkManager connection.',
          error: host.connectionError,
          onChanged: (v) => _edit(() => host.connection = v),
        ),
        _field(
          controller: _port,
          label: 'Port',
          helper: 'The player pages are served on this port.',
          error: host.portError,
          onChanged: (v) => _edit(() => host.port = v),
          digitsOnly: true,
          width: 220,
        ),
        const SizedBox(height: 12),
        const Text('NETWORK', style: HudText.sectionLabel),
        const SizedBox(height: 6),
        const _Explanation(
          'Stored in the hotspot profile itself. Changes are written to the '
          'profile on Save and take effect the next time the hotspot starts.',
        ),
        const SizedBox(height: 20),
        if (d.profileRenamed)
          const _Notice(
            'Save to switch profiles. The new profile\'s network name and '
            'password are read then.',
          )
        else if (d.networkError case final error?)
          _Notice(error, onRetry: widget.onReloadNetwork)
        else if (network == null)
          const Padding(
            padding: EdgeInsets.only(bottom: 18),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text(
                  'Reading the hotspot profile…',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        _field(
          controller: _ssid,
          label: 'Network name',
          helper: 'The WiFi network name the phones look for.',
          error: d.networkEditable ? network?.ssidError : null,
          enabled: d.networkEditable,
          onChanged: (v) => _edit(() => network?.ssid = v),
        ),
        _field(
          controller: _password,
          label: 'Password',
          helper: network != null && network.loaded.password == null
              ? 'The profile\'s password could not be read. Leave blank to '
                    'keep it.'
              : 'Leave blank to keep the current password.',
          error: d.networkEditable ? network?.passwordError : null,
          enabled: d.networkEditable,
          onChanged: (v) => _edit(() => network?.password = v),
          obscure: !_showPassword,
          suffix: IconButton(
            tooltip: _showPassword ? 'Hide password' : 'Show password',
            icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
            onPressed: () => setState(() => _showPassword = !_showPassword),
          ),
        ),
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String helper,
    required String? error,
    required ValueChanged<String> onChanged,
    bool enabled = true,
    bool obscure = false,
    bool digitsOnly = false,
    Widget? suffix,
    double? width,
  }) {
    final field = TextField(
      controller: controller,
      onChanged: onChanged,
      enabled: enabled,
      obscureText: obscure,
      keyboardType: digitsOnly ? TextInputType.number : null,
      inputFormatters: digitsOnly
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      style: const TextStyle(fontSize: 16, color: AppColors.text),
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        helperMaxLines: 2,
        errorText: error,
        suffixIcon: suffix,
        border: const OutlineInputBorder(),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width ?? 560),
          child: field,
        ),
      ),
    );
  }
}

class _Explanation extends StatelessWidget {
  const _Explanation(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 15,
      height: 1.45,
      color: AppColors.textSecondary,
    ),
  );
}

/// A message above the network fields, with an optional retry.
class _Notice extends StatelessWidget {
  const _Notice(this.message, {this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      constraints: const BoxConstraints(maxWidth: 560),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.panelRaised,
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 14, color: AppColors.text),
            ),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('RETRY')),
        ],
      ),
    );
  }
}
