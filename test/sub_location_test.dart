import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ekodav_safety/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    subLocationHistory = {...kDefaultSubLocations};
  });

  group('Seznam míst / oblastí', () {
    test('addSubLocation přidá nové místo a ohlásí to', () {
      expect(addSubLocation('Kotelna'), isTrue);
      expect(subLocationHistory, contains('Kotelna'));
    });

    test('duplicitu nepřidá bez ohledu na velikost písmen a diakritiku', () {
      subLocationHistory = {};
      addSubLocation('Výrobna');

      expect(addSubLocation('VYROBNA'), isFalse);
      expect(addSubLocation('výrobna'), isFalse);
      expect(addSubLocation('  Výrobna  '), isFalse);
      expect(subLocationHistory, ['Výrobna']);
    });

    test('parseSubLocationList rozdělí řádky, čárky i středníky', () {
      final parsed = parseSubLocationList('Podlaha č. 1\nVýrobna, Kotelna; Sklad materiálu\n\n  ');

      expect(parsed, ['Podlaha č. 1', 'Výrobna', 'Kotelna', 'Sklad materiálu']);
    });

    test('hromadné přidání vrátí počet skutečně přidaných položek', () {
      subLocationHistory = {'Kotelna'};

      final added = addSubLocationsFromText('Podlaha č. 1\nKOTELNA\nVýrobna');

      expect(added, 2);
      expect(subLocationHistory, containsAll(['Kotelna', 'Podlaha č. 1', 'Výrobna']));
    });

    test('prázdné položky se ignorují', () {
      final added = addSubLocationsFromText('\n\n ,, ;; \n');

      expect(added, 0);
    });
  });

  group('Obrazovka Seznam míst / oblastí', () {
    testWidgets('uživatel přidá jedno místo', (tester) async {
      subLocationHistory = {};
      await tester.pumpWidget(const MaterialApp(home: SubLocationManagerScreen()));

      await tester.enterText(find.byType(TextField).first, 'Kotelna');
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(subLocationHistory, contains('Kotelna'));
      expect(find.text('MÍSTA V SEZNAMU (1):'), findsOneWidget);
    });

    testWidgets('uživatel nahraje celý seznam najednou', (tester) async {
      subLocationHistory = {};
      await tester.pumpWidget(const MaterialApp(home: SubLocationManagerScreen()));

      await tester.tap(find.text('NAHRÁT SEZNAM'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField).last,
        'Podlaha č. 1\nVýrobna\nKotelna',
      );
      await tester.tap(find.text('PŘIDAT VŠE'));
      await tester.pumpAndSettle();

      expect(subLocationHistory, ['Podlaha č. 1', 'Výrobna', 'Kotelna']);
      expect(find.text('MÍSTA V SEZNAMU (3):'), findsOneWidget);
    });

    testWidgets('odebrání místa ho vyřadí ze seznamu', (tester) async {
      subLocationHistory = {'Kotelna', 'Výrobna'};
      await tester.pumpWidget(const MaterialApp(home: SubLocationManagerScreen()));

      await tester.tap(find.byIcon(Icons.delete).first);
      await tester.pumpAndSettle();

      expect(subLocationHistory, ['Výrobna']);
    });

    testWidgets('přejmenování zachová pořadí položky', (tester) async {
      subLocationHistory = {'Kotelna', 'Výrobna', 'Sklad'};
      await tester.pumpWidget(const MaterialApp(home: SubLocationManagerScreen()));

      await tester.tap(find.byIcon(Icons.edit).at(1));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, 'Výrobní hala B');
      await tester.tap(find.text('ULOŽIT'));
      await tester.pumpAndSettle();

      expect(subLocationHistory.toList(), ['Kotelna', 'Výrobní hala B', 'Sklad']);
    });
  });

  group('Nabídka míst při zadávání nálezu', () {
    testWidgets('místa ze seznamu se nabízejí jako tlačítka a vyplní pole', (tester) async {
      subLocationHistory = {'Podlaha č. 1', 'Kotelna'};

      await tester.pumpWidget(const MaterialApp(
        home: InspectionModeScreen(locationName: 'Testovací hala'),
      ));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ActionChip, 'Podlaha č. 1'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'Kotelna'), findsOneWidget);

      await tester.tap(find.widgetWithText(ActionChip, 'Kotelna'));
      await tester.pumpAndSettle();

      final placeField = tester.widget<TextField>(
        find.ancestor(
          of: find.text('např. Sklad, Parkoviště, Dílna, Rampa...'),
          matching: find.byType(TextField),
        ),
      );
      expect(placeField.controller?.text, 'Kotelna');
    });

    testWidgets('prázdný seznam nabídne naplnění přes Upravit seznam', (tester) async {
      subLocationHistory = {};

      await tester.pumpWidget(const MaterialApp(
        home: InspectionModeScreen(locationName: 'Testovací hala'),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Seznam míst je prázdný'), findsOneWidget);
      expect(find.text('Upravit seznam'), findsOneWidget);
    });

    testWidgets('tlačítko Upravit seznam otevře správu míst', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: InspectionModeScreen(locationName: 'Testovací hala'),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Upravit seznam'));
      await tester.pumpAndSettle();

      expect(find.text('Seznam míst / oblastí'), findsOneWidget);
      expect(find.text('NAHRÁT SEZNAM'), findsOneWidget);
    });
  });
}
