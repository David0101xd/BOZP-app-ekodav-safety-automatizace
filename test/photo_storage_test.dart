import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:ekodav_safety/main.dart';

Finding _finding({required String id, Uint8List? photo}) => Finding(
      id: id,
      orderNumber: 1,
      category: 'BOZP',
      severity: 'Vysoká',
      description: 'Blokovaný únikový východ',
      locationDetail: 'Sklad',
      legislation: 'Zákoník práce č. 262/2006 Sb.',
      photoBytes: photo,
      isPhotoTaken: photo != null,
      timestamp: DateTime(2026, 8, 8),
    );

void main() {
  group('Serializace nálezu bez fotografie v JSONu', () {
    final photo = Uint8List.fromList(List.filled(2048, 7));

    test('ve výchozím stavu se fotka do JSONu zakóduje', () {
      final json = _finding(id: 'f1', photo: photo).toJson();

      expect(json['photoBytes'], isNotNull);
      expect(base64Decode(json['photoBytes'] as String), photo);
    });

    test('s includePhotoBytes: false se fotka do JSONu vůbec nedostane', () {
      final json = _finding(id: 'f1', photo: photo).toJson(includePhotoBytes: false);

      expect(json.containsKey('photoBytes'), isFalse);
      // Zbytek nálezu zůstane kompletní.
      expect(json['description'], 'Blokovaný únikový východ');
      expect(json['isPhotoTaken'], isTrue);
      expect(json['legislation'], 'Zákoník práce č. 262/2006 Sb.');
    });

    test('JSON reportu bez fotek je řádově menší', () {
      final report = InspectionReport(
        id: 'r1',
        companyName: 'BENZINA s.r.o.',
        locationName: 'Hala A',
        date: DateTime(2026, 8, 8),
        findings: [
          _finding(id: 'f1', photo: photo),
          _finding(id: 'f2', photo: photo),
        ],
      );

      final withPhotos = jsonEncode(report.toJson()).length;
      final withoutPhotos = jsonEncode(report.toJson(includePhotoBytes: false)).length;

      expect(withoutPhotos, lessThan(withPhotos ~/ 4));
    });

    test('nález bez fotky projde oběma režimy', () {
      final withFlag = _finding(id: 'f1').toJson();
      final withoutFlag = _finding(id: 'f1').toJson(includePhotoBytes: false);

      expect(withFlag['photoBytes'], isNull);
      expect(withoutFlag.containsKey('photoBytes'), isFalse);
      expect(Finding.fromJson(withoutFlag).photoBytes, isNull);
      expect(Finding.fromJson(withoutFlag).isPhotoTaken, isFalse);
    });
  });

  group('Zpětná kompatibilita se starším uložením', () {
    test('report se snímky v JSONu se načte i po změně formátu', () {
      final photo = Uint8List.fromList([1, 2, 3, 4, 5]);
      final legacyJson = InspectionReport(
        id: 'r1',
        companyName: 'ACME a.s.',
        locationName: 'Kotelna',
        date: DateTime(2026, 8, 8),
        findings: [_finding(id: 'f1', photo: photo)],
      ).toJson();

      final restored = InspectionReport.fromJson(
        jsonDecode(jsonEncode(legacyJson)) as Map<String, dynamic>,
      );

      expect(restored.findings.single.photoBytes, photo);
      expect(restored.findings.single.isPhotoTaken, isTrue);
    });

    test('nový formát se načte s prázdnou fotkou, kterou doplní úložiště', () {
      final photo = Uint8List.fromList([9, 9, 9]);
      final newFormat = InspectionReport(
        id: 'r1',
        companyName: 'ACME a.s.',
        locationName: 'Kotelna',
        date: DateTime(2026, 8, 8),
        findings: [_finding(id: 'f1', photo: photo)],
      ).toJson(includePhotoBytes: false);

      final restored = InspectionReport.fromJson(
        jsonDecode(jsonEncode(newFormat)) as Map<String, dynamic>,
      );

      // Bajty v JSONu nejsou – doplní je až _attachPhotosFromStore().
      expect(restored.findings.single.photoBytes, isNull);
      expect(restored.findings.single.id, 'f1');
    });
  });

  group('Jednoznačná ID záznamů', () {
    test('newEntityId se neopakuje ani při rychlém volání po sobě', () {
      final ids = List.generate(500, (_) => newEntityId());

      expect(ids.toSet(), hasLength(500));
    });
  });

  group('Přehled zaplnění úložiště', () {
    test('bez otevřeného úložiště hlásí nulu místo pádu', () {
      final usage = photoStorageUsage();

      expect(usage.count, 0);
      expect(usage.bytes, 0);
      expect(isPhotoStoreReady, isFalse);
    });
  });
}
