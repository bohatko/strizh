import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app_template/nav.dart';
import 'package:app_template/supabase/supabase_config.dart';
import 'package:app_template/theme.dart';

class MasterDetailsPage extends StatefulWidget {
  final int masterId;
  const MasterDetailsPage({super.key, required this.masterId});

  @override
  State<MasterDetailsPage> createState() => _MasterDetailsPageState();
}

class _MasterDetailsPageState extends State<MasterDetailsPage> {
  late Future<Map<String, dynamic>?> _masterFuture;
  late Future<List<Map<String, dynamic>>> _servicesFuture;
  late Future<List<Map<String, dynamic>>> _reviewsFuture;
  static const List<String> _monthsRu = [
    'января',
    'февраля',
    'марта',
    'апреля',
    'мая',
    'июня',
    'июля',
    'августа',
    'сентября',
    'октября',
    'ноября',
    'декабря',
  ];

  @override
  void initState() {
    super.initState();
    _masterFuture = SupabaseService.selectSingle(
      'masters',
      filters: {'id': widget.masterId},
    );
    _servicesFuture = SupabaseConfig.client
        .from('master_services')
        .select('service_id, price, duration, services(id, name, category)')
        .eq('master_id', widget.masterId);
    _reviewsFuture = SupabaseConfig.client
        .from('reviews')
        .select('id, rating, text, created_at')
        .eq('master_id', widget.masterId)
        .order('created_at', ascending: false);
  }

  String _formatDateTime(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final local = parsed.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = _monthsRu[local.month - 1];
    final year = local.year;
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day $month $year в $hour:$minute';
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRoutes.masters);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(title: const Text('Профиль мастера')),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _masterFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Failed to load master: ${snapshot.error}'));
          }
          final master = snapshot.data;
          if (master == null) {
            return const Center(child: Text('Мастер не найден'));
          }
          final workImages =
              (master['works_images'] as List<dynamic>? ?? const <dynamic>[])
                  .map((item) => item.toString())
                  .toList();
          final avatarUrl = (master['avatar_url'] ?? '').toString();
          final title = (master['specialty'] ?? 'Мастер').toString();
          final level = (master['level'] ?? 'Не указан').toString();
          final bio = (master['bio'] ?? '').toString();
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: _reviewsFuture,
            builder: (context, reviewSnapshot) {
              final reviews = reviewSnapshot.data ?? const [];
              final ratings = reviews
                  .map((r) => (r['rating'] as num?)?.toDouble())
                  .whereType<double>()
                  .toList();
              final avgRating = ratings.isEmpty
                  ? null
                  : (ratings.reduce((a, b) => a + b) / ratings.length);
              return CustomScrollView(
                slivers: [
                  SliverAppBar(
                    expandedHeight: 210,
                    pinned: true,
                    backgroundColor: const Color(0xFFAB7BEE),
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      onPressed: _handleBack,
                    ),
                    flexibleSpace: FlexibleSpaceBar(
                      titlePadding: const EdgeInsetsDirectional.only(
                        start: 16,
                        bottom: 14,
                      ),
                      title: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (avatarUrl.isNotEmpty)
                            Image.network(avatarUrl, fit: BoxFit.cover)
                          else
                            Container(color: const Color(0xFFAB7BEE)),
                          Container(color: Colors.black.withValues(alpha: 0.28)),
                          Positioned(
                            left: AppSpacing.lg,
                            right: AppSpacing.lg,
                            bottom: AppSpacing.lg,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.92),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    level,
                                    style: const TextStyle(
                                      color: Color(0xFF6D4EA2),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.92),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    avgRating == null
                                        ? 'Нет оценок'
                                        : '⭐ ${avgRating.toStringAsFixed(1)} (${ratings.length})',
                                    style: const TextStyle(
                                      color: Color(0xFF333333),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.lg,
                        120,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('О мастере', style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: AppSpacing.sm),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                            ),
                            child: Text(
                              bio.isEmpty
                                  ? 'Опытный мастер салона, поможет подобрать подходящую услугу.'
                                  : bio,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            'Примеры работ',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          if (workImages.isEmpty)
                            Text(
                              'Примеры работ пока не добавлены.',
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.withColor(cs.onSurfaceVariant),
                            )
                          else
                            SizedBox(
                              height: 112,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: workImages.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: AppSpacing.sm),
                                itemBuilder: (context, index) {
                                  final url = workImages[index];
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      width: 140,
                                      color: cs.surfaceContainerHighest,
                                      child: Image.network(
                                        url,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Center(
                                          child: Icon(Icons.broken_image_outlined),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          const SizedBox(height: AppSpacing.xl),
                          Text(
                            'Услуги мастера',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          FutureBuilder<List<Map<String, dynamic>>>(
                            future: _servicesFuture,
                            builder: (context, servicesSnapshot) {
                              if (servicesSnapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                              if (servicesSnapshot.hasError) {
                                return Text(
                                  'Ошибка загрузки услуг: ${servicesSnapshot.error}',
                                );
                              }
                              final services = servicesSnapshot.data ?? [];
                              if (services.isEmpty) {
                                return Text(
                                  'У этого мастера пока нет привязанных услуг.',
                                  style: Theme.of(context).textTheme.bodySmall?.withColor(
                                    cs.onSurfaceVariant,
                                  ),
                                );
                              }
                              return Column(
                                children: services.map((item) {
                                  final service = item['services'] as Map<String, dynamic>?;
                                  final serviceId = service?['id'];
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                                    decoration: BoxDecoration(
                                      color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                                      borderRadius: BorderRadius.circular(AppRadius.lg),
                                    ),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.md,
                                        vertical: AppSpacing.xs,
                                      ),
                                      title: Text(
                                        (service?['name'] ?? 'Услуга').toString(),
                                      ),
                                      subtitle: Text(
                                        '${item['duration'] ?? '-'} мин • ${item['price'] ?? '-'} ₽',
                                      ),
                                      trailing: const Icon(Icons.chevron_right),
                                      onTap: serviceId == null
                                          ? null
                                          : () => context.go('/services/$serviceId'),
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          Text('Отзывы', style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: AppSpacing.sm),
                          if (reviewSnapshot.connectionState ==
                              ConnectionState.waiting)
                            const Center(child: CircularProgressIndicator())
                          else if (reviewSnapshot.hasError)
                            Text('Ошибка загрузки отзывов: ${reviewSnapshot.error}')
                          else if (reviews.isEmpty)
                            Text(
                              'Пока нет отзывов об этом мастере.',
                              style: Theme.of(context).textTheme.bodySmall?.withColor(
                                cs.onSurfaceVariant,
                              ),
                            )
                          else
                            Column(
                              children: reviews.map((review) {
                                final rating = review['rating'] ?? '-';
                                final text = (review['text'] ?? '').toString();
                                final createdAt = _formatDateTime(
                                  (review['created_at'] ?? '').toString(),
                                );
                                return Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                                  padding: const EdgeInsets.all(AppSpacing.md),
                                  decoration: BoxDecoration(
                                    color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(AppRadius.lg),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            '⭐ $rating',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const Spacer(),
                                          Text(
                                            createdAt,
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.withColor(cs.onSurfaceVariant),
                                          ),
                                        ],
                                      ),
                                      if (text.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(text),
                                      ],
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(
          '${AppRoutes.booking}?masterId=${widget.masterId}',
        ),
        icon: const Icon(Icons.calendar_month_outlined),
        label: const Text('Записаться'),
      ),
    );
  }
}
