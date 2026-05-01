import 'package:app_template/nav.dart';
import 'package:app_template/core/ui/admin_access_icon.dart';
import 'package:app_template/supabase/supabase_config.dart';
import 'package:app_template/theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ServicesListPage extends StatefulWidget {
  const ServicesListPage({super.key});

  @override
  State<ServicesListPage> createState() => _ServicesListPageState();
}

class _ServicesListPageState extends State<ServicesListPage> {
  late Future<List<Map<String, dynamic>>> _servicesFuture;
  final _searchController = TextEditingController();
  String _query = '';
  String _selectedCategory = 'Все';

  @override
  void initState() {
    super.initState();
    _servicesFuture = _loadServicesWithStats();
  }

  Future<List<Map<String, dynamic>>> _loadServicesWithStats() async {
    final services = await SupabaseService.select(
      'services',
      orderBy: 'created_at',
      ascending: false,
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> _buildCategoryOrder(List<Map<String, dynamic>> services) {
    final categories = services
        .map((item) => (item['category'] ?? '').toString().trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['Все', ...categories];
  }

  List<Map<String, dynamic>> _filterServices(List<Map<String, dynamic>> all) {
    final q = _query.toLowerCase();
    return all.where((service) {
      final name = (service['name'] ?? '').toString().toLowerCase();
      final description = (service['description'] ?? '').toString().toLowerCase();
      final category = (service['category'] ?? '').toString();
      final matchesQuery = q.isEmpty || name.contains(q) || description.contains(q);
      final matchesCategory = _selectedCategory == 'Все' || category == _selectedCategory;
      return matchesQuery && matchesCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const AdminAccessIcon(),
        title: const Text('Список услуг'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => context.go(AppRoutes.notifications),
            icon: Icon(
              Icons.notifications_none_rounded,
              color: cs.primary,
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _servicesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text('Не удалось загрузить услуги: ${snapshot.error}'),
              ),
            );
          }

          final services = snapshot.data ?? [];
          final categories = _buildCategoryOrder(services);
          if (!categories.contains(_selectedCategory)) {
            _selectedCategory = 'Все';
          }
          final filtered = _filterServices(services);
          return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) => setState(() => _query = value.trim()),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Поиск услуг...',
                          hintStyle: const TextStyle(
                            color: Color(0xFF999999),
                            fontSize: 16,
                          ),
                          prefixIcon: const Icon(Icons.search_rounded),
                          contentPadding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 60,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: categories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final category = categories[index];
                          final isSelected = _selectedCategory == category;
                          return ChoiceChip(
                            label: Text(category),
                            selected: isSelected,
                            onSelected: (_) => setState(() => _selectedCategory = category),
                            side: BorderSide.none,
                            backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.45),
                            selectedColor: cs.primaryContainer.withValues(alpha: 0.5),
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? cs.primary
                                  : cs.onSurface,
                              fontSize: isSelected ? 14 : 16,
                            ),
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    const SizedBox(height: 4),
                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xl),
                        child: Text(
                          'По выбранным фильтрам услуги не найдены.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.withColor(
                                cs.onSurfaceVariant,
                              ),
                        ),
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filtered.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.68,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          final imageUrl = (item['image_url'] ?? '').toString();
                          final duration = (item['duration'] ?? 60).toString();
                          final rawPrice = item['price'];
                          final price = rawPrice is num
                              ? rawPrice.toStringAsFixed(0)
                              : rawPrice.toString();
                          final avgRating = (item['avg_rating'] ?? '').toString();
                          final rawReviewsCount = item['reviews_count'];
                          final reviewsCount = rawReviewsCount is num
                              ? rawReviewsCount.toInt()
                              : int.tryParse(rawReviewsCount?.toString() ?? '') ?? 0;
                          final serviceId = item['id'];

                          return _ServiceCard(
                            title: (item['name'] ?? 'Услуга').toString(),
                            duration: '$duration мин',
                            rating: avgRating.isEmpty ? null : avgRating,
                            reviewsCount: reviewsCount,
                            price: '$price ₽',
                            imageUrl: imageUrl,
                            onTap: () {
                              if (serviceId is! int) return;
                              context.go('/services/$serviceId');
                            },
                          );
                        },
                      ),
                  ],
                );
        },
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final String title;
  final String duration;
  final String? rating;
  final int reviewsCount;
  final String price;
  final String imageUrl;
  final VoidCallback onTap;

  const _ServiceCard({
    required this.title,
    required this.duration,
    required this.rating,
    required this.reviewsCount,
    required this.price,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Image.network(
                    imageUrl,
                    height: 104,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => ColoredBox(
                      color: cs.surfaceContainerHighest,
                      child: const Center(child: Icon(Icons.broken_image_outlined)),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: rating == null
                      ? const SizedBox.shrink()
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: cs.surface.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text('⭐ $rating ($reviewsCount)'),
                        ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          height: 1.2,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: Color(0xFF7B7581),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          duration,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF7B7581),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    price,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: cs.primary,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
