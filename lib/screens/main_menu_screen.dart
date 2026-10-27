import 'dart:math' as math;
import 'dart:ui' show AppExitType;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_routes.dart';
import '../app_theme.dart';
import '../widgets/hud.dart';

/// One entry in the main menu.
class MenuOption {
  const MenuOption({
    required this.label,
    required this.description,
    required this.steps,
    required this.route,
  });

  final String label;
  final String description;
  final List<String> steps;
  final String route;
}

const List<MenuOption> mainMenuOptions = [
  MenuOption(
    label: 'Create / Edit Lance Precons',
    description:
        'Build a lance from the mech catalog, assign pilots, and save it '
        'as a precon for later skirmishes.',
    steps: [
      'Name a new lance or open an existing one',
      'Browse and select mechs',
      'Preview stats and gear',
      'Add to or remove from the lance',
      'Assign pilots',
      'Finalize and save',
    ],
    route: AppRoutes.lanceBuilder,
  ),
  MenuOption(
    label: 'New Skirmish',
    description:
        'Set up a game with saved lances for each side, then track damage '
        'and heat during play.',
    steps: ['Choose a lance for each side', 'Start the skirmish'],
    route: AppRoutes.newSkirmish,
  ),
  MenuOption(
    label: 'Load Skirmish',
    description:
        'Resume a skirmish from a save file with damage, heat, and pilot '
        'status intact.',
    steps: ['Choose a save file', 'Review lance status', 'Resume play'],
    route: AppRoutes.loadSkirmish,
  ),
];

/// Home screen. Hover or focus on an option to show its briefing.
/// Click an option, or Launch, to open its route.
class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  int _active = 0;

  static const double _wideBreakpoint = 960;

  void _setActive(int index) {
    if (index != _active) setState(() => _active = index);
  }

  void _open(int index) {
    _setActive(index);
    Navigator.of(context).pushNamed(mainMenuOptions[index].route);
  }

  void _quit() {
    ServicesBinding.instance.exitApplication(AppExitType.required);
  }

  @override
  Widget build(BuildContext context) {
    final option = mainMenuOptions[_active];

    return Scaffold(
      body: Column(
        children: [
          const _Header(),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= _wideBreakpoint) {
                  // Fill the window height, but scroll if the content
                  // is taller than the window.
                  const vPad = 48.0;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(40, vPad, 40, vPad),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: math.max(
                          0.0,
                          constraints.maxHeight - vPad * 2,
                        ),
                      ),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              width: 480,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _MenuList(
                                    active: _active,
                                    onActivate: _setActive,
                                    onOpen: _open,
                                  ),
                                  const Spacer(),
                                  _QuitButton(onPressed: _quit),
                                ],
                              ),
                            ),
                            const SizedBox(width: 40),
                            Expanded(
                              child: _BriefingPanel(
                                option: option,
                                fillHeight: true,
                                onLaunch: () => _open(_active),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 32, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _MenuList(
                        active: _active,
                        onActivate: _setActive,
                        onOpen: _open,
                      ),
                      const SizedBox(height: 32),
                      _BriefingPanel(
                        option: option,
                        fillHeight: false,
                        onLaunch: () => _open(_active),
                      ),
                      const SizedBox(height: 32),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _QuitButton(onPressed: _quit),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: const Row(
        children: [
          Icon(Icons.hexagon_outlined, color: AppColors.accent, size: 28),
          SizedBox(width: 14),
          Text(
            'COMBAT HELPER',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.4,
              color: AppColors.text,
            ),
          ),
          Spacer(),
          Text(
            'V2',
            style: TextStyle(
              fontSize: 13,
              letterSpacing: 1,
              color: AppColors.textDim,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuList extends StatelessWidget {
  const _MenuList({
    required this.active,
    required this.onActivate,
    required this.onOpen,
  });

  final int active;
  final ValueChanged<int> onActivate;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const HudTitleBlock(eyebrow: 'Main Menu', title: 'Select Operation'),
        const SizedBox(height: 28),
        for (var i = 0; i < mainMenuOptions.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          HudMenuButton(
            number: i + 1,
            label: mainMenuOptions[i].label,
            active: i == active,
            onActivate: () => onActivate(i),
            onTap: () => onOpen(i),
          ),
        ],
      ],
    );
  }
}

class _BriefingPanel extends StatelessWidget {
  const _BriefingPanel({
    required this.option,
    required this.fillHeight,
    required this.onLaunch,
  });

  final MenuOption option;

  /// True when the panel has a fixed height (wide layout). The Launch row
  /// then sits at the bottom of the panel.
  final bool fillHeight;
  final VoidCallback onLaunch;

  @override
  Widget build(BuildContext context) {
    return HudFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('BRIEFING', style: HudText.sectionLabel),
          const SizedBox(height: 8),
          Text(option.label.toUpperCase(), style: HudText.panelTitle),
          const SizedBox(height: 8),
          // The wide layout sizes the panel with IntrinsicHeight, which
          // mis-measures a width-capped Text and overflows. The panel is
          // narrow enough there that the cap isn't needed.
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: fillHeight ? double.infinity : 560,
            ),
            child: Text(
              option.description,
              style: const TextStyle(
                fontSize: 16,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('WORKFLOW', style: HudText.sectionLabel),
          const SizedBox(height: 10),
          for (var i = 0; i < option.steps.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _StepRow(number: i + 1, text: option.steps[i]),
          ],
          if (fillHeight) const Spacer() else const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: onLaunch,
              style: FilledButton.styleFrom(
                minimumSize: const Size(140, 48),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(2)),
                ),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
              child: const Text('LAUNCH'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.panelRaised,
        border: Border.all(color: const Color(0xFF262D34)),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            color: AppColors.textSecondary,
            child: Text(
              '$number',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.background,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 15, color: AppColors.text),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuitButton extends StatelessWidget {
  const _QuitButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          minimumSize: const Size(120, 44),
          side: const BorderSide(color: AppColors.borderStrong),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(2)),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.6,
          ),
        ),
        child: const Text('QUIT'),
      ),
    );
  }
}
