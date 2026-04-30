import 'package:app_template/features/auth/domain/models/user_model.dart';

abstract class IAuthRepository {
  Future<UserModel> signInWithEmailPassword({
    required String email,
    required String password,
  });

  Future<UserModel> signUpWithEmailPassword({
    required String email,
    required String password,
  });

  Future<void> signOut();

  Future<UserModel?> getCurrentUser();

  Stream<UserModel?> authStateChanges();

  Future<void> resetPassword(String email);

  Future<void> updateProfile({
    String? displayName,
    String? avatarUrl,
    String? firstName,
    String? lastName,
  });

  Future<void> deleteAccount();
}
