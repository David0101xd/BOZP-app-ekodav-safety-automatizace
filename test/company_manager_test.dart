import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ekodav_safety/main.dart';

/// Najde text uvnitř otevřeného výběrového panelu – na obrazovce za ním
/// mohou být stejné názvy (nedávné firmy, historie reportů).
Finder _inSheet(String text) => find.descendant(
      of: find.byType(DraggableScrollableSheet),
      matching: find.text(text),
    );

/// Vrátí text z controlleru pole podle jeho popisku (labelText / hintText).
String _fieldText(WidgetTester tester, String label) {
  final field = tester.widget<TextField>(
    find.ancestor(
      of: find.text(label),
      matching: find.byType(TextField),
    ),
  );
  return field.controller?.text ?? '';
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    savedCompanies.clear();
  });

  group('Datový model firem a provozoven', () {
    test('upsertSavedCompany založí firmu a přidá provozovnu', () {
      upsertSavedCompany(
        name: 'BENZINA s.r.o.',
        ico: '12345678',
        address: 'Milevská 2095/5, Praha 4',
        branchName: 'Skladová hala A - Brno',
      );

      expect(savedCompanies, hasLength(1));
      expect(savedCompanies.first.branches, hasLength(1));
      expect(savedCompanies.first.branches.first.name, 'Skladová hala A - Brno');
    });

    test('opakovaný upsert stejné firmy nevytvoří duplicitu, jen přidá provozovnu', () {
      upsertSavedCompany(name: 'BENZINA s.r.o.', ico: '12345678', branchName: 'Hala A');
      upsertSavedCompany(name: 'BENZINA s.r.o.', ico: '12345678', branchName: 'Hala B');

      expect(savedCompanies, hasLength(1));
      expect(savedCompanies.first.branches.map((b) => b.name), ['Hala A', 'Hala B']);
    });

    test('firma se páruje podle IČO i při jiném zápisu názvu', () {
      upsertSavedCompany(name: 'Benzina', ico: '12345678');
      upsertSavedCompany(name: 'BENZINA s.r.o.', ico: '12345678', address: 'Praha 4');

      expect(savedCompanies, hasLength(1));
      expect(savedCompanies.first.name, 'BENZINA s.r.o.');
      expect(savedCompanies.first.address, 'Praha 4');
    });

    test('provozovna se nepřidá dvakrát (shoda bez ohledu na diakritiku a velikost písmen)', () {
      final company = upsertSavedCompany(name: 'Test s.r.o.')!;
      upsertSavedBranch(company, name: 'Skladová hala');
      upsertSavedBranch(company, name: 'SKLADOVA HALA', address: 'Brno');

      expect(company.branches, hasLength(1));
      expect(company.branches.first.address, 'Brno');
    });

    test('firma se serializuje a načte včetně provozoven', () {
      final company = upsertSavedCompany(name: 'Test s.r.o.', ico: '111')!;
      upsertSavedBranch(company, name: 'Provozovna 1', address: 'Brno', note: 'brána č. 2');

      final restored = SavedCompany.fromJson(company.toJson());

      expect(restored.name, 'Test s.r.o.');
      expect(restored.branches, hasLength(1));
      expect(restored.branches.first.name, 'Provozovna 1');
      expect(restored.branches.first.note, 'brána č. 2');
    });

    test('starší uložená data bez provozoven se načtou s prázdným seznamem', () {
      final restored = SavedCompany.fromJson({
        'id': '1',
        'name': 'Stará firma',
        'ico': '999',
        'address': 'Praha',
      });

      expect(restored.branches, isEmpty);
    });
  });

  group('Obrazovka Správa firem a provozoven', () {
    testWidgets('uživatel přidá firmu a k ní provozovnu', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: CompanyManagerScreen()));

      // Přidání firmy přes tlačítko PŘIDAT FIRMU.
      await tester.tap(find.text('PŘIDAT FIRMU'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'ACME a.s.');
      await tester.enterText(find.byType(TextField).at(1), '87654321');
      await tester.enterText(find.byType(TextField).at(2), 'Praha 1');
      await tester.tap(find.text('ULOŽIT FIRMU'));
      await tester.pumpAndSettle();

      expect(savedCompanies, hasLength(1));
      expect(find.text('ACME a.s.'), findsOneWidget);

      // Rozkliknutí firmy a přidání provozovny.
      await tester.tap(find.text('ACME a.s.'));
      await tester.pumpAndSettle();

      expect(find.text('Tato firma zatím nemá žádné provozovny.'), findsOneWidget);

      await tester.tap(find.text('Přidat provozovnu'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'Sklad Ostrava');
      await tester.tap(find.text('ULOŽIT PROVOZOVNU'));
      await tester.pumpAndSettle();

      expect(savedCompanies.first.branches.map((b) => b.name), ['Sklad Ostrava']);
      expect(find.text('Sklad Ostrava'), findsOneWidget);
    });

    testWidgets('smazání firmy vyžaduje potvrzení', (tester) async {
      final company = upsertSavedCompany(name: 'Ke smazání s.r.o.')!;
      upsertSavedBranch(company, name: 'Provozovna X');

      await tester.pumpWidget(const MaterialApp(home: CompanyManagerScreen()));

      await tester.tap(find.text('Ke smazání s.r.o.'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Smazat firmu'));
      await tester.pumpAndSettle();

      // Zrušení potvrzení firmu zachová.
      await tester.tap(find.text('Zrušit'));
      await tester.pumpAndSettle();
      expect(savedCompanies, hasLength(1));

      await tester.tap(find.text('Smazat firmu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SMAZAT'));
      await tester.pumpAndSettle();

      expect(savedCompanies, isEmpty);
    });
  });

  group('Výběr firmy a provozovny při zadávání kontroly', () {
    testWidgets('rozkliknutí firmy a výběr provozovny předvyplní formulář', (tester) async {
      final company = upsertSavedCompany(
        name: 'BENZINA s.r.o.',
        ico: '12345678',
        address: 'Milevská 2095/5, Praha 4',
      )!;
      upsertSavedBranch(company, name: 'Skladová hala A - Brno', address: 'Průmyslová 12, Brno');

      await tester.pumpWidget(const MaterialApp(home: NewReportScreen()));

      await tester.tap(find.text('VYBRAT Z MÝCH FIREM'));
      await tester.pumpAndSettle();

      // V panelu je firma i počet jejích provozoven.
      expect(find.textContaining('Provozoven: 1'), findsOneWidget);

      // Rozkliknutí firmy odkryje její provozovny.
      await tester.tap(_inSheet('BENZINA s.r.o.'));
      await tester.pumpAndSettle();

      expect(find.text('Použít jen firmu (bez provozovny)'), findsOneWidget);

      await tester.tap(_inSheet('Skladová hala A - Brno'));
      await tester.pumpAndSettle();

      expect(_fieldText(tester, 'Název firmy'), 'BENZINA s.r.o.');
      expect(_fieldText(tester, 'IČO'), '12345678');
      expect(_fieldText(tester, 'Sídlo / Adresa'), 'Milevská 2095/5, Praha 4');
      expect(
        _fieldText(tester, 'např. Čerpací stanice, hala, budova...'),
        'Skladová hala A - Brno',
      );
    });

    testWidgets('volba "jen firma" nechá pole s lokací prázdné', (tester) async {
      final company = upsertSavedCompany(name: 'ACME a.s.', ico: '87654321')!;
      upsertSavedBranch(company, name: 'Sklad Ostrava');

      await tester.pumpWidget(const MaterialApp(home: NewReportScreen()));

      await tester.tap(find.text('VYBRAT Z MÝCH FIREM'));
      await tester.pumpAndSettle();
      await tester.tap(_inSheet('ACME a.s.'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Použít jen firmu (bez provozovny)'));
      await tester.pumpAndSettle();

      expect(_fieldText(tester, 'Název firmy'), 'ACME a.s.');
      expect(_fieldText(tester, 'např. Čerpací stanice, hala, budova...'), '');
    });

    testWidgets('bez uložených firem panel nabídne správu firem', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: NewReportScreen()));

      await tester.tap(find.text('VYBRAT Z MÝCH FIREM'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Zatím nemáte žádné uložené firmy.'), findsOneWidget);
      expect(find.text('Spravovat'), findsOneWidget);
    });
  });
}
