import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_template/core/network/connectivity_status_provider.dart';
import 'package:app_template/core/ui/app_button.dart';
import 'package:app_template/theme.dart';

class OfflinePage extends ConsumerStatefulWidget {
  const OfflinePage({super.key});

  @override
  ConsumerState<OfflinePage> createState() => _OfflinePageState();
}

class _OfflinePageState extends ConsumerState<OfflinePage> {
  bool _isChecking = false;

  Future<void> _checkAgain() async {
    if (_isChecking) return;
    setState(() => _isChecking = true);
    try {
      final isOnline = await ref.refresh(connectivityStatusProvider.future);
      if (isOnline) return;
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 72,
                    width: 72,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: cs.outline.withValues(alpha: 0.18)),
                    ),
                    child: Icon(Icons.wifi_off_rounded, size: 34, color: cs.onSurface),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'No connection',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    "You're offline. Please check your internet connection.",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.withColor(cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    label: 'Check again',
                    onPressed: _checkAgain,
                    isLoading: _isChecking,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

