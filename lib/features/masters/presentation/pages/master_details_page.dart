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

  Future<void> _showSalonInfoSheet() {
    final cs = Theme.of(context).colorScheme;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) => const _SalonInfoSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFFFEF7FF),
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
                        AppSpacing.xxl,
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
                              color: Colors.white.withValues(alpha: 0.88),
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                            ),
                            child: Text(
                              bio.isEmpty
                                  ? 'Опытный мастер салона, поможет подобрать подходящую услугу.'
                                  : bio,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          InkWell(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            onTap: _showSalonInfoSheet,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.location_on_outlined,
                                    size: 18,
                                    color: cs.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Минск, ул. Центральная, 12',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall?.withColor(cs.onSurfaceVariant),
                                  ),
                                ],
                              ),
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
                                      color: Colors.white.withValues(alpha: 0.9),
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
                                    color: Colors.white.withValues(alpha: 0.9),
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

class _SalonInfoSheet extends StatelessWidget {
  const _SalonInfoSheet();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Свяжитесь с нами',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Мы всегда рады помочь вам с выбором услуг и ответить на любые вопросы.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.withColor(cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _ContactCard(
                  title: 'Телефон',
                  subtitle: 'Ответим на ваши звонки',
                  icon: Icons.phone,
                  content: '+7 (999) 123-45-67',
                  actionLabel: 'Позвонить',
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _ScheduleCard(
                  title: 'Режим работы',
                  subtitle: 'Ждем вас каждый день',
                  icon: Icons.schedule,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: cs.surfaceContainerHighest,
                child: Icon(
                  Icons.location_on,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Наш адрес',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'г. Минск, ул. Центральная, д. 12',
                      style: Theme.of(context).textTheme.bodyMedium?.withColor(
                        cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              image: const DecorationImage(
                image: NetworkImage(
                  'https://images.unsplash.com/photo-1524661135-423995f22d0b?w=1200&q=80&auto=format&fit=crop',
                ),
                fit: BoxFit.cover,
              ),
            ),
            child: Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFB388FF),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(Icons.location_on, color: Colors.white, size: 36),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String content;
  final String actionLabel;

  const _ContactCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.content,
    required this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFB388FF).withValues(alpha: 0.3),
                child: Icon(icon, size: 18, color: const Color(0xFF6D4EA2)),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.withColor(
                        cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            content,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB388FF),
              minimumSize: const Size(double.infinity, 42),
            ),
            onPressed: () {},
            icon: const Icon(Icons.phone_outlined, size: 18),
            label: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _ScheduleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: cs.surface,
                child: Icon(icon, size: 18, color: cs.onSurfaceVariant),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.withColor(
                        cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const _TimeRow(dayRange: 'Пн - Пт', time: '10:00 - 22:00'),
          Divider(color: cs.outline.withValues(alpha: 0.2)),
          const _TimeRow(dayRange: 'Сб - Вс', time: '11:00 - 21:00'),
        ],
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  final String dayRange;
  final String time;

  const _TimeRow({required this.dayRange, required this.time});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(dayRange),
          const Spacer(),
          Text(time, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
