import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ekodav_safety/main.dart';

/// Nejmenší platné PNG (1×1 px) – stačí k ověření dekódování rozměrů.
final Uint8List _pngPixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

Finding _finding({
  required int order,
  double? x,
  double? y,
  String severity = 'Vysoká',
}) =>
    Finding(
      id: newEntityId(),
      orderNumber: order,
      category: 'BOZP',
      severity: severity,
      description: 'Nález č. $order',
      locationDetail: 'Kotelna',
      timestamp: DateTime(2026, 8, 8),
      pinX: x,
      pinY: y,
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    savedCompanies.clear();
    globalFindings = [];
  });

  group('Poloha nálezu v plánu', () {
    test('nález bez souřadnic nemá polohu', () {
      expect(_finding(order: 1).hasPin, isFalse);
      expect(_finding(order: 1, x: 0.5).hasPin, isFalse);
      expect(_finding(order: 1, x: 0.5, y: 0.5).hasPin, isTrue);
    });

    test('souřadnice přežijí uložení a načtení', () {
      final json = _finding(order: 3, x: 0.4231, y: 0.7118).toJson(includePhotoBytes: false);
      final restored = Finding.fromJson(jsonDecode(jsonEncode(json)) as Map<String, dynamic>);

      expect(restored.pinX, closeTo(0.4231, 0.0001));
      expect(restored.pinY, closeTo(0.7118, 0.0001));
      expect(restored.hasPin, isTrue);
    });

    test('starší nález bez souřadnic se načte bez pádu', () {
      final legacy = {
        'id': 'f1',
        'orderNumber': 1,
        'category': 'BOZP',
        'severity': 'Vysoká',
        'description': 'Starý nález',
        'timestamp': '2026-08-08T10:00:00.000',
      };

      final restored = Finding.fromJson(legacy);

      expect(restored.hasPin, isFalse);
      expect(restored.pinX, isNull);
    });
  });

  group('Plán u provozovny', () {
    test('provozovna si pamatuje plán napříč uložením', () {
      final company = upsertSavedCompany(name: 'ACME a.s.')!;
      upsertSavedBranch(company, name: 'Hala A', layoutId: 'layout-1');

      final restored = SavedCompany.fromJson(company.toJson());

      expect(restored.branches.single.layoutId, 'layout-1');
      expect(restored.branches.single.hasLayout, isTrue);
    });

    test('provozovna bez plánu to hlásí', () {
      final company = upsertSavedCompany(name: 'ACME a.s.')!;
      upsertSavedBranch(company, name: 'Hala B');

      expect(company.branches.single.hasLayout, isFalse);
      expect(SavedCompany.fromJson(company.toJson()).branches.single.layoutId, isNull);
    });

    test('report si drží plán, ke kterému se puntíky vážou', () {
      final report = InspectionReport(
        id: 'r1',
        locationName: 'Hala A',
        date: DateTime(2026, 8, 8),
        findings: [_finding(order: 1, x: 0.2, y: 0.3)],
        layoutId: 'layout-1',
      );

      final restored = InspectionReport.fromJson(
        jsonDecode(jsonEncode(report.toJson(includePhotoBytes: false))) as Map<String, dynamic>,
      );

      expect(restored.layoutId, 'layout-1');
      expect(restored.findings.single.pinX, 0.2);
    });
  });

  group('Rozměry plánu', () {
    test('decodeImageSize přečte rozměry obrázku', () async {
      final size = await decodeImageSize(_pngPixel);

      expect(size, isNotNull);
      expect(size!.width, 1);
      expect(size.height, 1);
    });

    test('poškozený obrázek vrátí null místo pádu', () async {
      final size = await decodeImageSize(Uint8List.fromList([1, 2, 3, 4]));

      expect(size, isNull);
    });
  });

  group('Obrazovka plánu', () {
    testWidgets('ťuknutí do plánu vrátí poměrné souřadnice', (tester) async {
      LayoutTapResult? result;

      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await Navigator.push<LayoutTapResult>(
                context,
                MaterialPageRoute(
                  builder: (_) => LayoutPinScreen(
                    layoutBytes: _pngPixel,
                    findings: const [],
                    imageSize: const Size(100, 100),
                  ),
                ),
              );
            },
            child: const Text('otevřít'),
          ),
        ),
      ));

      await tester.tap(find.text('otevřít'));
      await tester.pumpAndSettle();

      // Plán 1:1 se vykreslí jako čtverec – ťukneme do jeho středu.
      final planRect = tester.getRect(find.byType(Image).first);
      await tester.tapAt(planRect.center);
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.isNewPin, isTrue);
      expect(result!.x, closeTo(0.5, 0.02));
      expect(result!.y, closeTo(0.5, 0.02));
    });

    testWidgets('ťuknutí do levého horního rohu dá souřadnice blízko nuly', (tester) async {
      LayoutTapResult? result;

      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await Navigator.push<LayoutTapResult>(
                context,
                MaterialPageRoute(
                  builder: (_) => LayoutPinScreen(
                    layoutBytes: _pngPixel,
                    findings: const [],
                    imageSize: const Size(100, 100),
                  ),
                ),
              );
            },
            child: const Text('otevřít'),
          ),
        ),
      ));

      await tester.tap(find.text('otevřít'));
      await tester.pumpAndSettle();

      final planRect = tester.getRect(find.byType(Image).first);
      await tester.tapAt(planRect.topLeft + const Offset(2, 2));
      await tester.pumpAndSettle();

      expect(result!.x, lessThan(0.05));
      expect(result!.y, lessThan(0.05));
    });

    testWidgets('existující nálezy se vykreslí jako očíslované puntíky', (tester) async {
      final findings = [
        _finding(order: 1, x: 0.2, y: 0.2),
        _finding(order: 2, x: 0.8, y: 0.6),
        _finding(order: 3), // bez polohy – v plánu být nemá
      ];

      await tester.pumpWidget(MaterialApp(
        home: LayoutPinScreen(
          layoutBytes: _pngPixel,
          findings: findings,
          imageSize: const Size(100, 100),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsNothing);
      expect(find.textContaining('V plánu: 2 nálezů'), findsOneWidget);
      expect(find.textContaining('bez polohy: 1'), findsOneWidget);
    });

    testWidgets('ťuknutí na puntík otevře daný nález místo zakládání nového', (tester) async {
      LayoutTapResult? result;
      final findings = [_finding(order: 7, x: 0.5, y: 0.5)];

      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await Navigator.push<LayoutTapResult>(
                context,
                MaterialPageRoute(
                  builder: (_) => LayoutPinScreen(
                    layoutBytes: _pngPixel,
                    findings: findings,
                    imageSize: const Size(100, 100),
                  ),
                ),
              );
            },
            child: const Text('otevřít'),
          ),
        ),
      ));

      await tester.tap(find.text('otevřít'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('7'));
      await tester.pumpAndSettle();

      expect(result!.isNewPin, isFalse);
      expect(result!.existingFinding!.orderNumber, 7);
    });
  });
}
