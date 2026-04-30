import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_template/features/auth/presentation/controllers/auth_controller.dart';
import 'package:app_template/features/auth/presentation/models/auth_state.dart';
import 'package:app_template/features/auth/presentation/pages/login_page.dart';
import 'package:app_template/features/home/presentation/pages/home_page.dart';
import 'package:app_template/features/search/presentation/pages/search_page.dart';
import 'package:app_template/features/shop/presentation/pages/shop_page.dart';
import 'package:app_template/features/settings/presentation/pages/settings_page.dart';
import 'package:app_template/features/settings/presentation/pages/profile_page.dart';

/// GoRouter configuration for app navigation
///
/// This uses go_router for declarative routing, which provides:
/// - Type-safe navigatio
/// - Deep linking support (web URLs, app links)
/// - Easy route parameters
/// - Navigation guards and redirects
///
/// To add a new route:
/// 1. Add a route constant to AppRoutes below
/// 2. Add a GoRoute to the routes list
/// 3. Navigate using context.go() or context.push()
/// 4. Use context.pop() to go back.
class AppRouter {
  static GoRouter createRouter(Ref ref) {
    return GoRouter(
      initialLocation: AppRoutes.home,
      refreshListenable: ref.watch(routerRefreshNotifierProvider),
      redirect: (context, state) {
        final auth = ref.read(authControllerProvider);

        final isLogin = state.matchedLocation == AppRoutes.login;
        final isSplashLike = auth.isLoading;

        if (isSplashLike) return null;

        final authValue = auth.asData?.value;
        final isAuthed = authValue is Authenticated;

        if (!isAuthed && !isLogin) return AppRoutes.login;
        if (isAuthed && isLogin) return AppRoutes.home;
        return null;
      },
      routes: [
        GoRoute(
          path: AppRoutes.login,
          name: 'login',
          pageBuilder: (context, state) => const NoTransitionPage(child: LoginPage()),
        ),
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: [
            GoRoute(
              path: AppRoutes.home,
              name: 'home',
              pageBuilder: (context, state) => const NoTransitionPage(child: HomePage()),
            ),
            GoRoute(
              path: AppRoutes.shop,
              name: 'shop',
              pageBuilder: (context, state) => const NoTransitionPage(child: ShopPage()),
            ),
            GoRoute(
              path: AppRoutes.search,
              name: 'search',
              pageBuilder: (context, state) => const NoTransitionPage(child: SearchPage()),
            ),
            GoRoute(
              path: AppRoutes.profile,
              name: 'profile',
              pageBuilder: (context, state) => const NoTransitionPage(child: ProfilePage()),
            ),
            GoRoute(
              path: AppRoutes.settings,
              name: 'settings',
              pageBuilder: (context, state) => const NoTransitionPage(child: SettingsPage()),
            ),
          ],
        ),
      ],
    );
  }
}

/// Route path constants
/// Use these instead of hard-coding route strings
class AppRoutes {
  static const String login = '/login';
  static const String home = '/home';
  static const String shop = '/shop';
  static const String search = '/search';
  static const String profile = '/profile';
  static const String settings = '/settings';
}

final appRouterProvider = Provider<GoRouter>((ref) => AppRouter.createRouter(ref));

class RouterRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}

final routerRefreshNotifierProvider = Provider<RouterRefreshNotifier>((ref) {
  final notifier = RouterRefreshNotifier();
  ref.listen(authStateStreamProvider, (_, __) => notifier.refresh());
  ref.onDispose(notifier.dispose);
  return notifier;
});

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  int _indexForLocation(String location) {
    if (location.startsWith(AppRoutes.shop)) return 1;
    if (location.startsWith(AppRoutes.search)) return 2;
    if (location.startsWith(AppRoutes.profile)) return 3;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppRoutes.home);
        return;
      case 1:
        context.go(AppRoutes.shop);
        return;
      case 2:
        context.go(AppRoutes.search);
        return;
      case 3:
        context.go(AppRoutes.profile);
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final index = _indexForLocation(location);

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final Color barColor =
        isDark ? cs.surfaceContainerHighest.withValues(alpha: 0.9) : cs.surface;
    final Color shadowColor =
        cs.shadow.withValues(alpha: isDark ? 0.6 : 0.04);
    return Scaffold(
      body: child,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          height: 88,
          decoration: BoxDecoration(
            color: barColor,
            border: Border(
              top: BorderSide(
                color: cs.outline.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _BottomNavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                isActive: index == 0,
                onTap: () => _onTap(context, 0),
              ),
              _BottomNavItem(
                icon: Icons.storefront_rounded,
                label: 'Shop',
                isActive: index == 1,
                onTap: () => _onTap(context, 1),
              ),
              _BottomNavItem(
                icon: Icons.search_rounded,
                label: 'Search',
                isActive: index == 2,
                onTap: () => _onTap(context, 2),
              ),
              _BottomNavItem(
                icon: Icons.person_rounded,
                label: 'Profile',
                isActive: index == 3,
                onTap: () => _onTap(context, 3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_BottomNavItem> createState() => _BottomNavItemState();
}

class _BottomNavItemState extends State<_BottomNavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final activeColor = cs.primary;
    final inactiveColor = cs.onSurfaceVariant;

    final bool isActive = widget.isActive;
    final Color iconColor =
        isActive ? cs.onPrimary : (_isHovered ? activeColor : inactiveColor);
    final Color labelColor =
        isActive ? activeColor : (_isHovered ? activeColor : inactiveColor);

    return Expanded(
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                height: isActive ? 32 : 24,
                width: isActive ? 32 : 24,
                decoration: isActive
                    ? BoxDecoration(
                        color: activeColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: activeColor.withValues(alpha: 0.35),
                            offset: const Offset(0, 6),
                            blurRadius: 16,
                          ),
                        ],
                      )
                    : null,
                alignment: Alignment.center,
                child: Icon(
                  widget.icon,
                  size: 20,
                  color: iconColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: labelColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
