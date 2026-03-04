import 'dart:async';

import '../../live2d/data/services/live2d_native_bridge.dart';
import '../data/models/image_overlay_settings.dart';
import '../data/services/image_overlay_native_bridge.dart';
import '../data/services/image_overlay_storage_service.dart';

class ImageOverlayDirectiveResult {
  const ImageOverlayDirectiveResult({
    required this.cleanedText,
    required this.errors,
  });

  final String cleanedText;
  final List<String> errors;
}

class ImageOverlayDirectiveService {
  ImageOverlayDirectiveService._();

  static final ImageOverlayDirectiveService instance =
      ImageOverlayDirectiveService._();

  final Live2DNativeBridge _live2dBridge = Live2DNativeBridge();
  final ImageOverlayNativeBridge _imageBridge = ImageOverlayNativeBridge.instance;
  final ImageOverlayStorageService _storage = ImageOverlayStorageService.instance;

  static final RegExp _blockRegex = RegExp(
    r'<overlay>([\s\S]*?)</overlay>',
    caseSensitive: false,
  );

  static final RegExp _inlineRegex = RegExp(
    r'\[(img_move|img_emotion):([^\]]+)\]',
    caseSensitive: false,
  );

  Future<ImageOverlayDirectiveResult> processAssistantOutput(
    String text,
  ) async {
    final errors = <String>[];
    final blockMatches = _blockRegex.allMatches(text).toList(growable: false);
    final inlineMatches = _inlineRegex.allMatches(text).toList(growable: false);
    if (blockMatches.isEmpty && inlineMatches.isEmpty) {
      return ImageOverlayDirectiveResult(cleanedText: text, errors: errors);
    }

    for (final match in blockMatches) {
      final block = match.group(1) ?? '';
      try {
        await _runBlock(block);
      } catch (e) {
        errors.add(e.toString());
      }
    }

    for (final match in inlineMatches) {
      try {
        await _runInline(match.group(1) ?? '', match.group(2) ?? '');
      } catch (e) {
        errors.add(e.toString());
      }
    }

    final cleaned = text
        .replaceAll(_blockRegex, '')
        .replaceAll(_inlineRegex, '')
        .trim();
    return ImageOverlayDirectiveResult(cleanedText: cleaned, errors: errors);
  }

  Future<void> _runBlock(String block) async {
    final commandRegex = RegExp(
      r'<(move|emotion|wait)\b([^/>]*)/?>',
      caseSensitive: false,
    );
    final commands = commandRegex.allMatches(block).toList(growable: false);
    for (final command in commands) {
      final tag = (command.group(1) ?? '').toLowerCase();
      final attrs = _parseXmlAttrs(command.group(2) ?? '');
      await _execute(tag, attrs);
    }
  }

  Future<void> _runInline(String tag, String payload) async {
    final attrs = _parseInlineAttrs(payload);
    await _execute(tag.toLowerCase(), attrs);
  }

  Future<void> _execute(String tag, Map<String, String> attrs) async {
    final settings = await ImageOverlaySettings.load();
    if (!settings.isEnabled) {
      return;
    }

    final delayMs = int.tryParse(attrs['delay'] ?? '') ?? 0;
    if (delayMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: delayMs));
    }

    switch (tag) {
      case 'move':
      case 'img_move':
        await _runMove(attrs);
        break;
      case 'emotion':
      case 'img_emotion':
        await _runEmotion(attrs, settings);
        break;
      case 'wait':
        final ms = int.tryParse(attrs['ms'] ?? attrs['duration'] ?? '');
        if (ms != null && ms > 0) {
          await Future<void>.delayed(Duration(milliseconds: ms));
        }
        break;
    }
  }

  Future<void> _runMove(Map<String, String> attrs) async {
    final x = int.tryParse(attrs['x'] ?? '');
    final y = int.tryParse(attrs['y'] ?? '');
    if (x == null || y == null) {
      return;
    }
    await _live2dBridge.setPosition(x.toDouble(), y.toDouble());
  }

  Future<void> _runEmotion(
    Map<String, String> attrs,
    ImageOverlaySettings settings,
  ) async {
    final emotion = (attrs['name'] ?? attrs['emotion'] ?? '').trim();
    if (emotion.isEmpty) {
      return;
    }

    final characterFolder = settings.selectedCharacterFolder;
    if (characterFolder == null) {
      return;
    }

    _storage.restoreRootPath(settings.dataFolderPath);
    final characters = await _storage.scanCharacters();
    for (final character in characters) {
      if (character.folderPath != characterFolder) {
        continue;
      }
      for (final item in character.emotions) {
        if (item.name.toLowerCase() == emotion.toLowerCase()) {
          await _imageBridge.setOverlayMode('image');
          await _imageBridge.loadOverlayImage(item.filePath);
          return;
        }
      }
    }
  }

  Map<String, String> _parseXmlAttrs(String raw) {
    final out = <String, String>{};
    final regex = RegExp(r'(\w+)\s*=\s*"([^"]*)"');
    for (final match in regex.allMatches(raw)) {
      final key = match.group(1);
      final value = match.group(2);
      if (key != null && value != null) {
        out[key] = value;
      }
    }
    return out;
  }

  Map<String, String> _parseInlineAttrs(String raw) {
    final out = <String, String>{};
    final parts = raw.split(',');
    for (final part in parts) {
      final idx = part.indexOf('=');
      if (idx <= 0) {
        continue;
      }
      final key = part.substring(0, idx).trim();
      final value = part.substring(idx + 1).trim();
      if (key.isNotEmpty && value.isNotEmpty) {
        out[key] = value;
      }
    }
    return out;
  }
}
