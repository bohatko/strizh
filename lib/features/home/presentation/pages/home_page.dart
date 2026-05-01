import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app_template/core/ui/app_snackbar.dart';
import 'package:app_template/features/auth/presentation/controllers/auth_controller.dart';
import 'package:app_template/features/auth/presentation/models/auth_state.dart';
import 'package:app_template/features/salon/presentation/widgets/salon_location_sheet.dart';
import 'package:app_template/nav.dart';
import 'package:app_template/supabase/supabase_config.dart';
import 'package:app_template/theme.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  Future<List<Map<String, dynamic>>> _loadPopularServices() async {
    final services = await SupabaseService.select(
      'services',
      orderBy: 'created_at',
      ascending: false,
      limit: 6,
    );
    final reviews = await SupabaseConfig.client
        .from('reviews')
        .select('rating, appointments(service_id)');

    final totals = <int, double>{};
    final counts = <int, int>{};
    for (final row in List<Map<String, dynamic>>.from(reviews)) {
      final appointment = row['appointments'] as Map<String, dynamic>?;
      final serviceId = appointment?['service_id'];
      final rating = row['rating'];
      if (serviceId is int && rating is num) {
        totals[serviceId] = (totals[serviceId] ?? 0) + rating.toDouble();
        counts[serviceId] = (counts[serviceId] ?? 0) + 1;
      }
    }

    for (final service in services) {
      final id = service['id'];
      if (id is int && (counts[id] ?? 0) > 0) {
        service['avg_rating'] = (totals[id]! / counts[id]!).toStringAsFixed(1);
        service['reviews_count'] = counts[id];
      } else {
        service['avg_rating'] = null;
        service['reviews_count'] = 0;
      }
    }

    return services;
  }
  Future<List<Map<String, dynamic>>> _loadMasters() =>
      SupabaseService.select('masters', orderBy: 'created_at', ascending: false, limit: 8);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final cs = Theme.of(context).colorScheme;
    final authValue = authState.asData?.value;
    final isAuthed = authValue is Authenticated;
    final email = isAuthed ? authValue.user.email : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F2FA),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Стриж',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Уведомления',
                  onPressed: () => context.go(AppRoutes.notifications),
                  icon: const Icon(Icons.notifications_none_rounded),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              isAuthed ? 'Добрый день, ${email?.split('@').first ?? 'Анна'}!' : 'Добрый день, гость!',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Готовы к преображению?',
              style: Theme.of(context).textTheme.bodyMedium?.withColor(cs.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.xl),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFB388FF), Color(0xFFAB7BEE)]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '-20% СКИДКА',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.black.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Весеннее\nобновление волос',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: const Color(0xFF3B2863),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF6E48B8)),
                    onPressed: () => context.go(isAuthed ? AppRoutes.booking : AppRoutes.login),
                    child: const Text('Записаться'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            _SectionHeader(
              title: 'Популярные услуги',
              onAllTap: () => context.go(AppRoutes.services),
            ),
            const SizedBox(height: AppSpacing.sm),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _loadPopularServices(),
              builder: (context, snapshot) {
                final services = snapshot.data ?? const [];
                if (services.isEmpty) {
                  return const Text('Список услуг пока пуст.');
                }
                return SizedBox(
                  height: 196,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: services.length,
                    separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
                    itemBuilder: (context, index) {
                      final item = services[index];
                      return _ServiceCard(
                        name: (item['name'] ?? 'Услуга').toString(),
                        price: (item['price'] ?? 0).toString(),
                        imageUrl: (item['image_url'] ?? '').toString(),
                        rating: (item['avg_rating'] ?? '').toString(),
                        reviewsCount: item['reviews_count'] as int? ?? 0,
                        onTap: () => context.go('/services/${item['id']}'),
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.xl),
            _SectionHeader(
              title: 'Наши мастера',
              onAllTap: () => context.go(AppRoutes.masters),
            ),
            const SizedBox(height: AppSpacing.sm),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _loadMasters(),
              builder: (context, snapshot) {
                final masters = snapshot.data ?? const [];
                if (masters.isEmpty) {
                  return const Text('Список мастеров пока пуст.');
                }
                return SizedBox(
                  height: 160,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: masters.length,
                    separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
                    itemBuilder: (context, index) {
                      final item = masters[index];
                      return _MasterChip(
                        name: (item['specialty'] ?? 'Мастер').toString(),
                        subtitle: (item['level'] ?? '').toString(),
                        avatarUrl: (item['avatar_url'] ?? '').toString(),
                        onTap: () => context.go('/masters/${item['id']}'),
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            _LocationTile(onTap: () => showSalonLocationSheet(context)),
          ],
        ),
      ),
      floatingActionButton: isAuthed
          ? FloatingActionButton.extended(
              onPressed: () => context.go(AppRoutes.booking),
              icon: const Icon(Icons.add),
              label: const Text('Записаться'),
            )
          : FloatingActionButton.extended(
              onPressed: () {
                AppSnackbar.showInfo(
                  context,
                  'Войдите в аккаунт, чтобы записаться.',
                );
                context.go(AppRoutes.login);
              },
              icon: const Icon(Icons.lock_outline),
              label: const Text('Войти и записаться'),
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onAllTap;

  const _SectionHeader({required this.title, required this.onAllTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        TextButton(onPressed: onAllTap, child: Text('Все', style: TextStyle(color: cs.primary))),
      ],
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final String name;
  final String price;
  final String imageUrl;
  final String rating;
  final int reviewsCount;
  final VoidCallback onTap;

  const _ServiceCard({
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.rating,
    required this.reviewsCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.86),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: SizedBox(
            width: 146,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 68,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE8F0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: imageUrl.isEmpty
                        ? const Center(child: Icon(Icons.image_outlined))
                        : Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (_, __, ___) =>
                                const Center(child: Icon(Icons.broken_image_outlined)),
                          ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  rating.isEmpty ? 'Нет отзывов' : '⭐ $rating ($reviewsCount)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text('от $price ₽', style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF6E48B8))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MasterChip extends StatelessWidget {
  final String name;
  final String subtitle;
  final String avatarUrl;
  final VoidCallback onTap;

  const _MasterChip({
    required this.name,
    required this.subtitle,
    required this.avatarUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 92,
        child: Column(
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: const Color(0xFFE0DDE3),
              backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
              child: avatarUrl.isEmpty ? const Icon(Icons.person, size: 34) : null,
            ),
            const SizedBox(height: 8),
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall),
            Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFFF0ECF7), borderRadius: BorderRadius.circular(20)),
              child: const Text('⭐ 5.0', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationTile extends StatelessWidget {
  final VoidCallback onTap;

  const _LocationTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        onTap: onTap,
        leading: const Icon(Icons.location_on_outlined),
        title: const Text('Локация салона'),
        subtitle: const Text('Адрес, контакты и график работы'),
        trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
      ),
    );
  }
}
