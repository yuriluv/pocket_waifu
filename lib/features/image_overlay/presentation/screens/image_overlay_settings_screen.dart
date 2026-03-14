import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/image_overlay_character.dart';
import '../../data/models/image_overlay_preset.dart';
import '../../data/models/image_overlay_settings.dart';
import '../../presentation/controllers/image_overlay_controller.dart';
import '../../../../providers/settings_provider.dart';

class ImageOverlaySettingsScreen extends StatelessWidget {
  const ImageOverlaySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ImageOverlayController(
        settingsProvider: context.read<SettingsProvider>(),
      )..initialize(),
      child: const _ImageOverlaySettingsBody(),
    );
  }
}

class _ImageOverlaySettingsBody extends StatelessWidget {
  const _ImageOverlaySettingsBody();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ImageOverlayController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('이미지 오버레이 설정'),
        actions: [
          IconButton(
            onPressed: controller.refreshCharacters,
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
          ),
        ],
      ),
      body: switch (controller.state) {
        ImageOverlayControllerState.loading ||
        ImageOverlayControllerState.initial => const Center(
          child: CircularProgressIndicator(),
        ),
        ImageOverlayControllerState.error => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(controller.errorMessage ?? '오류가 발생했습니다.'),
          ),
        ),
        ImageOverlayControllerState.ready => ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const _FolderSection(),
            const _CharacterSection(),
            const _DisplaySection(),
            if (controller.isAdvancedOverlayMode) const _HitboxSection(),
            const _TouchThroughSection(),
            if (controller.isAdvancedOverlayMode) const _PresetSection(),
            const _AdvancedSection(),
          ],
        ),
      },
    );
  }
}

class _FolderSection extends StatelessWidget {
  const _FolderSection();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ImageOverlayController>();
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('데이터 폴더', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '일반 캐릭터 폴더 구조와 .charx 파일이 함께 있는 폴더를 모두 지원합니다.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(
              controller.folderPath ?? '선택된 폴더 없음',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (controller.folderIssueMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                controller.folderIssueMessage!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: controller.pickFolder,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('폴더 선택'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: controller.hasFolderSelected
                      ? controller.clearFolder
                      : null,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('초기화'),
                ),
              ],
            ),
            if (controller.needsFolderAccessPermission) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: controller.requestFolderAccessPermission,
                    icon: const Icon(Icons.lock_open),
                    label: const Text('권한 다시 요청'),
                  ),
                  OutlinedButton.icon(
                    onPressed: controller.openFolderAccessSettings,
                    icon: const Icon(Icons.settings),
                    label: const Text('앱 설정 열기'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CharacterSection extends StatelessWidget {
  const _CharacterSection();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ImageOverlayController>();
    final selectedCharacter = controller.selectedCharacter;
    final selectedEmotion = controller.selectedEmotion;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('캐릭터/감정 이미지', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (controller.characters.isEmpty)
              const Text('캐릭터 폴더 또는 .charx 파일을 찾지 못했습니다.')
            else ...[
              DropdownButtonFormField<String>(
                initialValue: selectedCharacter?.folderPath,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: '캐릭터',
                ),
                items: controller.characters
                    .map(
                      (e) => DropdownMenuItem<String>(
                        value: e.folderPath,
                        child: Text(e.name),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) async {
                  if (value == null) return;
                  for (final character in controller.characters) {
                    if (character.folderPath == value) {
                      await controller.selectCharacter(character);
                      break;
                    }
                  }
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: selectedEmotion?.filePath,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: '감정 이미지',
                ),
                items:
                    (selectedCharacter?.emotions ??
                            const <ImageOverlayEmotion>[])
                        .map(
                          (e) => DropdownMenuItem<String>(
                            value: e.filePath,
                            child: Text(e.name),
                          ),
                        )
                        .toList(growable: false),
                onChanged: (value) async {
                  if (value == null || selectedCharacter == null) return;
                  for (final emotion in selectedCharacter.emotions) {
                    if (emotion.filePath == value) {
                      await controller.selectEmotion(emotion);
                      break;
                    }
                  }
                },
              ),
            ],
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: controller.settings.isEnabled,
              onChanged: controller.characters.isEmpty
                  ? null
                  : (enabled) => controller.setEnabled(enabled),
              title: const Text('오버레이 활성화'),
              subtitle: const Text('이미지 오버레이를 표시/숨김'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DisplaySection extends StatefulWidget {
  const _DisplaySection();

  @override
  State<_DisplaySection> createState() => _DisplaySectionState();
}

class _DisplaySectionState extends State<_DisplaySection> {
  late final TextEditingController _scaleController;

  @override
  void initState() {
    super.initState();
    final scale = context.read<ImageOverlayController>().settings.imageScale;
    _scaleController = TextEditingController(text: scale.toStringAsFixed(2));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scale = context.watch<ImageOverlayController>().settings.imageScale;
    final text = scale.toStringAsFixed(2);
    if (_scaleController.text != text) {
      _scaleController.text = text;
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _submitScale(String raw) {
    final normalized = raw.trim().replaceAll(',', '.');
    final parsed = double.tryParse(normalized);
    if (parsed == null) {
      return;
    }
    final clamped = parsed.clamp(
      ImageOverlaySettings.minScale,
      ImageOverlaySettings.maxScale,
    );
    context.read<ImageOverlayController>().setImageScale(clamped);
    _scaleController.text = clamped.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ImageOverlayController>();
    final settings = controller.settings;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('표시 설정', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('오버레이 방식', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('편집 오버레이'),
                  selected: controller.isAdvancedOverlayMode,
                  onSelected: (_) => controller.setOverlayInteractionMode(
                    ImageOverlaySettings.overlayModeAdvanced,
                  ),
                ),
                ChoiceChip(
                  label: const Text('기본 오버레이'),
                  selected: controller.isBasicOverlayMode,
                  onSelected: (_) => controller.setOverlayInteractionMode(
                    ImageOverlaySettings.overlayModeBasic,
                  ),
                ),
              ],
            ),
            if (controller.isBasicOverlayMode)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '기본 모드는 오버레이 내 편집 기능 없이 이미지 표시/터치스루 중심으로 동작합니다.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 10),
            Text('불투명도: ${(settings.opacity * 100).round()}%'),
            Slider(
              value: settings.opacity,
              min: 0,
              max: 1,
              divisions: 20,
              label: '${(settings.opacity * 100).round()}%',
              onChanged: controller.setOpacity,
            ),
            const SizedBox(height: 8),
            Text('크기 배율: ${settings.imageScale.toStringAsFixed(2)}x'),
            const SizedBox(height: 6),
            Row(
              children: [
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _scaleController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      suffixText: 'x',
                      isDense: true,
                    ),
                    onSubmitted: _submitScale,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => _submitScale(_scaleController.text),
                  child: const Text('적용'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HitboxSection extends StatelessWidget {
  const _HitboxSection();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ImageOverlayController>();
    final settings = controller.settings;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('히트박스', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: controller.hitboxEditMode,
              onChanged: settings.isEnabled
                  ? controller.setHitboxEditMode
                  : null,
              title: const Text('히트박스 편집 모드'),
              subtitle: const Text('오버레이에서 드래그/리사이즈로 직접 수정'),
            ),
            const SizedBox(height: 6),
            Text('가로 위치: ${(settings.positionX * 100).round()}%'),
            Slider(
              value: settings.positionX,
              min: 0,
              max: 1,
              divisions: 100,
              label: '${(settings.positionX * 100).round()}%',
              onChanged: (value) {
                controller.setOverlayPosition(value, settings.positionY);
              },
            ),
            Text('세로 위치: ${(settings.positionY * 100).round()}%'),
            Slider(
              value: settings.positionY,
              min: 0,
              max: 1,
              divisions: 100,
              label: '${(settings.positionY * 100).round()}%',
              onChanged: (value) {
                controller.setOverlayPosition(settings.positionX, value);
              },
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => controller.setOverlayPosition(0.0, 0.0),
                  child: const Text('좌상단'),
                ),
                OutlinedButton(
                  onPressed: () => controller.setOverlayPosition(0.5, 0.0),
                  child: const Text('상단 중앙'),
                ),
                OutlinedButton(
                  onPressed: () => controller.setOverlayPosition(1.0, 0.0),
                  child: const Text('우상단'),
                ),
                OutlinedButton(
                  onPressed: () => controller.setOverlayPosition(0.0, 1.0),
                  child: const Text('좌하단'),
                ),
                OutlinedButton(
                  onPressed: () => controller.setOverlayPosition(0.5, 1.0),
                  child: const Text('하단 중앙'),
                ),
                OutlinedButton(
                  onPressed: () => controller.setOverlayPosition(1.0, 1.0),
                  child: const Text('우하단'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TouchThroughSection extends StatefulWidget {
  const _TouchThroughSection();

  @override
  State<_TouchThroughSection> createState() => _TouchThroughSectionState();
}

class _TouchThroughSectionState extends State<_TouchThroughSection> {
  late final TextEditingController _alphaController;

  @override
  void initState() {
    super.initState();
    final alpha = context
        .read<ImageOverlayController>()
        .settings
        .touchThroughAlpha;
    _alphaController = TextEditingController(text: alpha.toString());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final alpha = context
        .watch<ImageOverlayController>()
        .settings
        .touchThroughAlpha;
    _alphaController.text = alpha.toString();
  }

  @override
  void dispose() {
    _alphaController.dispose();
    super.dispose();
  }

  void _submitAlpha(String value) {
    final parsed = int.tryParse(value);
    if (parsed == null) {
      return;
    }
    final clamped = parsed.clamp(0, 100).toInt();
    context.read<ImageOverlayController>().setTouchThroughAlpha(clamped);
    _alphaController.text = clamped.toString();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ImageOverlayController>();
    final settings = controller.settings;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('터치스루', style: Theme.of(context).textTheme.titleMedium),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: settings.touchThroughEnabled,
              onChanged: controller.setTouchThroughEnabled,
              title: const Text('터치스루 활성화'),
              subtitle: const Text('앱 외부에서는 터치 통과 + 반투명'),
            ),
            if (settings.touchThroughEnabled)
              Row(
                children: [
                  const Expanded(child: Text('배경 투명도')),
                  SizedBox(
                    width: 88,
                    child: TextField(
                      controller: _alphaController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        suffixText: '%',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: _submitAlpha,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _PresetSection extends StatelessWidget {
  const _PresetSection();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ImageOverlayController>();

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('히트박스 프리셋', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: () => _showSavePresetDialog(context, controller),
                  icon: const Icon(Icons.save),
                  label: const Text('현재 상태 저장'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _showPresetListDialog(context, controller),
                  icon: const Icon(Icons.list),
                  label: Text('프리셋 ${controller.presets.length}개'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSavePresetDialog(
    BuildContext context,
    ImageOverlayController controller,
  ) {
    final nameController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('프리셋 저장'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '프리셋 이름',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  return;
                }
                await controller.savePreset(name);
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('저장'),
            ),
          ],
        );
      },
    );
  }

  void _showPresetListDialog(
    BuildContext context,
    ImageOverlayController controller,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('히트박스 프리셋 목록'),
          content: SizedBox(
            width: double.maxFinite,
            child: controller.presets.isEmpty
                ? const Text('저장된 프리셋이 없습니다.')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: controller.presets.length,
                    itemBuilder: (context, index) {
                      final preset = controller.presets[index];
                      String linkedLabel = '없음';
                      if (preset.linkedCharacterFolder != null) {
                        for (final character in controller.characters) {
                          if (character.folderPath ==
                              preset.linkedCharacterFolder) {
                            linkedLabel = character.name;
                            break;
                          }
                        }
                      }
                      return ListTile(
                        title: Text(preset.name),
                        subtitle: Text(
                          '크기: ${preset.overlayWidth}x${preset.overlayHeight} · '
                          '위치: ${(preset.positionX * 100).round()}%, ${(preset.positionY * 100).round()}% · '
                          '배율: ${preset.imageScale.toStringAsFixed(2)}x · '
                          '연동: $linkedLabel',
                        ),
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            TextButton(
                              onPressed: () async {
                                await controller.loadPreset(preset);
                                if (context.mounted) {
                                  Navigator.pop(context);
                                }
                              },
                              child: const Text('적용'),
                            ),
                            IconButton(
                              onPressed: () =>
                                  _showLinkDialog(context, controller, preset),
                              icon: const Icon(Icons.link),
                              tooltip: '연동',
                            ),
                            IconButton(
                              onPressed: () =>
                                  controller.deletePreset(preset.id),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('닫기'),
            ),
          ],
        );
      },
    );
  }

  void _showLinkDialog(
    BuildContext context,
    ImageOverlayController controller,
    ImageOverlayPreset preset,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('프리셋 연동'),
          content: SizedBox(
            width: double.maxFinite,
            child: controller.characters.isEmpty
                ? const Text('연동 가능한 캐릭터 폴더가 없습니다.')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: controller.characters.length,
                    itemBuilder: (context, index) {
                      final character = controller.characters[index];
                      return ListTile(
                        title: Text(character.name),
                        subtitle: Text(character.folderPath),
                        onTap: () async {
                          await controller.linkPresetToCharacter(
                            preset.id,
                            character.folderPath,
                          );
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await controller.unlinkPreset(preset.id);
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('연동 해제'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('닫기'),
            ),
          ],
        );
      },
    );
  }
}

class _AdvancedSection extends StatelessWidget {
  const _AdvancedSection();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ImageOverlayController>();
    final selectedCharacter = controller.selectedCharacter;
    final emotions =
        selectedCharacter?.emotions ?? const <ImageOverlayEmotion>[];

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('고급 설정', style: Theme.of(context).textTheme.titleMedium),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: controller.settings.syncCharacterNameWithSession,
              onChanged: controller.setSyncCharacterNameWithSession,
              title: const Text('캐릭터 이름 자동 동기화'),
              subtitle: const Text('메인 세션 캐릭터 이름과 폴더명을 동기화'),
            ),
            const SizedBox(height: 8),
            Text('감정 이미지 목록', style: Theme.of(context).textTheme.titleSmall),
            if (emotions.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('선택된 캐릭터가 없거나 감정 이미지가 없습니다.'),
              )
            else
              ...emotions.map(
                (emotion) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(emotion.name),
                  subtitle: Text(emotion.filePath),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    tooltip: emotion.supportsRename
                        ? '이름 변경'
                        : 'CHARX 자동 추출 이미지는 이름 변경을 지원하지 않습니다.',
                    onPressed: emotion.supportsRename
                        ? () => _showRenameDialog(context, controller, emotion)
                        : null,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(
    BuildContext context,
    ImageOverlayController controller,
    ImageOverlayEmotion emotion,
  ) {
    final renameController = TextEditingController(text: emotion.name);
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('감정 이미지 이름 변경'),
          content: TextField(
            controller: renameController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '새 이름',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () async {
                final ok = await controller.renameEmotion(
                  emotion,
                  renameController.text,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ok ? '이름을 변경했습니다.' : '이름 변경에 실패했습니다.'),
                    ),
                  );
                }
              },
              child: const Text('저장'),
            ),
          ],
        );
      },
    );
  }
}
