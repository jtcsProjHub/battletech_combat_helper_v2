// File: lib/widgets/inline_editable_text.dart
// Text that turns into a one-line field on double-click, with check and
// cancel buttons. Enter or the check commits; Escape or the cancel button
// restores the old value. An empty value cannot be committed.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';

class InlineEditableText extends StatefulWidget {
  const InlineEditableText({
    super.key,
    required this.value,
    required this.onChanged,
    this.style,
    this.display,
    this.tooltip = 'Double-click to rename',
  });

  final String value;

  /// Called with the trimmed new value, only when it differs.
  final ValueChanged<String> onChanged;

  final TextStyle? style;

  /// How to show the value when not editing, e.g. upper case. Defaults to
  /// the value itself.
  final String Function(String value)? display;

  final String tooltip;

  @override
  State<InlineEditableText> createState() => _InlineEditableTextState();
}

class _InlineEditableTextState extends State<InlineEditableText> {
  late final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _editing = false;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _start() {
    _controller
      ..text = widget.value
      ..selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.value.length,
      );
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  bool get _canCommit => _controller.text.trim().isNotEmpty;

  void _commit() {
    if (!_canCommit) return;
    final next = _controller.text.trim();
    setState(() => _editing = false);
    if (next != widget.value) widget.onChanged(next);
  }

  void _cancel() => setState(() => _editing = false);

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.merge(widget.style);
    if (!_editing) {
      return Tooltip(
        message: widget.tooltip,
        waitDuration: const Duration(milliseconds: 600),
        child: GestureDetector(
          onDoubleTap: _start,
          child: Text(
            widget.display?.call(widget.value) ?? widget.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      );
    }

    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _cancel},
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 160, maxWidth: 520),
              child: IntrinsicWidth(
                child: ListenableBuilder(
                  listenable: _controller,
                  builder: (context, _) => TextField(
                    controller: _controller,
                    focusNode: _focus,
                    style: style,
                    maxLines: 1,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _commit(),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      errorText: _canCommit ? null : 'Enter a name',
                      enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: AppColors.borderStrong),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => IconButton(
              tooltip: 'Save name',
              visualDensity: VisualDensity.compact,
              color: AppColors.accent,
              onPressed: _canCommit ? _commit : null,
              icon: const Icon(Icons.check, size: 20),
            ),
          ),
          IconButton(
            tooltip: 'Cancel rename',
            visualDensity: VisualDensity.compact,
            color: AppColors.textDim,
            onPressed: _cancel,
            icon: const Icon(Icons.close, size: 20),
          ),
        ],
      ),
    );
  }
}
