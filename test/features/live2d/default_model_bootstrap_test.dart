import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_application_1/features/live2d/data/services/live2d_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Live2DStorageService default bootstrap', () {
    late Directory tempDocs;
    late String artifactRoot;

    setUp(() async {
      tempDocs = await Directory.systemTemp.createTemp('live2d_bootstrap_test');
      artifactRoot = path.join(Directory.current.path, 'artifacts', 'live2d', 'archetypes');
    });

    tearDown(() async {
      if (await tempDocs.exists()) {
        await tempDocs.delete(recursive: true);
      }
    });

    test('bootstraps archetypes and returns default model path on first run', () async {
      final service = Live2DStorageService.test(
        appDocumentDirectoryProvider: () async => tempDocs,
        assetStringLoader: (assetPath) async {
          final sourceFile = File(path.join(Directory.current.path, assetPath));
          return sourceFile.readAsString();
        },
        assetByteLoader: (assetPath) async {
          final sourceFile = File(path.join(Directory.current.path, assetPath));
          final bytes = await sourceFile.readAsBytes();
          return ByteData.view(Uint8List.fromList(bytes).buffer);
        },
      );

      final result = await service.bootstrapDefaultModelRootIfNeeded();

      expect(result.bootstrapped, isTrue);
      expect(result.failure, isNull);
      expect(result.rootFolderPath, isNotNull);
      expect(
        result.defaultModelRelativePath,
        'c_full_ready/c_full_ready.model3.json',
      );

      final modelRootPath = await service.getModelRootPath();
      expect(modelRootPath, isNotNull);

      final archetypeA = Directory(path.join(modelRootPath!, 'a_requires_preprocess'));
      final archetypeB = Directory(path.join(modelRootPath, 'b_partial_parameters'));
      final archetypeC = Directory(path.join(modelRootPath, 'c_full_ready'));

      expect(await archetypeA.exists(), isTrue);
      expect(await archetypeB.exists(), isTrue);
      expect(await archetypeC.exists(), isTrue);

      final selectedModel = File(
        path.join(modelRootPath, result.defaultModelRelativePath!),
      );
      expect(await selectedModel.exists(), isTrue);
    });

    test('returns structured failure and keeps recoverable state on missing asset', () async {
      final service = Live2DStorageService.test(
        appDocumentDirectoryProvider: () async => tempDocs,
        assetStringLoader: (assetPath) async {
          final sourceFile = File(path.join(Directory.current.path, assetPath));
          return sourceFile.readAsString();
        },
        assetByteLoader: (assetPath) async {
          if (assetPath.endsWith('b_partial_parameters/b_partial_parameters.moc3')) {
            throw FlutterError('missing bundled asset');
          }
          final sourceFile = File(path.join(Directory.current.path, assetPath));
          final bytes = await sourceFile.readAsBytes();
          return ByteData.view(Uint8List.fromList(bytes).buffer);
        },
      );

      final result = await service.bootstrapDefaultModelRootIfNeeded();

      expect(result.bootstrapped, isFalse);
      expect(result.failure, DefaultModelBootstrapFailure.missingAsset);

      final bootstrappedRoot = Directory(path.join(tempDocs.path, 'live2d_bootstrap'));
      expect(await bootstrappedRoot.exists(), isFalse);
      expect(service.currentFolderPath, isNull);
      expect(service.hasFolderSelected, isFalse);
      expect(Directory(artifactRoot).existsSync(), isTrue);
    });
  });
}
