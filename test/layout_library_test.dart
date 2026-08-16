import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ekodav_safety/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    savedCompanies.clear();
    savedLayouts.clear();
    globalFindings = [];
  });

  group('Rozpoznání PDF', () {
    test('PDF se pozná podle úvodní značky souboru', () {
      final pdf = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x34]);

      expect(looksLikePdf(pdf), isTrue);
    });

    test('PNG se za PDF nepovažuje', () {
      final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

      expect(looksLikePdf(png), isFalse);
    });

    test('příliš krátká data nespadnou', () {
      expect(looksLikePdf(Uint8List.fromList([0x25, 0x50])), isFalse);
      expect(looksLikePdf(Uint8List(0)), isFalse);
    });
  });

  group('Knihovna plánů', () {
    test('plán přežije uložení a načtení', () {
      final layout = SavedLayout(id: 'l1', name: 'Hala A', imageId: 'img-1');

      final restored = SavedLayout.fromJson(
        jsonDecode(jsonEncode(layout.toJson())) as Map<String, dynamic>,
      );

      expect(restored.id, 'l1');
      expect(restored.name, 'Hala A');
      expect(restored.imageId, 'img-1');
    });

    test('plán se dohledá podle obrázku', () {
      savedLayouts.add(SavedLayout(id: 'l1', name: 'Hala A', imageId: 'img-1'));
      savedLayouts.add(SavedLayout(id: 'l2', name: 'Hala B', imageId: 'img-2'));

      expect(findLayoutByImageId('img-2')?.name, 'Hala B');
      expect(findLayoutByImageId('neexistuje'), isNull);
      expect(findLayoutByImageId(null), isNull);
    });

    test('poškozený záznam plánu se načte s náhradními hodnotami', () {
      final restored = SavedLayout.fromJson({});

      expect(restored.name, 'Plán');
      expect(restored.id, isNotEmpty);
    });
  });

  group('Panel plánu při zadávání kontroly', () {
    testWidgets('panel je vidět nad tlačítkem pro zahájení kontroly', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: NewReportScreen()));
      await tester.pumpAndSettle();

      expect(find.text('PLÁN PROVOZOVNY'), findsOneWidget);
      expect(find.textContaining('Nahrát plán'), findsOneWidget);
    });

    testWidgets('bez uložených plánů je výběr z knihovny nedostupný', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: NewReportScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Vybrat z plánů (0)'), findsOneWidget);

      final button = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text('Vybrat z plánů (0)'),
          matching: find.byType(OutlinedButton),
        ),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('s uloženými plány jde výběr otevřít', (tester) async {
      savedLayouts.add(SavedLayout(id: 'l1', name: 'Výrobní hala', imageId: 'img-1'));

      await tester.pumpWidget(const MaterialApp(home: NewReportScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Vybrat z plánů (1)'), findsOneWidget);

      await tester.tap(find.text('Vybrat z plánů (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Vyberte plán'), findsOneWidget);
      expect(find.text('Výrobní hala'), findsOneWidget);
    });

    testWidgets('výběr plánu z knihovny ho označí jako vybraný', (tester) async {
      savedLayouts.add(SavedLayout(id: 'l1', name: 'Výrobní hala', imageId: 'img-1'));

      await tester.pumpWidget(const MaterialApp(home: NewReportScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Vybrat z plánů (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Výrobní hala'));
      await tester.pumpAndSettle();

      // Bez otevřeného úložiště chybí náhled, ale volba se musí projevit.
      expect(find.text('Odebrat'), findsOneWidget);
    });
  });
}
