import 'package:app_template/features/auth/presentation/controllers/auth_controller.dart';
import 'package:app_template/features/auth/presentation/models/auth_state.dart';
import 'package:app_template/nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AdminAccessIcon extends ConsumerWidget {
  final bool keepPlaceholderWhenHidden;

  const AdminAccessIcon({
    super.key,
    this.keepPlaceholderWhenHidden = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider).asData?.value;
    final isAdmin =
        authState is Authenticated && authState.user.role?.toLowerCase() == 'admin';

    if (!isAdmin) {
      return keepPlaceholderWhenHidden
          ? const SizedBox(width: 48, height: 48)
          : const SizedBox.shrink();
    }

    final cs = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: 'Админ-панель',
      onPressed: () => context.go(AppRoutes.adminPanel),
      icon: Icon(Icons.admin_panel_settings_outlined, color: cs.primary),
    );
  }
}
