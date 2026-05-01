import 'package:app_template/nav.dart';
import 'package:app_template/supabase/supabase_config.dart';
import 'package:app_template/theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ServiceDetailsPage extends StatefulWidget {
  final int serviceId;
  const ServiceDetailsPage({super.key, required this.serviceId});

  @override
  State<ServiceDetailsPage> createState() => _ServiceDetailsPageState();
}

class _ServiceDetailsPageState extends State<ServiceDetailsPage> {
  late Future<Map<String, dynamic>?> _serviceFuture;
  late Future<List<Map<String, dynamic>>> _mastersFuture;
  late Future<Map<String, dynamic>> _ratingFuture;

  @override
  void initState() {
    super.initState();
    _serviceFuture = SupabaseService.selectSingle(
      'services',
      filters: {'id': widget.serviceId},
    );
    _mastersFuture = SupabaseConfig.client
        .from('master_services')
        .select(
          'master_id, price, duration, masters(id, specialty, level)',
        )
        .eq('service_id', widget.serviceId);
    _ratingFuture = _loadServiceRating();
  }

  Future<Map<String, dynamic>> _loadServiceRating() async {
    final rows = await SupabaseConfig.client
        .from('reviews')
        .select('rating, appointments(service_id)');
    double sum = 0;
    int count = 0;
    for (final row in List<Map<String, dynamic>>.from(rows)) {
      final appointment = row['appointments'] as Map<String, dynamic>?;
      final serviceId = appointment?['service_id'];
      final rating = row['rating'];
      if (serviceId == widget.serviceId && rating is num) {
        sum += rating.toDouble();
        count += 1;
      }
    }
    return {
      'avg': count == 0 ? null : (sum / count).toStringAsFixed(1),
      'count': count,
    };
  }

  String _displayMasterName(Map<String, dynamic>? master) {
    if (master == null) return 'Специалист';
    final fullName = (master['full_name'] ?? '').toString().trim();
    if (fullName.isNotEmpty) return fullName;
    final fallbackName = (master['name'] ?? '').toString().trim();
    if (fallbackName.isNotEmpty) return fallbackName;
    return (master['specialty'] ?? 'Специалист').toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEF7FF),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _serviceFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text('Не удалось загрузить услугу: ${snapshot.error}'),
              ),
            );
          }
          final service = snapshot.data;
          if (service == null) {
            return const Center(child: Text('Услуга не найдена'));
          }

          final title = (service['name'] ?? 'Услуга').toString();
          final description = (service['description'] ?? 'Описание скоро появится.').toString();
          final duration = (service['duration'] ?? 90).toString();
          final imageUrl = (service['image_url'] ?? '').toString();
          final rawPrice = service['price'];
          final price = rawPrice is num ? rawPrice.toStringAsFixed(0) : rawPrice.toString();

          return FutureBuilder<Map<String, dynamic>>(
            future: _ratingFuture,
            builder: (context, ratingSnapshot) {
              final avg = ratingSnapshot.data?['avg'] as String?;
              final count = ratingSnapshot.data?['count'] as int? ?? 0;
              return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 320,
                      width: double.infinity,
                      child: imageUrl.isEmpty
                          ? const ColoredBox(color: Color(0xFFF8F1FA))
                          : Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const ColoredBox(color: Color(0xFFF8F1FA)),
                            ),
                    ),
                    Transform.translate(
                      offset: const Offset(0, -32),
                      child: Container(
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFEF7FF),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                        ),
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    fontSize: 16,
                                    height: 1.25,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.5,
                                    color: const Color(0xFF1D1A20),
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.star_rounded,
                                    size: 16, color: Color(0xFFB7A922)),
                                const SizedBox(width: 4),
                                Text(
                                  avg ?? '-',
                                  style: TextStyle(fontSize: 16, color: Color(0xFF1D1A20)),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '($count)',
                                  style: TextStyle(fontSize: 16, color: Color(0xFF7B7581)),
                                ),
                                const SizedBox(width: 12),
                                const _DotDivider(),
                                const SizedBox(width: 12),
                                const Icon(Icons.access_time_rounded,
                                    size: 16, color: Color(0xFF4A4550)),
                                const SizedBox(width: 4),
                                Text(
                                  '$duration min',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Color(0xFF4A4550),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const _DotDivider(),
                                const SizedBox(width: 12),
                                Text(
                                  '$price ₽',
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF6D4EA2),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 22),
                            Text(
                              description,
                              style: const TextStyle(
                                fontSize: 16,
                                height: 1.5,
                                color: Color(0xFF4A4550),
                              ),
                            ),
                            const SizedBox(height: 26),
                            const Text(
                              'Доступные специалисты',
                              style: TextStyle(
                                fontSize: 16,
                                height: 1.2,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.2,
                                color: Color(0xFF1D1A20),
                              ),
                            ),
                            const SizedBox(height: 12),
                            FutureBuilder<List<Map<String, dynamic>>>(
                              future: _mastersFuture,
                              builder: (context, mastersSnapshot) {
                                if (mastersSnapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const SizedBox(
                                    height: 188,
                                    child: Center(child: CircularProgressIndicator()),
                                  );
                                }
                                if (mastersSnapshot.hasError) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Text(
                                      'Не удалось загрузить специалистов: ${mastersSnapshot.error}',
                                    ),
                                  );
                                }

                                final mastersRows = mastersSnapshot.data ?? [];
                                if (mastersRows.isEmpty) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Text('Для этой услуги пока нет назначенных мастеров.'),
                                  );
                                }

                                return SizedBox(
                                  height: 188,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: mastersRows.length,
                                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                                    itemBuilder: (context, index) {
                                      final row = mastersRows[index];
                                      final master = row['masters'] as Map<String, dynamic>?;
                                      final masterId = master?['id'];
                                      final rowDuration = row['duration']?.toString() ??
                                          (service['duration']?.toString() ?? '-');
                                      final rowPrice = row['price'];
                                      final rowPriceText = rowPrice is num
                                          ? rowPrice.toStringAsFixed(0)
                                          : rowPrice?.toString() ?? '-';
                                      final level = (master?['level'] ?? '').toString().trim();
                                      final masterAvatar =
                                          (master?['avatar_url'] ?? '').toString();

                                      return _MasterCard(
                                        name: _displayMasterName(master),
                                        rating: null,
                                        subtitle: level.isEmpty
                                            ? '$rowDuration мин • $rowPriceText ₽'
                                            : '$level • $rowDuration мин • $rowPriceText ₽',
                                        imageUrl: masterAvatar.isEmpty ? null : masterAvatar,
                                        onTap: masterId is int
                                            ? () => context.go('/masters/$masterId')
                                            : null,
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Container(
                    height: 64,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.8),
                      border: const Border(
                        bottom: BorderSide(color: Color(0xFFF4F4F5)),
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => context.go(AppRoutes.services),
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: Color(0xFFC5A3FF),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Стриж',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: const Color(0xFF18181B),
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => context.go(AppRoutes.notifications),
                          icon: const Icon(
                            Icons.notifications_none_rounded,
                            color: Color(0xFFC5A3FF),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 24,
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => context.go(
                      '${AppRoutes.booking}?serviceId=${widget.serviceId}',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC5A3FF),
                      foregroundColor: const Color(0xFF533487),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Записаться',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ],
          );
            },
          );
        },
      ),
    );
  }
}

class _DotDivider extends StatelessWidget {
  const _DotDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: 4,
      decoration: const BoxDecoration(
        color: Color(0xFFCCC3D2),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _MasterCard extends StatelessWidget {
  final String name;
  final String? rating;
  final String subtitle;
  final String? imageUrl;
  final VoidCallback? onTap;

  const _MasterCard({
    required this.name,
    required this.rating,
    required this.subtitle,
    required this.imageUrl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8F1FA),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 140,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                child: imageUrl == null
                    ? Container(
                        color: const Color(0xFFE7E0E8),
                        child: const Icon(
                          Icons.person_outline,
                          size: 28,
                          color: Color(0xFF4A4550),
                        ),
                      )
                    : Image.network(
                        imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFFE7E0E8),
                          child: const Icon(Icons.person_outline),
                        ),
                      ),
              ),
              const SizedBox(height: 8),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFF1D1A20),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF4A4550),
                ),
              ),
              if (rating != null) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: 12,
                      color: Color(0xFFB7A922),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      rating ?? '-',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF4A4550),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
