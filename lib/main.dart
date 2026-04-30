import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:app_template/theme.dart';
import 'package:app_template/nav.dart';
import 'package:app_template/core/providers/theme_provider.dart';
import 'package:app_template/core/network/network_gate.dart';
import 'package:app_template/core/startup/startup_gate.dart';
import 'package:app_template/supabase/supabase_config.dart';
import 'package:app_template/core/logging/app_logger.dart';

/// Main entry point for the application
///
/// This sets up:
/// - Supabase initialization
/// - Environment variables loading
/// - Riverpod state management
/// - go_router navigation
/// - Material 3 theming with light/dark modes
/// - English localization
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await SupabaseConfig.initialize();
  } catch (e) {
    AppLogger.error('Error initializing app', error: e);
  }
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeControllerProvider);
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'App Template',
      debugShowCheckedModeBanner: false,
      locale: const Locale('en', 'US'),
      supportedLocales: const [Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        return NetworkGate(
          child: StartupGate(child: child ?? const SizedBox.shrink()),
        );
      },
    );
  }
}

