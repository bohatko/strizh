import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app_template/core/ui/app_snackbar.dart';
import 'package:app_template/features/auth/presentation/controllers/auth_controller.dart';
import 'package:app_template/features/auth/presentation/models/auth_state.dart';
import 'package:app_template/nav.dart';
import 'package:app_template/supabase/supabase_config.dart';
import 'package:app_template/theme.dart';

class MyAppointmentsPage extends ConsumerStatefulWidget {
  const MyAppointmentsPage({super.key});

  @override
  ConsumerState<MyAppointmentsPage> createState() => _MyAppointmentsPageState();
}

class _MyAppointmentsPageState extends ConsumerState<MyAppointmentsPage> {
  static const _accent = Color(0xFF6D4EA2);
  static const _textPrimary = Color(0xFF1D1A20);
  static const _textSecondary = Color(0xFF5E5965);
  static const _danger = Color(0xFFC3423F);

  late Future<List<Map<String, dynamic>>> _appointmentsFuture;
  bool _showUpcoming = true;

  @override
  void initState() {
    super.initState();
    _appointmentsFuture = _loadAppointments();
  }

  Future<List<Map<String, dynamic>>> _loadAppointments() async {
    final authValue = ref.read(authControllerProvider).asData?.value;
    if (authValue is! Authenticated) {
      return const [];
    }
    final rows = await SupabaseConfig.client
        .from('appointments')
        .select('id, appointment_time, status, masters(specialty), services(name)')
        .eq('client_id', authValue.user.id)
        .order('appointment_time', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> _cancelAppointment(int appointmentId) async {
    try {
      await SupabaseService.update(
        'appointments',
        {'status': 'cancelled'},
        filters: {'id': appointmentId},
      );
      setState(() {
        _appointmentsFuture = _loadAppointments();
      });
      if (!mounted) return;
      AppSnackbar.showInfo(context, 'Запись отменена.');
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.showError(context, 'Не удалось отменить запись: $e');
    }
  }

  Future<void> _confirmAndCancelAppointment(int appointmentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFBFAFD),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFE6DFEC)),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: const Text(
            'Отменить запись?',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: const Text(
            'Вы уверены, что хотите отменить запись? Записаться заново можно в любое время.',
            style: TextStyle(
              color: _textSecondary,
              fontSize: 14,
              height: 1.35,
            ),
          ),
          actions: [
            SizedBox(
              height: 44,
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: _textSecondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Color(0xFFD7D0DE)),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Нет'),
              ),
            ),
            SizedBox(
              height: 44,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _danger,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Да, отменить'),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _cancelAppointment(appointmentId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authValue = ref.watch(authControllerProvider).asData?.value;
    final isAuthed = authValue is Authenticated;
    final cs = Theme.of(context).colorScheme;

    if (!isAuthed) {
      return Scaffold(
        appBar: AppBar(title: const Text('Мои записи')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Войдите, чтобы увидеть ваши записи.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  onPressed: () => context.go(AppRoutes.login),
                  child: const Text('Войти'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: cs.surface,
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _appointmentsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Ошибка загрузки: ${snapshot.error}'));
          }
          final appointments = snapshot.data ?? [];
          final upcoming = appointments
              .where((a) => _isUpcoming((a['status'] ?? '').toString()))
              .toList();
          final history = appointments
              .where((a) => !_isUpcoming((a['status'] ?? '').toString()))
              .toList();
          final visible = _showUpcoming ? upcoming : history;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            children: [
              Text(
                'Мои записи',
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 16,
                  height: 1.05,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              _buildTabs(),
              const SizedBox(height: 18),
              if (visible.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Text(
                    _showUpcoming
                        ? 'Нет предстоящих записей'
                        : 'История записей пока пуста',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
                  ),
                ),
              ...visible.map((item) {
                final status = (item['status'] ?? '').toString();
                final id = item['id'] as int;
                final canReview = status == 'completed';
                final canCancel = status == 'pending' || status == 'confirmed';
                final master = item['masters'] as Map<String, dynamic>?;
                final service = item['services'] as Map<String, dynamic>?;
                final dt = DateTime.tryParse((item['appointment_time'] ?? '').toString());
                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _StatusPill(status: status),
                                const SizedBox(height: 10),
                                Text(
                                  (service?['name'] ?? 'Услуга').toString(),
                                  style: TextStyle(
                                    color: cs.onSurface,
                                    fontSize: 14,
                                    height: 1.1,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.person_outline_rounded,
                                      size: 18,
                                      color: cs.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        (master?['specialty'] ?? 'Мастер').toString(),
                                        style: TextStyle(
                                          color: cs.onSurfaceVariant,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _timeLabel(dt),
                                style: TextStyle(
                                  color: cs.primary,
                                  fontSize: 14,
                                  height: 0.9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _dateLabel(dt),
                                style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Divider(color: cs.outline.withValues(alpha: 0.25)),
                      const SizedBox(height: 8),
                      if (canCancel)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => _confirmAndCancelAppointment(id),
                            child: const Text(
                              'Отменить запись',
                              style: TextStyle(color: _danger, fontSize: 14),
                            ),
                          ),
                        )
                      else if (canReview)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => context.go('/appointments/$id/review'),
                            child: const Text(
                              'Оставить отзыв',
                              style: TextStyle(color: _accent, fontSize: 14),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTabs() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _tabButton(
              label: 'Предстоящие',
              active: _showUpcoming,
              onTap: () => setState(() => _showUpcoming = true),
            ),
          ),
          Expanded(
            child: _tabButton(
              label: 'История',
              active: !_showUpcoming,
              onTap: () => setState(() => _showUpcoming = false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabButton({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? cs.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: active ? cs.primary : cs.onSurface,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  static bool _isUpcoming(String status) {
    return status == 'pending' || status == 'confirmed';
  }

  static String _timeLabel(DateTime? dt) {
    if (dt == null) return '--:--';
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  static String _dateLabel(DateTime? dt) {
    if (dt == null) return 'Без даты';
    final month = _monthsGenitive[dt.month - 1];
    return '${dt.day} $month';
  }

  static const _monthsGenitive = <String>[
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
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final statusRu = switch (status) {
      'confirmed' => 'Подтверждено',
      'pending' => 'Ожидает',
      'completed' => 'Завершено',
      'cancelled' => 'Отменено',
      _ => status,
    };
    final color = switch (status) {
      'confirmed' => const Color(0xFF6D4EA2),
      'pending' => const Color(0xFF8A8441),
      'completed' => const Color(0xFF1F8A5A),
      'cancelled' => const Color(0xFFC3423F),
      _ => const Color(0xFF6D4EA2),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        statusRu,
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
