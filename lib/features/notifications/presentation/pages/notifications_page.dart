import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_template/features/auth/presentation/controllers/auth_controller.dart';
import 'package:app_template/features/auth/presentation/models/auth_state.dart';
import 'package:app_template/supabase/supabase_config.dart';
import 'package:app_template/theme.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  late Future<List<Map<String, dynamic>>> _notificationsFuture;
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
    _notificationsFuture = _loadNotifications();
  }

  Future<List<Map<String, dynamic>>> _loadNotifications() {
    final authValue = ref.read(authControllerProvider).asData?.value;
    if (authValue is Authenticated) {
      return SupabaseConfig.client
          .from('notifications')
          .select()
          .or('user_id.is.null,user_id.eq.${authValue.user.id}')
          .order('created_at', ascending: false);
    }
    return SupabaseConfig.client
        .from('notifications')
        .select()
        .isFilter('user_id', null)
        .order('created_at', ascending: false);
  }

  Future<void> _markAsRead(int id) async {
    await SupabaseService.update(
      'notifications',
      {'is_read': true},
      filters: {'id': id},
    );
    if (!mounted) return;
    setState(() {
      _notificationsFuture = _loadNotifications();
    });
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Уведомления'),
        centerTitle: false,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _notificationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text('Не удалось загрузить уведомления: ${snapshot.error}'),
              ),
            );
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return Center(
              child: Text(
                'Пока нет уведомлений.',
                style: Theme.of(context).textTheme.bodyMedium?.withColor(
                  cs.onSurfaceVariant,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final n = items[index];
              final id = n['id'] as int?;
              final isRead = n['is_read'] == true;
              final card = Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: isRead
                      ? cs.surfaceContainerHighest.withValues(alpha: 0.2)
                      : cs.primaryContainer.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            (n['title'] ?? 'Уведомление').toString(),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: cs.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        if (!isRead && id != null) ...[
                          const SizedBox(width: AppSpacing.sm),
                          TextButton(
                            onPressed: () => _markAsRead(id),
                            child: const Text('Прочитано'),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      (n['body'] ?? '').toString(),
                      style: Theme.of(context).textTheme.bodyMedium?.withColor(
                        cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatDateTime((n['created_at'] ?? '').toString()),
                      style: Theme.of(context).textTheme.labelSmall?.withColor(
                        cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
              if (id == null || isRead) return card;
              return Dismissible(
                key: ValueKey('notification-$id'),
                direction: DismissDirection.horizontal,
                background: _SwipeBackground(
                  alignStart: true,
                  label: 'Прочитано',
                ),
                secondaryBackground: _SwipeBackground(
                  alignStart: false,
                  label: 'Прочитано',
                ),
                onDismissed: (_) => _markAsRead(id),
                child: card,
              );
            },
          );
        },
      ),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  final bool alignStart;
  final String label;

  const _SwipeBackground({required this.alignStart, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      alignment: alignStart ? Alignment.centerLeft : Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.done_rounded),
          const SizedBox(width: AppSpacing.xs),
          Text(label),
        ],
      ),
    );
  }
}
