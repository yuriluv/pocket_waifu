// ============================================================================
// 간단한 오버레이 테스트 위젯
// ============================================================================
// WebView 없이 오버레이 자체가 작동하는지 테스트합니다.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

/// 테스트용 간단한 오버레이 위젯
class SimpleOverlayTest extends StatefulWidget {
  const SimpleOverlayTest({super.key});

  @override
  State<SimpleOverlayTest> createState() => _SimpleOverlayTestState();
}

class _SimpleOverlayTestState extends State<SimpleOverlayTest> {
  int _counter = 0;
  String _status = '오버레이 시작됨';

  @override
  void initState() {
    super.initState();
    debugPrint('[SimpleOverlay] 위젯 초기화됨');
    
    // 데이터 수신 테스트
    FlutterOverlayWindow.overlayListener.listen((data) {
      debugPrint('[SimpleOverlay] 데이터 수신: $data');
      setState(() {
        _status = '데이터: $data';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 상태 텍스트
            Text(
              _status,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 16),
            
            // 카운터
            Text(
              '탭: $_counter',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 탭 버튼
            GestureDetector(
              onTap: () {
                setState(() {
                  _counter++;
                });
                debugPrint('[SimpleOverlay] 탭됨: $_counter');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '여기를 탭!',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 닫기 버튼
            GestureDetector(
              onTap: () async {
                debugPrint('[SimpleOverlay] 닫기 요청');
                await FlutterOverlayWindow.closeOverlay();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '닫기',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
