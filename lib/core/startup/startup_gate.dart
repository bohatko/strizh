import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_template/features/auth/presentation/controllers/auth_controller.dart';
import 'package:app_template/core/startup/splash_page.dart';

class StartupCompleteNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void markComplete() => state = true;
}

final startupCompleteProvider =
    NotifierProvider<StartupCompleteNotifier, bool>(StartupCompleteNotifier.new);

class StartupGate extends ConsumerStatefulWidget {
  final Widget child;

  const StartupGate({super.key, required this.child});

  @override
  ConsumerState<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends ConsumerState<StartupGate> {
  @override
  void initState() {
    super.initState();
    ref.listenManual(authControllerProvider, (prev, next) {
      final complete = ref.read(startupCompleteProvider);
      if (complete) return;
      if (!next.isLoading) {
        ref.read(startupCompleteProvider.notifier).markComplete();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final startupComplete = ref.watch(startupCompleteProvider);
    final authAsync = ref.watch(authControllerProvider);

    if (!startupComplete && authAsync.isLoading) {
      return const SplashPage();
    }
    return widget.child;
  }
}

