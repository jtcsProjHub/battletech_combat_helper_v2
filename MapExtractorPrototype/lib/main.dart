import 'package:flutter/material.dart';

import 'src/ui/extractor_screen.dart';

void main() => runApp(const MapExtractorApp());

class MapExtractorApp extends StatelessWidget {
  const MapExtractorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Map Extractor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF8D6E3F),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const ExtractorScreen(),
    );
  }
}
