import 'package:flutter/material.dart';
import 'package:app_template/core/logging/app_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_template/core/providers/theme_provider.dart';
import 'package:app_template/features/auth/presentation/controllers/auth_controller.dart';
import 'package:app_template/features/auth/presentation/models/auth_state.dart';
import 'package:app_template/theme.dart';
import 'package:app_template/core/ui/app_button.dart';
import 'package:app_template/core/ui/app_snackbar.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final themeMode = ref.watch(themeControllerProvider);
    final authAsync = ref.watch(authControllerProvider);
    final authValue = authAsync.asData?.value;
    final userEmail = authValue is Authenticated ? authValue.user.email : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            if (userEmail != null) ...[
              _SettingsCard(
                title: 'Account',
                child: Row(
                  children: [
                    Container(
                      height: 44,
                      width: 44,
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.person, color: cs.onPrimaryContainer),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Signed in as', style: Theme.of(context).textTheme.labelSmall?.withColor(cs.onSurfaceVariant)),
                          const SizedBox(height: 2),
                          Text(userEmail, style: Theme.of(context).textTheme.titleMedium),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            _SettingsCard(
              title: 'Appearance',
              child: Column(
                children: [
                  _ThemeTile(
                    title: 'Light',
                    icon: Icons.light_mode,
                    selected: themeMode == ThemeMode.light,
                    onTap: () => ref.read(themeControllerProvider.notifier).setThemeMode(ThemeMode.light),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _ThemeTile(
                    title: 'Dark',
                    icon: Icons.dark_mode,
                    selected: themeMode == ThemeMode.dark,
                    onTap: () => ref.read(themeControllerProvider.notifier).setThemeMode(ThemeMode.dark),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _SettingsCard(
              title: 'Session',
              child: AppButton(
                label: 'Sign out',
                icon: Icons.logout,
                isDestructive: true,
                onPressed: authAsync.isLoading
                    ? null
                    : () async {
                        try {
                          await ref.read(authControllerProvider.notifier).signOut();
                        } catch (e) {
                          AppLogger.warning('Sign out failed', error: e);
                          if (context.mounted) {
                            AppSnackbar.showError(context, e.toString());
                          }
                        }
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SettingsCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelLarge?.withColor(cs.onSurfaceVariant)),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: cs.outline.withValues(alpha: 0.18)),
          ),
          child: child,
        ),
      ],
    );
  }
}

class _ThemeTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeTile({required this.title, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: selected ? cs.primaryContainer.withValues(alpha: 0.35) : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
          child: Row(
            children: [
              Icon(icon, color: selected ? cs.primary : cs.onSurfaceVariant),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 22,
                width: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: selected ? cs.primary : cs.outline.withValues(alpha: 0.4), width: 2),
                ),
                child: selected
                    ? Center(
                        child: Container(
                          height: 10,
                          width: 10,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: cs.primary),
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
