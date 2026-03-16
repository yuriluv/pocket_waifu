import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

SnackBar _buildFeedbackSnackBar({
  required String message,
  required Duration duration,
  Color? backgroundColor,
  Color? closeIconColor,
}) {
  return SnackBar(
    content: Text(message),
    behavior: SnackBarBehavior.floating,
    duration: duration,
    backgroundColor: backgroundColor,
    showCloseIcon: true,
    closeIconColor: closeIconColor,
  );
}

extension UiFeedbackX on BuildContext {
  void showSnackBarMessage(
    String message, {
    Duration duration = const Duration(seconds: 2),
    Color? backgroundColor,
    Color? closeIconColor,
  }) {
    ScaffoldMessenger.of(this)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        _buildFeedbackSnackBar(
          message: message,
          duration: duration,
          backgroundColor: backgroundColor,
          closeIconColor: closeIconColor,
        ),
      );
  }

  void showInfoSnackBar(String message) {
    showSnackBarMessage(message);
  }

  void showErrorSnackBar(String message) {
    final colorScheme = Theme.of(this).colorScheme;
    showSnackBarMessage(
      message,
      duration: const Duration(seconds: 3),
      backgroundColor: colorScheme.error,
      closeIconColor: colorScheme.onError,
    );
  }

  Future<void> copyToClipboard(String text, {String? successMessage}) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      showInfoSnackBar(successMessage ?? '클립보드에 복사되었습니다.');
    }
  }
}
