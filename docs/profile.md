# Profile screen (`/profile`)

## Logout

The logout icon in the app bar opens a confirmation dialog. Tapping **Подтвердить выход**:

1. Calls `AuthController.signOut()` (Supabase session is cleared).
2. Navigates to `/login` via `context.go(AppRoutes.login)`.

GoRouter also redirects unauthenticated users away from protected routes such as `/profile` when auth state changes.

## Account deletion

After a confirmed account deletion, the app signs out and navigates to `/login` using the same flow.

## Avatar upload

Before opening the gallery picker, the app requests photo library access via `GalleryPermission` (`lib/core/permissions/gallery_permission.dart`). If access is permanently denied, the user is prompted to open system settings.

Platform setup:

- **Android:** `READ_MEDIA_IMAGES` (API 33+) and `READ_EXTERNAL_STORAGE` (API 32 and below) in `AndroidManifest.xml`
- **iOS:** `NSPhotoLibraryUsageDescription` in `Info.plist`, `PERMISSION_PHOTOS=1` in `Podfile`

## Related files

- `lib/features/settings/presentation/pages/profile_page.dart`
- `lib/core/permissions/gallery_permission.dart`
- `lib/nav.dart`
