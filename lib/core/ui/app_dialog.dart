import 'package:flutter/material.dart';
import 'package:app_template/theme.dart';

class AppDialog extends StatelessWidget {
  final Widget title;
  final Widget? body;
  final List<Widget> actions;

  const AppDialog({
    super.key,
    required this.title,
    this.body,
    required this.actions,
  });

  static Future<T?> show<T>({
    required BuildContext context,
    required Widget title,
    Widget? body,
    required List<Widget> actions,
  }) {
    return showDialog<T>(
      context: context,
      builder: (dialogContext) {
        return AppDialog(
          title: title,
          body: body,
          actions: actions,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      contentPadding: const EdgeInsets.all(AppSpacing.lg),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DefaultTextStyle(
            style: Theme.of(context).textTheme.titleMedium!,
            child: Row(
              children: [
                Icon(Icons.info_outline, color: cs.primary),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: title),
              ],
            ),
          ),
          if (body != null) ...[
            const SizedBox(height: AppSpacing.sm),
            DefaultTextStyle(
              style: Theme.of(context)
                  .textTheme
                  .bodySmall!
                  .copyWith(color: cs.onSurfaceVariant),
              child: body!,
            ),
          ],
        ],
      ),
      actions: actions,
    );
  }
}

