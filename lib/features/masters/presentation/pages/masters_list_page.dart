import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:app_template/nav.dart';
import 'package:app_template/supabase/supabase_config.dart';
import 'package:app_template/theme.dart';

class MastersListPage extends StatefulWidget {
  const MastersListPage({super.key});

  @override
  State<MastersListPage> createState() => _MastersListPageState();
}

class _MastersListPageState extends State<MastersListPage> {
  late Future<List<Map<String, dynamic>>> _mastersFuture;

  @override
  void initState() {
    super.initState();
    _mastersFuture = _loadMasters();
  }

  Future<List<Map<String, dynamic>>> _loadMasters() async {
    final rows = await SupabaseConfig.client
        .from('masters')
        .select('id, specialty, level, bio, avatar_url, master_services(services(name))')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFFFEF7FF),
      appBar: AppBar(title: const Text('Наши мастера')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _mastersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text('Failed to load masters: ${snapshot.error}'),
              ),
            );
          }
          final masters = snapshot.data ?? [];
          if (masters.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  'Мастера пока не добавлены.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.withColor(cs.onSurfaceVariant),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemBuilder: (context, index) {
              final master = masters[index];
              final id = master['id'] as int?;
              final name = (master['specialty'] ?? 'Мастер').toString();
              final level = (master['level'] ?? 'Не указан').toString();
              final bio = (master['bio'] ?? 'Профессиональный мастер салона Стриж.')
                  .toString();
              final avatarUrl = (master['avatar_url'] ?? '').toString();
              final rawMasterServices = (master['master_services'] as List<dynamic>? ??
                      const <dynamic>[])
                  .cast<Map<String, dynamic>>();
              final serviceNames = rawMasterServices
                  .map((item) => item['services'])
                  .whereType<Map<String, dynamic>>()
                  .map((service) => (service['name'] ?? '').toString())
                  .where((name) => name.isNotEmpty)
                  .toList();
              return _MasterTile(
                title: name,
                level: level,
                bio: bio,
                avatarUrl: avatarUrl,
                services: serviceNames,
                onTap: id == null ? null : () => context.go('/masters/$id'),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemCount: masters.length,
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(AppRoutes.services),
        icon: const Icon(Icons.spa_outlined),
        label: const Text('Услуги'),
      ),
    );
  }
}

class _MasterTile extends StatelessWidget {
  final String title;
  final String level;
  final String bio;
  final String avatarUrl;
  final List<String> services;
  final VoidCallback? onTap;

  const _MasterTile({
    required this.title,
    required this.level,
    required this.bio,
    required this.avatarUrl,
    required this.services,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: cs.primaryContainer,
                    backgroundImage: avatarUrl.isNotEmpty
                        ? NetworkImage(avatarUrl)
                        : null,
                    child: avatarUrl.isEmpty
                        ? Icon(Icons.person, color: cs.onPrimaryContainer)
                        : null,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          level,
                          style: Theme.of(context).textTheme.bodySmall?.withColor(
                            cs.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                bio,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.withColor(
                  cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: services.isEmpty
                    ? [
                        Chip(
                          label: const Text('Услуги добавляются'),
                          backgroundColor: cs.surfaceContainerHighest.withValues(
                            alpha: 0.4,
                          ),
                        ),
                      ]
                    : services
                        .map(
                          (service) => Chip(
                            label: Text(service),
                            backgroundColor: const Color(0xFFF3EDFF),
                            side: BorderSide.none,
                          ),
                        )
                        .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
