// ============================================================================
// ============================================================================
// ============================================================================

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import '../models/live2d_settings.dart';
import 'live2d_log_service.dart';

class Live2DStorageService {
  static final Live2DStorageService _instance = Live2DStorageService._internal();
  factory Live2DStorageService() => _instance;
  Live2DStorageService._internal();

  static const String _tag = 'Storage';

  String? _currentFolderPath;
  String? _currentFolderUri;

  // === Getter ===
  String? get currentFolderPath => _currentFolderPath;
  String? get currentFolderUri => _currentFolderUri;
  bool get hasFolderSelected => _currentFolderPath != null;

  void restoreFromSettings(Live2DSettings settings) {
    _currentFolderPath = settings.dataFolderPath;
    _currentFolderUri = settings.dataFolderUri;
    
    if (_currentFolderPath != null) {
      live2dLog.info(_tag, '폴더 정보 복원됨', details: _currentFolderPath);
    }
  }

  /// 
  Future<String?> pickFolder() async {
    try {
      live2dLog.info(_tag, '폴더 선택 다이얼로그 열기...');

      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Live2D 모델 폴더 선택',
        lockParentWindow: true,
      );

      if (result == null) {
        live2dLog.info(_tag, '폴더 선택 취소됨');
        return null;
      }

      final dir = Directory(result);
      if (!await dir.exists()) {
        live2dLog.error(_tag, '선택한 폴더가 존재하지 않음', details: result);
        return null;
      }

      _currentFolderPath = result;
      _currentFolderUri = result;

      live2dLog.info(_tag, '폴더 선택 완료', details: result);
      
      final live2dFolder = Directory(path.join(result, 'Live2D'));
      if (await live2dFolder.exists()) {
        live2dLog.info(_tag, 'Live2D 하위 폴더 발견', details: live2dFolder.path);
      } else {
        live2dLog.warning(
          _tag, 
          'Live2D 하위 폴더 없음',
          details: '선택한 폴더에 Live2D 서브폴더가 없습니다. '
                   '모델들이 직접 이 폴더에 있거나, Live2D 폴더를 생성해주세요.',
        );
      }

      return result;
    } catch (e, stack) {
      live2dLog.error(
        _tag,
        '폴더 선택 실패',
        error: e,
        stackTrace: stack,
      );
      return null;
    }
  }

  Future<bool> validateCurrentFolder() async {
    if (_currentFolderPath == null) {
      return false;
    }

    try {
      final dir = Directory(_currentFolderPath!);
      final exists = await dir.exists();
      
      if (!exists) {
        live2dLog.warning(
          _tag,
          '저장된 폴더가 더 이상 존재하지 않음',
          details: _currentFolderPath,
        );
        _currentFolderPath = null;
        _currentFolderUri = null;
        return false;
      }

      return true;
    } catch (e) {
      live2dLog.error(_tag, '폴더 유효성 검증 실패', error: e);
      return false;
    }
  }

  void clearFolder() {
    _currentFolderPath = null;
    _currentFolderUri = null;
    live2dLog.info(_tag, '폴더 설정 초기화됨');
  }

  /// 
  Future<String?> getModelRootPath() async {
    if (_currentFolderPath == null) return null;

    final live2dFolder = Directory(path.join(_currentFolderPath!, 'Live2D'));
    if (await live2dFolder.exists()) {
      return live2dFolder.path;
    }

    return _currentFolderPath;
  }

  Future<bool> fileExists(String filePath) async {
    try {
      return await File(filePath).exists();
    } catch (e) {
      return false;
    }
  }

  Future<List<String>> listDirectory(String dirPath, {bool recursive = false}) async {
    final result = <String>[];
    
    try {
      final dir = Directory(dirPath);
      if (!await dir.exists()) {
        live2dLog.warning(_tag, '디렉토리 없음', details: dirPath);
        return result;
      }

      await for (final entity in dir.list(recursive: recursive, followLinks: false)) {
        result.add(entity.path);
      }

      live2dLog.debug(
        _tag,
        '디렉토리 내용 (${result.length}개)',
        details: dirPath,
      );
    } catch (e) {
      live2dLog.error(_tag, '디렉토리 나열 실패', error: e, details: dirPath);
    }

    return result;
  }

  String? get folderDisplayName {
    if (_currentFolderPath == null) return null;
    return path.basename(_currentFolderPath!);
  }
}
