import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/live2d/utils/folder_validator.dart';

void main() {
  group('FolderValidator', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('folder_validator_test');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('returns pathMissing when directory does not exist', () async {
      final nonExistentPath = '${tempDir.path}/not_exists';
      final (result, count) = await FolderValidator.validate(nonExistentPath, (_) async => []);
      
      expect(result, FolderValidationResult.pathMissing);
      expect(count, 0);
    });

    test('returns noModel when scan returns empty list', () async {
      final (result, count) = await FolderValidator.validate(tempDir.path, (_) async => []);
      
      expect(result, FolderValidationResult.noModel);
      expect(count, 0);
    });

    test('returns valid and count when scan returns models', () async {
      final mockModels = ['model1.model3.json', 'model2.model3.json'];
      
      final (result, count) = await FolderValidator.validate(
        tempDir.path,
        (_) async => mockModels,
      );
      
      expect(result, FolderValidationResult.valid);
      expect(count, 2);
    });
    
    test('returns permissionDenied when scan throws exception', () async {
      final (result, count) = await FolderValidator.validate(
        tempDir.path,
        (_) async => throw Exception('Permission Denied'),
      );
      
      expect(result, FolderValidationResult.permissionDenied);
      expect(count, 0);
    });
  });
}
