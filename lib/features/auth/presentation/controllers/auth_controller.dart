import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_template/core/logging/app_logger.dart';
import 'package:app_template/features/auth/data/providers/auth_repository_provider.dart';
import 'package:app_template/features/auth/presentation/models/auth_state.dart';

class AuthController extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    final repository = ref.watch(authRepositoryProvider);

    ref.listen(
      authStateStreamProvider,
      (_, next) {
        next.whenData((authState) {
          state = AsyncValue.data(authState);
        });
      },
    );

    final currentUser = await repository.getCurrentUser();
    if (currentUser != null) {
      return Authenticated(currentUser);
    }
    return const Unauthenticated();
  }

  Future<void> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(authRepositoryProvider);
      final user = await repository.signInWithEmailPassword(
        email: email,
        password: password,
      );
      return Authenticated(user);
    });
  }

  Future<void> signUpWithEmailPassword({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(authRepositoryProvider);
      final user = await repository.signUpWithEmailPassword(
        email: email,
        password: password,
      );
      return Authenticated(user);
    });
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(authRepositoryProvider);
      await repository.signOut();
      return const Unauthenticated();
    });
  }

  Future<void> resetPassword(String email) async {
    final repository = ref.read(authRepositoryProvider);
    try {
      await repository.resetPassword(email);
    } catch (e) {
      AppLogger.warning('Password reset error', error: e);
      rethrow;
    }
  }

  Future<void> updateProfile({
    String? displayName,
    String? avatarUrl,
    String? firstName,
    String? lastName,
  }) async {
    final repository = ref.read(authRepositoryProvider);
    try {
      await repository.updateProfile(
        displayName: displayName,
        avatarUrl: avatarUrl,
        firstName: firstName,
        lastName: lastName,
      );
      final currentUser = await repository.getCurrentUser();
      if (currentUser != null) {
        state = AsyncValue.data(Authenticated(currentUser));
      }
    } catch (e) {
      AppLogger.warning('Profile update error', error: e);
      rethrow;
    }
  }

  Future<void> deleteAccount() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(authRepositoryProvider);
      await repository.deleteAccount();
      return const Unauthenticated();
    });
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthState>(
  () => AuthController(),
);

final authStateStreamProvider = StreamProvider<AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return repository.authStateChanges().map((user) {
    if (user != null) {
      return Authenticated(user);
    }
    return const Unauthenticated();
  });
});
