import 'package:flutter/material.dart';
import 'package:app_template/theme.dart';

class AppSnackbar {
  static void showSuccess(BuildContext context, String message) {
    _show(
      context,
      message,
      variant: _SnackbarVariant.success,
    );
  }

  static void showError(BuildContext context, String message) {
    _show(
      context,
      message,
      variant: _SnackbarVariant.error,
    );
  }

  static void showInfo(BuildContext context, String message) {
    _show(
      context,
      message,
      variant: _SnackbarVariant.info,
    );
  }

  static void _show(
    BuildContext context,
    String message, {
    required _SnackbarVariant variant,
  }) {
    final cs = Theme.of(context).colorScheme;
    final Color bg;
    final Color fg;

    switch (variant) {
      case _SnackbarVariant.success:
        bg = cs.primaryContainer;
        fg = cs.onPrimaryContainer;
        break;
      case _SnackbarVariant.error:
        bg = cs.errorContainer;
        fg = cs.onErrorContainer;
        break;
      case _SnackbarVariant.info:
        bg = cs.surfaceContainerHighest;
        fg = cs.onSurface;
        break;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: fg),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: bg,
        margin: const EdgeInsets.all(AppSpacing.lg),
      ),
    );
  }
}

enum _SnackbarVariant { success, error, info }

