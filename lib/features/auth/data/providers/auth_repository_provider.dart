import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_template/core/providers/supabase_provider.dart';
import 'package:app_template/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:app_template/features/auth/domain/repositories/i_auth_repository.dart';

final authRepositoryProvider = Provider<IAuthRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseAuthRepository(client);
});
