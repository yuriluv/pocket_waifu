import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

extension UiFeedbackX on BuildContext {
  void showInfoSnackBar(String message) {
    ScaffoldMessenger.of(this)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  void showErrorSnackBar(String message) {
    ScaffoldMessenger.of(this)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(this).colorScheme.error,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  Future<void> copyToClipboard(String text, {String? successMessage}) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      showInfoSnackBar(successMessage ?? '클립보드에 복사되었습니다.');
    }
  }
}
