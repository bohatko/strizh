import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_template/core/network/connectivity_status_provider.dart';
import 'package:app_template/core/network/offline_page.dart';

class NetworkGate extends ConsumerWidget {
  final Widget child;

  const NetworkGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onlineAsync = ref.watch(connectivityStatusProvider);

    return onlineAsync.when(
      data: (isOnline) => isOnline ? child : const OfflinePage(),
      loading: () => child,
      error: (_, __) => child,
    );
  }
}

