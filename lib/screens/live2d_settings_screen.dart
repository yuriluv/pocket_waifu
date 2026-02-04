// ============================================================================
// Live2D 설정 화면 (Live2D Settings Screen)
// ============================================================================
// 이 화면에서 Live2D 오버레이 관련 설정을 관리합니다.
// 
// 주요 기능:
// - 권한 상태 표시 및 요청 (저장소, 오버레이)
// - 외부 저장소의 모델 목록 표시
// - 모델 선택
// - 오버레이 ON/OFF 토글
// - 오버레이 크기 조절 (0.5x ~ 3.0x)
// ============================================================================

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/live2d_service.dart';
import '../services/overlay_service.dart';
import '../services/local_server_service.dart';

class Live2DSettingsScreen extends StatefulWidget {
  const Live2DSettingsScreen({super.key});

  @override
  State<Live2DSettingsScreen> createState() => _Live2DSettingsScreenState();
}

class _Live2DSettingsScreenState extends State<Live2DSettingsScreen> {
  // === 서비스 인스턴스 ===
  final Live2DService _live2dService = Live2DService();
  final OverlayService _overlayService = OverlayService();
  final LocalServerService _serverService = LocalServerService();

  // === 상태 변수 ===
  bool _isLoading = true;
  bool _hasStoragePermission = false;
  bool _hasOverlayPermission = false;
  bool _isServerRunning = false;
  String? _modelFolderPath;  // 사용자가 선택한 모델 폴더 경로
  List<Live2DModel> _models = [];
  String? _selectedModelPath;
  double _overlaySize = 1.0;
  bool _overlayEnabled = false;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  /// 화면 초기화
  Future<void> _initializeScreen() async {
    setState(() => _isLoading = true);

    try {
      // 권한 상태 확인
      final permissions = await _overlayService.checkAllPermissions();
      _hasStoragePermission = permissions['storage'] ?? false;
      _hasOverlayPermission = permissions['overlay'] ?? false;

      // 서버 상태 확인
      _isServerRunning = _serverService.isRunning;

      // Live2D 서비스 초기화
      await _live2dService.initialize();
      _modelFolderPath = _live2dService.live2dRootPath;
      _models = _live2dService.models;
      _selectedModelPath = _live2dService.selectedModelPath;

      // 오버레이 설정 불러오기
      _overlaySize = _live2dService.overlaySize;
      _overlayEnabled = _live2dService.overlayEnabled;
    } catch (e) {
      debugPrint('[Live2DSettings] 초기화 오류: $e');
    }

    setState(() => _isLoading = false);
  }

  /// 폴더 선택 (file_picker 사용)
  Future<void> _selectModelFolder() async {
    try {
      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Live2D 모델 폴더 선택',
      );
      
      if (result != null) {
        setState(() => _isLoading = true);
        
        // 새 폴더 경로 설정
        await _live2dService.setModelFolderPath(result);
        
        setState(() {
          _modelFolderPath = result;
          _models = _live2dService.models;
          _selectedModelPath = null; // 폴더 변경 시 선택 초기화
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('폴더 선택됨: $result\n${_models.length}개의 모델 발견'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[Live2DSettings] 폴더 선택 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('폴더 선택 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 저장소 권한 요청
  Future<void> _requestStoragePermission() async {
    final granted = await _overlayService.requestStoragePermission();
    
    setState(() {
      _hasStoragePermission = granted;
    });

    if (!granted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('저장소 권한이 필요합니다. 설정에서 권한을 허용해주세요.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  /// 오버레이 권한 요청
  Future<void> _requestOverlayPermission() async {
    final granted = await _overlayService.requestOverlayPermission();
    
    setState(() {
      _hasOverlayPermission = granted;
    });

    if (!granted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('오버레이 권한이 필요합니다. 설정에서 권한을 허용해주세요.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  /// 모델 목록 새로고침
  Future<void> _refreshModels() async {
    if (_modelFolderPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('먼저 모델 폴더를 선택해주세요.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    await _live2dService.scanModels();
    
    setState(() {
      _models = _live2dService.models;
      _isLoading = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_models.length}개의 모델을 찾았습니다.'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// 모델 선택
  Future<void> _selectModel(String? relativePath) async {
    await _live2dService.selectModel(relativePath);
    setState(() {
      _selectedModelPath = relativePath;
    });
  }

  /// 오버레이 크기 변경
  Future<void> _setOverlaySize(double size) async {
    await _live2dService.setOverlaySize(size);
    _overlayService.setSizeMultiplier(size);
    setState(() {
      _overlaySize = size;
    });
  }

  /// 오버레이 토글
  Future<void> _toggleOverlay(bool enabled) async {
    if (enabled) {
      // 오버레이 활성화 조건 확인
      if (!_hasOverlayPermission) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('오버레이 권한이 필요합니다.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (_modelFolderPath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('먼저 모델 폴더를 선택해주세요.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      if (_selectedModelPath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('먼저 모델을 선택해주세요.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // 서버 시작 (필요시)
      if (!_serverService.isRunning) {
        debugPrint('[Live2DSettings] 서버 시작 - 모델 폴더: $_modelFolderPath');
        await _serverService.startServer(_modelFolderPath!);
        setState(() => _isServerRunning = true);
      }

      // 오버레이 표시
      final success = await _overlayService.showOverlay();
      if (success) {
        // 모델 URL을 오버레이로 전송
        debugPrint('[Live2DSettings] === 모델 URL 생성 ===');
        debugPrint('[Live2DSettings] 선택된 모델 경로: $_selectedModelPath');
        debugPrint('[Live2DSettings] 모델 폴더 경로: $_modelFolderPath');
        
        final webViewUrl = _serverService.getWebViewUrl(_selectedModelPath!);
        debugPrint('[Live2DSettings] 생성된 WebView URL: $webViewUrl');
        
        await _overlayService.sendDataToOverlay({
          'action': 'loadModel',
          'url': webViewUrl,
        });
      }
    } else {
      // 오버레이 숨기기
      await _overlayService.hideOverlay();
    }

    await _live2dService.setOverlayEnabled(enabled);
    setState(() {
      _overlayEnabled = enabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live2D 설정'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _modelFolderPath != null ? _refreshModels : null,
            tooltip: '모델 목록 새로고침',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // === 권한 섹션 ===
                  _buildSectionTitle('권한 설정', Icons.security),
                  const SizedBox(height: 8),
                  _buildPermissionCard(),

                  const SizedBox(height: 24),

                  // === 폴더 선택 섹션 ===
                  _buildSectionTitle('모델 폴더', Icons.folder_open),
                  const SizedBox(height: 8),
                  _buildFolderSelectionCard(),

                  const SizedBox(height: 24),

                  // === 오버레이 컨트롤 섹션 ===
                  _buildSectionTitle('오버레이 설정', Icons.layers),
                  const SizedBox(height: 8),
                  _buildOverlayControlCard(),

                  const SizedBox(height: 24),

                  // === 모델 목록 섹션 ===
                  _buildSectionTitle('모델 목록', Icons.face),
                  const SizedBox(height: 8),
                  _buildModelListCard(),

                  const SizedBox(height: 24),

                  // === 안내 섹션 ===
                  _buildInfoCard(),
                ],
              ),
            ),
    );
  }

  /// 섹션 제목 위젯
  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }

  /// 권한 설정 카드
  Widget _buildPermissionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 저장소 권한
            _buildPermissionTile(
              title: '저장소 접근',
              subtitle: '외부 저장소의 Live2D 모델을 읽습니다',
              isGranted: _hasStoragePermission,
              onRequest: _requestStoragePermission,
            ),
            const Divider(),
            // 오버레이 권한
            _buildPermissionTile(
              title: '다른 앱 위에 표시',
              subtitle: '오버레이 윈도우를 표시합니다',
              isGranted: _hasOverlayPermission,
              onRequest: _requestOverlayPermission,
            ),
          ],
        ),
      ),
    );
  }

  /// 권한 타일 위젯
  Widget _buildPermissionTile({
    required String title,
    required String subtitle,
    required bool isGranted,
    required VoidCallback onRequest,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        isGranted ? Icons.check_circle : Icons.error,
        color: isGranted ? Colors.green : Colors.red,
        size: 28,
      ),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).textTheme.bodySmall?.color,
        ),
      ),
      trailing: isGranted
          ? const Chip(
              label: Text('허용됨'),
              backgroundColor: Colors.green,
              labelStyle: TextStyle(color: Colors.white, fontSize: 12),
            )
          : ElevatedButton(
              onPressed: onRequest,
              child: const Text('권한 요청'),
            ),
    );
  }

  /// 폴더 선택 카드
  Widget _buildFolderSelectionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 현재 폴더 경로 표시
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '현재 선택된 폴더',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _modelFolderPath ?? '선택된 폴더 없음',
                        style: TextStyle(
                          fontSize: 12,
                          color: _modelFolderPath != null 
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).textTheme.bodySmall?.color,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _selectModelFolder,
                  icon: const Icon(Icons.folder_open, size: 18),
                  label: Text(_modelFolderPath == null ? '폴더 선택' : '변경'),
                ),
              ],
            ),
            
            if (_modelFolderPath != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 14,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '발견된 모델: ${_models.length}개',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 오버레이 컨트롤 카드
  Widget _buildOverlayControlCard() {
    final canEnable = _hasOverlayPermission && _modelFolderPath != null && _selectedModelPath != null;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 오버레이 ON/OFF 스위치
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('오버레이 활성화'),
              subtitle: Text(
                canEnable
                    ? (_overlayEnabled ? '화면 위에 표시 중' : '터치하여 활성화')
                    : '권한을 허용하고 폴더/모델을 선택하세요',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
              value: _overlayEnabled,
              onChanged: canEnable ? _toggleOverlay : null,
            ),
            
            const Divider(),

            // 크기 조절 슬라이더
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('오버레이 크기'),
                    Text(
                      '${(_overlaySize * 100).toInt()}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _overlaySize,
                  min: 0.5,
                  max: 3.0,
                  divisions: 25,
                  label: '${(_overlaySize * 100).toInt()}%',
                  onChanged: _setOverlaySize,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '50%',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                    Text(
                      '300%',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 8),

            // 서버 상태 표시
            Row(
              children: [
                Icon(
                  _isServerRunning ? Icons.dns : Icons.dns_outlined,
                  size: 16,
                  color: _isServerRunning ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  '로컬 서버: ${_isServerRunning ? "실행 중 (포트 8080)" : "중지됨"}',
                  style: TextStyle(
                    fontSize: 12,
                    color: _isServerRunning ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 모델 목록 카드
  Widget _buildModelListCard() {
    // 폴더가 선택되지 않은 경우
    if (_modelFolderPath == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.folder_off,
                  size: 48,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 12),
                const Text('모델 폴더를 선택해주세요'),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _selectModelFolder,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('폴더 선택'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 모델이 없는 경우
    if (_models.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.sentiment_dissatisfied,
                  size: 48,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 12),
                const Text('발견된 모델이 없습니다'),
                const SizedBox(height: 4),
                Text(
                  '$_modelFolderPath\n폴더에 .model3.json 파일이 포함된 모델을 추가해주세요',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _refreshModels,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('새로고침'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      child: Column(
        children: [
          // 모델 수 표시
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '총 ${_models.length}개의 모델',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                if (_selectedModelPath != null)
                  TextButton(
                    onPressed: () => _selectModel(null),
                    child: const Text('선택 해제'),
                  ),
              ],
            ),
          ),
          
          // 모델 리스트
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _models.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final model = _models[index];
              final isSelected = model.relativePath == _selectedModelPath;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Icon(
                    isSelected ? Icons.check : Icons.face,
                    color: isSelected
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                title: Text(
                  model.name,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: Text(
                  model.relativePath,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
                selected: isSelected,
                onTap: () => _selectModel(model.relativePath),
              );
            },
          ),
        ],
      ),
    );
  }

  /// 안내 카드
  Widget _buildInfoCard() {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '모델 추가 방법',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoStep(1, '위의 "폴더 선택" 버튼으로 Live2D 모델이 있는 폴더 선택'),
            _buildInfoStep(2, '폴더 안에 모델 폴더들이 있어야 함 (예: hiyori/, mao/)'),
            _buildInfoStep(3, '각 모델 폴더에 .model3.json 파일 필수'),
            _buildInfoStep(4, '새로고침 버튼으로 모델 목록 갱신'),
            const SizedBox(height: 8),
            Text(
              '현재 경로: ${_modelFolderPath ?? "선택 안됨"}',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 안내 단계 위젯
  Widget _buildInfoStep(int number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
