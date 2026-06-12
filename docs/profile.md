# Profile screen (`/profile`)

## Logout

The logout icon in the app bar opens a confirmation dialog. Tapping **Подтвердить выход**:

1. Calls `AuthController.signOut()` (Supabase session is cleared).
2. Navigates to `/login` via `context.go(AppRoutes.login)`.

GoRouter also redirects unauthenticated users away from protected routes such as `/profile` when auth state changes.

## Account deletion

After a confirmed account deletion, the app signs out and navigates to `/login` using the same flow.

## Related files

- `lib/features/settings/presentation/pages/profile_page.dart`
- `lib/nav.dart`
