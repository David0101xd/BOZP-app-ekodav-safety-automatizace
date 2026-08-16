import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ekodav_safety/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    savedCompanies.clear();
  });

  group('Popis chyby z ARES', () {
    test('vytáhne popis, který server poslal', () {
      final response = http.Response.bytes(
        utf8.encode(jsonEncode({'kod': 'VALIDACE', 'popis': 'Pole obchodniJmeno je povinné.'})),
        400,
      );

      expect(aresErrorDetail(response), 'Pole obchodniJmeno je povinné.');
    });

    test('poskládá popisy z chyb validace', () {
      final response = http.Response.bytes(
        utf8.encode(jsonEncode({
          'chyby': [
            {'kod': 'A', 'popis': 'Neplatná hodnota pocet.'},
            {'kod': 'B', 'popis': 'Neplatná hodnota start.'},
          ]
        })),
        400,
      );

      final detail = aresErrorDetail(response);

      expect(detail, contains('Neplatná hodnota pocet.'));
      expect(detail, contains('Neplatná hodnota start.'));
    });

    test('u odpovědi bez JSON vrátí zkrácené tělo', () {
      final response = http.Response('<html>Bad Request</html>', 400);

      expect(aresErrorDetail(response), contains('Bad Request'));
    });

    test('u prázdné odpovědi nespadne', () {
      expect(aresErrorDetail(http.Response('', 400)), isNotEmpty);
    });

    test('dlouhé tělo se zkrátí, aby hláška zůstala čitelná', () {
      final response = http.Response('x' * 500, 400);

      expect(aresErrorDetail(response).length, lessThan(210));
    });
  });

  group('Označení verze', () {
    testWidgets('domovská obrazovka vypisuje verzi sestavení', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pumpAndSettle();

      expect(find.textContaining('Verze aplikace:'), findsOneWidget);
    });

    testWidgets('domovská obrazovka ukazuje stav úložiště fotografií', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pumpAndSettle();

      // Bez otevřeného úložiště musí být vidět upozornění na náhradní režim.
      expect(find.textContaining('Náhradní režim úložiště'), findsOneWidget);
    });
  });

  group('Plán v seznamu provozoven', () {
    testWidgets('provozovna s plánem je označená štítkem', (tester) async {
      final company = upsertSavedCompany(name: 'ACME a.s.')!;
      upsertSavedBranch(company, name: 'Hala s plánem', layoutId: 'layout-1');
      upsertSavedBranch(company, name: 'Hala bez plánu');

      await tester.pumpWidget(const MaterialApp(home: CompanyManagerScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ACME a.s.'));
      await tester.pumpAndSettle();

      expect(find.text('Hala s plánem'), findsOneWidget);
      expect(find.text('Hala bez plánu'), findsOneWidget);
      // Štítek nese jen ta provozovna, která plán opravdu má.
      expect(find.text('PLÁN'), findsOneWidget);
    });
  });
}
