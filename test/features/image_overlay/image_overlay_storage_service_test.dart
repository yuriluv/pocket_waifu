import 'dart:io';

import 'package:flutter_application_1/features/image_overlay/data/services/image_overlay_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  group('ImageOverlayStorageService', () {
    late Directory sandboxDir;

    setUp(() async {
      sandboxDir = await Directory.systemTemp.createTemp(
        'image_overlay_storage_test_',
      );
    });

    tearDown(() async {
      if (await sandboxDir.exists()) {
        await sandboxDir.delete(recursive: true);
      }
    });

    test('normalizes Android primary tree URIs to storage path', () {
      final normalized = ImageOverlayStorageService
          .normalizeFolderPathForTesting(
            'content://com.android.externalstorage.documents/tree/'
            'primary%3AOverlayPack/document/primary%3AOverlayPack',
          );

      expect(normalized, path.normalize('/storage/emulated/0/OverlayPack'));
    });

    test('normalizes file URIs to file paths', () {
      final normalized = ImageOverlayStorageService
          .normalizeFolderPathForTesting(
            'file:///storage/emulated/0/OverlayPack',
          );

      expect(normalized, path.normalize('/storage/emulated/0/OverlayPack'));
    });

    test('normalizes Android raw tree URIs to storage path', () {
      final normalized = ImageOverlayStorageService
          .normalizeFolderPathForTesting(
            'content://com.android.externalstorage.documents/tree/'
            'raw%3A%2Fstorage%2Femulated%2F0%2FOverlayPack',
          );

      expect(normalized, path.normalize('/storage/emulated/0/OverlayPack'));
    });

    test('reports missing folders explicitly', () async {
      final service = ImageOverlayStorageService.instance;
      service.restoreRootPath(path.join(sandboxDir.path, 'missing'));

      final characters = await service.scanCharacters();

      expect(characters, isEmpty);
      expect(service.lastScanIssue, ImageOverlayScanIssue.folderMissing);
    });

    test('surfaces permission issue for external storage roots without access', () async {
      final service = ImageOverlayStorageService.createForTesting(
        hasExternalStorageAccess: () async => false,
        isLikelyExternalStoragePath: (_) => true,
      );
      service.restoreRootPath(sandboxDir.path);

      final characters = await service.scanCharacters();

      expect(characters, isEmpty);
      expect(service.lastScanIssue, ImageOverlayScanIssue.permissionDenied);
    });

    test('scans simple folder characters and clears issues', () async {
      final characterDir = Directory(path.join(sandboxDir.path, 'Alice'));
      await characterDir.create(recursive: true);
      await File(path.join(characterDir.path, 'happy.png')).writeAsBytes(
        const <int>[1, 2, 3],
      );

      final service = ImageOverlayStorageService.instance;
      service.restoreRootPath(sandboxDir.path);

      final characters = await service.scanCharacters();

      expect(characters, hasLength(1));
      expect(characters.first.name, 'Alice');
      expect(characters.first.emotions.single.name, 'happy');
      expect(service.lastScanIssue, ImageOverlayScanIssue.none);
    });
  });
}
