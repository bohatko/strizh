import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_template/features/auth/presentation/controllers/auth_controller.dart';
import 'package:app_template/features/auth/presentation/models/auth_state.dart';
import 'package:app_template/core/providers/theme_provider.dart';
import 'package:app_template/theme.dart';
import 'package:app_template/core/ui/app_button.dart';
import 'package:app_template/core/ui/app_text_field.dart';
import 'package:app_template/core/ui/app_snackbar.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  bool _notificationsEnabled = true;
  DateTime? _memberSince;
  String? _staffId;
  String? _role;

  bool _initializedFromAuth = false;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  void _hydrateFromAuth(AsyncValue<AuthState> authAsync) {
    if (_initializedFromAuth) return;
    final value = authAsync.asData?.value;
    if (value is! Authenticated) return;

    final user = value.user;
    final fullName = user.displayName?.trim() ?? '';
    final parts = fullName.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();

    if (_firstNameCtrl.text.isEmpty && parts.isNotEmpty) {
      _firstNameCtrl.text = parts.first;
    }
    if (_lastNameCtrl.text.isEmpty && parts.length > 1) {
      _lastNameCtrl.text = parts.sublist(1).join(' ');
    }
    if (_emailCtrl.text.isEmpty) {
      _emailCtrl.text = user.email;
    }

    _memberSince ??= user.createdAt;
    _staffId ??= user.displayName ?? '-';
    _role ??= user.role ?? '-';

    _initializedFromAuth = true;
  }

  Future<void> _saveProfile() async {
    final notifier = ref.read(authControllerProvider.notifier);
    final first = _firstNameCtrl.text.trim();
    final last = _lastNameCtrl.text.trim();
    final fullName = [first, last].where((p) => p.isNotEmpty).join(' ');

    try {
      await notifier.updateProfile(
        displayName: fullName.isEmpty ? null : fullName,
        firstName: first.isEmpty ? null : first,
        lastName: last.isEmpty ? null : last,
      );
      if (!mounted) return;
      AppSnackbar.showSuccess(context, 'Profile updated');
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.showError(context, e.toString());
    }
  }

  String _formatMemberSince(DateTime? date) {
    if (date == null) return '-';
    final d = date.toLocal();
    final year = d.year.toString();
    final month = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Future<void> _showSignOutDialog({required bool isBusy}) async {
    if (isBusy) return;
    final cs = Theme.of(context).colorScheme;

    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
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
              Row(
                children: [
                  Icon(Icons.logout_rounded, color: cs.error),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    'Sign Out',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Are you sure you want to log out of SimPool?',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.withColor(cs.onSurfaceVariant),
              ),
            ],
          ),
          actions: [
            OutlinedButton(
              style: ButtonStyle(
                splashFactory: NoSplash.splashFactory,
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: ButtonStyle(
                splashFactory: NoSplash.splashFactory,
                backgroundColor: WidgetStatePropertyAll(cs.error),
                foregroundColor: WidgetStatePropertyAll(cs.onError),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Confirm Logout'),
            ),
          ],
        );
      },
    );

    if (shouldSignOut != true) return;

    try {
      await ref.read(authControllerProvider.notifier).signOut();
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.showError(context, e.toString());
    }
  }

  Future<void> _showDeleteAccountDialog() async {
    final cs = Theme.of(context).colorScheme;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
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
              Row(
                children: [
                  Icon(Icons.report_problem_rounded, color: cs.error),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    'Delete Account',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Deleting your account is permanent. All service logs and customer feedback will be erased.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.withColor(cs.onSurfaceVariant),
              ),
            ],
          ),
          actions: [
            OutlinedButton(
              style: ButtonStyle(
                splashFactory: NoSplash.splashFactory,
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: ButtonStyle(
                splashFactory: NoSplash.splashFactory,
                backgroundColor: WidgetStatePropertyAll(cs.error),
                foregroundColor: WidgetStatePropertyAll(cs.onError),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete Account'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    try {
      await ref.read(authControllerProvider.notifier).deleteAccount();
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.showError(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final authAsync = ref.watch(authControllerProvider);
    final themeMode = ref.watch(themeControllerProvider);

    _hydrateFromAuth(authAsync);

    final isDark = themeMode == ThemeMode.dark;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 48),
                  Text(
                    'Profile Settings',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout_rounded),
                    onPressed: authAsync.isLoading
                        ? null
                        : () => _showSignOutDialog(
                              isBusy: authAsync.isLoading,
                            ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: 120,
                      width: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: cs.surface,
                          width: 4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: cs.shadow.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                        child: const Icon(Icons.person, size: 48),
                      ),
                    ),
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Material(
                        color: cs.primary,
                        shape: const CircleBorder(),
                        elevation: 2,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Avatar change is not implemented in this template.'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            child: Icon(
                              Icons.photo_camera_rounded,
                              size: 18,
                              color: cs.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Preferences',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.withColor(cs.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.sm),
              _SettingsToggleTile(
                icon: Icons.dark_mode_rounded,
                title: 'Dark Mode',
                subtitle: 'Switch between light and dark themes',
                value: isDark,
                onChanged: (_) =>
                    ref.read(themeControllerProvider.notifier).toggleTheme(),
              ),
              const SizedBox(height: AppSpacing.sm),
              _SettingsToggleTile(
                icon: Icons.notifications_active_rounded,
                title: 'Push Notifications',
                subtitle: 'Service reminders and updates',
                value: _notificationsEnabled,
                onChanged: (v) {
                  setState(() {
                    _notificationsEnabled = v;
                  });
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Personal Information',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.withColor(cs.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.sm),
              _ProfileInputField(
                label: 'First Name',
                controller: _firstNameCtrl,
                icon: Icons.person_outline_rounded,
              ),
              const SizedBox(height: AppSpacing.md),
              _ProfileInputField(
                label: 'Last Name',
                controller: _lastNameCtrl,
                icon: Icons.person_outline_rounded,
              ),
              const SizedBox(height: AppSpacing.md),
              _ProfileInputField(
                label: 'Email Address',
                controller: _emailCtrl,
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                enabled: false,
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: cs.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Account Details',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Divider(color: cs.outline.withValues(alpha: 0.2)),
                    const SizedBox(height: AppSpacing.sm),
                    _InfoRow(
                      label: 'Member Since',
                      value: _formatMemberSince(_memberSince),
                    ),
                    _InfoRow(
                      label: 'Display name',
                      value: _staffId ?? '-',
                    ),
                    _InfoRow(
                      label: 'Role',
                      value: _role ?? '-',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Save Changes',
                icon: Icons.check_circle_rounded,
                onPressed: authAsync.isLoading ? null : _saveProfile,
                isLoading: authAsync.isLoading,
              ),
              const SizedBox(height: AppSpacing.lg),
              _DangerZoneCard(onDelete: _showDeleteAccountDialog),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsToggleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: cs.outline.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 22, color: cs.primary),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.withColor(cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: cs.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _ProfileInputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool enabled;

  const _ProfileInputField({
    required this.label,
    required this.controller,
    required this.icon,
    this.keyboardType,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: controller,
      label: label,
      icon: icon,
      keyboardType: keyboardType,
      enabled: enabled,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.withColor(cs.onSurfaceVariant),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.semiBold
                  .withColor(cs.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

class _DangerZoneCard extends StatelessWidget {
  final VoidCallback onDelete;

  const _DangerZoneCard({required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color background =
        isDark ? cs.errorContainer.withValues(alpha: 0.6) : cs.errorContainer.withValues(alpha: 0.2);
    final Color borderColor =
        isDark ? cs.error.withValues(alpha: 0.6) : cs.error.withValues(alpha: 0.35);
    final Color bodyColor =
        isDark ? cs.onErrorContainer.withValues(alpha: 0.9) : cs.onSurfaceVariant;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.report_problem_rounded, color: cs.error, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Danger Zone',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.withColor(cs.error),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Deleting your account is permanent. All service logs and customer feedback will be erased.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.withColor(bodyColor),
          ),
          const SizedBox(height: AppSpacing.md),
          TextButton(
            onPressed: onDelete,
            style: ButtonStyle(
              foregroundColor: WidgetStatePropertyAll(cs.error),
            ),
            child: const Text(
              'Delete Account',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
