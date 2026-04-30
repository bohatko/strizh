import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_template/core/logging/app_logger.dart';
import 'package:app_template/features/auth/domain/models/user_model.dart';
import 'package:app_template/features/auth/domain/repositories/i_auth_repository.dart';

class SupabaseAuthRepository implements IAuthRepository {
  final SupabaseClient _client;

  SupabaseAuthRepository(this._client);

  static const String _profilesTable = 'profiles';

  @override
  Future<UserModel> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Sign in failed: No user returned');
      }

      final base = _mapSupabaseUserToUserModel(response.user!);
      final enriched = await _enrichWithProfile(base);
      await _ensureProfileRow(enriched);

      if (enriched.softDelete) {
        await _client.auth.signOut();
        throw Exception('This account has been deleted.');
      }

      return enriched;
    } on AuthException catch (e) {
      AppLogger.warning('Supabase auth error', error: e.message);
      throw _mapAuthException(e);
    } catch (e) {
      AppLogger.error('Unexpected sign in error', error: e);
      rethrow;
    }
  }

  @override
  Future<UserModel> signUpWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Sign up failed: No user returned');
      }

      final base = _mapSupabaseUserToUserModel(response.user!);
      await _ensureProfileRow(base);
      return await _enrichWithProfile(base);
    } on AuthException catch (e) {
      AppLogger.warning('Supabase auth error', error: e.message);
      throw _mapAuthException(e);
    } catch (e) {
      AppLogger.error('Unexpected sign up error', error: e);
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on AuthException catch (e) {
      AppLogger.warning('Supabase sign out error', error: e.message);
      throw _mapAuthException(e);
    } catch (e) {
      AppLogger.error('Unexpected sign out error', error: e);
      rethrow;
    }
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return null;

      final base = _mapSupabaseUserToUserModel(user);
      final enriched = await _enrichWithProfile(base);
      await _ensureProfileRow(enriched);

      if (enriched.softDelete) {
        await _client.auth.signOut();
        return null;
      }

      return enriched;
    } catch (e) {
      AppLogger.warning('Error getting current user', error: e);
      return null;
    }
  }

  @override
  Stream<UserModel?> authStateChanges() {
    return _client.auth.onAuthStateChange.asyncMap((state) async {
      final user = state.session?.user;
      if (user == null) return null;

      final base = _mapSupabaseUserToUserModel(user);
      final enriched = await _enrichWithProfile(base);
      await _ensureProfileRow(enriched);

      if (enriched.softDelete) {
        await _client.auth.signOut();
        return null;
      }

      return enriched;
    });
  }

  @override
  Future<void> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
    } on AuthException catch (e) {
      AppLogger.warning('Supabase password reset error', error: e.message);
      throw _mapAuthException(e);
    } catch (e) {
      AppLogger.error('Unexpected password reset error', error: e);
      rethrow;
    }
  }

  @override
  Future<void> updateProfile({
    String? displayName,
    String? avatarUrl,
    String? firstName,
    String? lastName,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (displayName != null) updates['display_name'] = displayName;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

      final current = _client.auth.currentUser;
      if (current == null) {
        throw Exception('Not authenticated');
      }

      await _client.auth.updateUser(UserAttributes(data: updates));

      final profileUpdates = <String, dynamic>{};
      if (displayName != null) profileUpdates['display_name'] = displayName;
      if (avatarUrl != null) profileUpdates['avatar_url'] = avatarUrl;
      if (firstName != null) profileUpdates['first_name'] = firstName;
      if (lastName != null) profileUpdates['last_name'] = lastName;

      if (profileUpdates.isNotEmpty) {
        await _client
            .from(_profilesTable)
            .update({
              ...profileUpdates,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', current.id);
      }
    } on AuthException catch (e) {
      AppLogger.warning('Supabase profile update error', error: e.message);
      throw _mapAuthException(e);
    } catch (e) {
      AppLogger.error('Unexpected profile update error', error: e);
      rethrow;
    }
  }

  @override
  Future<void> deleteAccount() async {
    try {
      final current = _client.auth.currentUser;
      if (current == null) {
        throw Exception('Not authenticated');
      }

      await _client.auth.updateUser(
        UserAttributes(
          data: const {
            'soft_delete': true,
          },
        ),
      );

      await _client
          .from(_profilesTable)
          .update({
            'soft_delete': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', current.id);

      await _client.auth.signOut();
    } on AuthException catch (e) {
      AppLogger.warning('Supabase delete account error', error: e.message);
      throw _mapAuthException(e);
    } catch (e) {
      AppLogger.error('Unexpected delete account error', error: e);
      rethrow;
    }
  }

  UserModel _mapSupabaseUserToUserModel(User user) {
    return UserModel(
      id: user.id,
      email: user.email ?? '',
      displayName: user.userMetadata?['display_name'] as String?,
      avatarUrl: user.userMetadata?['avatar_url'] as String?,
      role: user.userMetadata?['role'] as String?,
      softDelete: user.userMetadata?['soft_delete'] as bool? ?? false,
      emailVerifiedAt: user.emailConfirmedAt != null 
          ? DateTime.parse(user.emailConfirmedAt!)
          : null,
      createdAt: DateTime.parse(user.createdAt),
      updatedAt: user.updatedAt != null
          ? DateTime.parse(user.updatedAt!)
          : DateTime.parse(user.createdAt),
    );
  }

  Future<UserModel> _enrichWithProfile(UserModel base) async {
    try {
      final row = await _client
          .from(_profilesTable)
          .select('id,email,display_name,avatar_url,role,soft_delete,created_at,updated_at')
          .eq('id', base.id)
          .maybeSingle();

      if (row == null) return base;

      DateTime? parseTs(dynamic v) {
        if (v == null) return null;
        if (v is String) return DateTime.tryParse(v);
        return null;
      }

      return base.copyWith(
        email: (row['email'] as String?) ?? base.email,
        displayName: (row['display_name'] as String?) ?? base.displayName,
        avatarUrl: (row['avatar_url'] as String?) ?? base.avatarUrl,
        role: (row['role'] as String?) ?? base.role,
        softDelete: (row['soft_delete'] as bool?) ?? base.softDelete,
        createdAt: parseTs(row['created_at']) ?? base.createdAt,
        updatedAt: parseTs(row['updated_at']) ?? base.updatedAt,
      );
    } catch (e) {
      // If the table doesn't exist yet or RLS blocks access, we still want auth to work.
      AppLogger.warning('Failed to enrich user with profile row', error: e);
      return base;
    }
  }

  Future<void> _ensureProfileRow(UserModel user) async {
    try {
      // Upsert a minimal row so we can reliably store profile fields in Postgres.
      await _client.from(_profilesTable).upsert({
        'id': user.id,
        'email': user.email,
        'display_name': user.displayName,
        'avatar_url': user.avatarUrl,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Don't break sign-in if DB profile is not set up yet.
      AppLogger.warning('Failed to ensure profile row exists', error: e);
    }
  }

  Exception _mapAuthException(AuthException e) {
    switch (e.statusCode) {
      case '400':
        return Exception('Invalid credentials');
      case '422':
        return Exception('Email already registered');
      case '429':
        return Exception('Too many requests. Please try again later');
      default:
        return Exception(e.message);
    }
  }
}
