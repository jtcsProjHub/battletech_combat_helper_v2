import 'package:flutter/material.dart';

import 'screens/lance_builder_screen.dart';
import 'screens/main_menu_screen.dart';
import 'screens/placeholder_screen.dart';

/// Named routes for the app. Use these constants with Navigator.pushNamed.
class AppRoutes {
  AppRoutes._();

  static const mainMenu = '/';
  static const lanceBuilder = '/lance-builder';
  static const newSkirmish = '/skirmish/new';
  static const loadSkirmish = '/skirmish/load';

  static Map<String, WidgetBuilder> get table => {
        mainMenu: (_) => const MainMenuScreen(),
        lanceBuilder: (_) => const LanceBuilderScreen(),
        newSkirmish: (_) => const PlaceholderScreen(title: 'New Skirmish'),
        loadSkirmish: (_) => const PlaceholderScreen(title: 'Load Skirmish'),
      };
}
