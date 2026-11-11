import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map_extractor_prototype/main.dart';

void main() {
  testWidgets('app starts on the empty extractor screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    await tester.pumpWidget(const MapExtractorApp());
    expect(find.text('Map extractor'), findsOneWidget);
    expect(find.text('Hex 0101'), findsNothing);
    await tester.tapAt(const Offset(700, 200));
    await tester.pump();
  });
}
