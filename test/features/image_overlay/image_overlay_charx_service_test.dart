import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_application_1/features/image_overlay/data/services/image_overlay_charx_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  group('ImageOverlayCharxService', () {
    late Directory sandboxDir;
    late ImageOverlayCharxService service;

    setUp(() async {
      sandboxDir = await Directory.systemTemp.createTemp('charx_overlay_test_');
      service = ImageOverlayCharxService(
        cacheRootProvider: () async =>
            Directory(path.join(sandboxDir.path, 'cache')),
      );
    });

    tearDown(() async {
      if (await sandboxDir.exists()) {
        await sandboxDir.delete(recursive: true);
      }
    });

    test(
      'extracts mapped overlay assets and uses the charx filename',
      () async {
        final charxFile = File(path.join(sandboxDir.path, 'Aldebaran.charx'));
        await charxFile.writeAsBytes(
          _buildCharxBytes(
            assets: <Map<String, dynamic>>[
              {
                'type': 'icon',
                'name': 'iconx',
                'uri': 'embeded://assets/icon/image/1.png',
                'ext': 'png',
              },
              {
                'type': 'x-risu-asset',
                'name': 'Aldebaran_affectionate',
                'uri': 'embeded://assets/other/image/2.png',
                'ext': 'png',
              },
              {
                'type': 'x-risu-asset',
                'name': 'Aldebaran_smile',
                'uri': 'embedded://assets/other/image/3.png',
                'ext': 'png',
              },
            ],
            files: <String, List<int>>{
              'assets/icon/image/1.png': <int>[1, 2, 3],
              'assets/other/image/2.png': <int>[2, 2, 2],
              'assets/other/image/3.png': <int>[3, 3, 3],
            },
          ),
        );

        final character = await service.loadCharacter(charxFile);

        expect(character, isNotNull);
        expect(character!.name, 'Aldebaran');
        expect(
          character.emotions.map((emotion) => emotion.name).toList(),
          equals(<String>['Aldebaran_affectionate', 'Aldebaran_smile']),
        );
        expect(
          character.emotions.every(
            (emotion) => emotion.supportsRename == false,
          ),
          isTrue,
        );
        for (final emotion in character.emotions) {
          expect(await File(emotion.filePath).exists(), isTrue);
        }
      },
    );

    test('returns null when card.json has no overlay emotion assets', () async {
      final charxFile = File(path.join(sandboxDir.path, 'NoOverlay.charx'));
      await charxFile.writeAsBytes(
        _buildCharxBytes(
          assets: <Map<String, dynamic>>[
            {
              'type': 'icon',
              'name': 'iconx',
              'uri': 'embeded://assets/icon/image/1.png',
              'ext': 'png',
            },
          ],
          files: <String, List<int>>{
            'assets/icon/image/1.png': <int>[1, 2, 3],
          },
        ),
      );

      final character = await service.loadCharacter(charxFile);

      expect(character, isNull);
    });

    test('keeps duplicate uri mappings and accepts Card.json casing', () async {
      final charxFile = File(path.join(sandboxDir.path, 'Duplicate.charx'));
      await charxFile.writeAsBytes(
        _buildCharxBytes(
          cardPath: 'Card.json',
          assets: <Map<String, dynamic>>[
            {
              'type': 'x-risu-asset',
              'name': 'Duplicate_base',
              'uri': 'embeded://assets/other/image/7.png',
              'ext': 'png',
            },
            {
              'type': 'x-risu-asset',
              'name': 'Duplicate_alt',
              'uri': 'embeded://assets/other/image/7.png',
              'ext': 'png',
            },
          ],
          files: <String, List<int>>{
            'assets/other/image/7.png': <int>[7, 7, 7],
          },
        ),
      );

      final character = await service.loadCharacter(charxFile);

      expect(character, isNotNull);
      expect(
        character!.emotions.map((emotion) => emotion.name).toList(),
        equals(<String>['Duplicate_alt', 'Duplicate_base']),
      );
    });
  });
}

List<int> _buildCharxBytes({
  String cardPath = 'card.json',
  required List<Map<String, dynamic>> assets,
  required Map<String, List<int>> files,
}) {
  final archive = Archive();
  archive.add(
    ArchiveFile.string(
      cardPath,
      jsonEncode(<String, dynamic>{
        'spec': 'chara_card_v3',
        'spec_version': '3.0',
        'data': <String, dynamic>{'assets': assets},
      }),
    ),
  );

  files.forEach((archivePath, content) {
    archive.add(ArchiveFile.bytes(archivePath, content));
  });

  final encoded = ZipEncoder().encodeBytes(archive);
  return encoded;
}
