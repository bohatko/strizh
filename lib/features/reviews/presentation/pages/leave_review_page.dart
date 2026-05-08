import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app_template/core/ui/app_button.dart';
import 'package:app_template/core/ui/app_snackbar.dart';
import 'package:app_template/features/auth/presentation/controllers/auth_controller.dart';
import 'package:app_template/features/auth/presentation/models/auth_state.dart';
import 'package:app_template/nav.dart';
import 'package:app_template/supabase/supabase_config.dart';
import 'package:app_template/theme.dart';

class LeaveReviewPage extends ConsumerStatefulWidget {
  final int appointmentId;
  const LeaveReviewPage({super.key, required this.appointmentId});

  @override
  ConsumerState<LeaveReviewPage> createState() => _LeaveReviewPageState();
}

class _LeaveReviewPageState extends ConsumerState<LeaveReviewPage> {
  final _controller = TextEditingController();
  int _rating = 5;
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final authValue = ref.read(authControllerProvider).asData?.value;
    if (authValue is! Authenticated) {
      context.go(AppRoutes.login);
      return;
    }

    setState(() => _loading = true);
    try {
      final appointment = await SupabaseService.selectSingle(
        'appointments',
        filters: {'id': widget.appointmentId},
      );
      if (appointment == null) {
        throw Exception('Запись не найдена.');
      }
      final status = (appointment['status'] ?? '').toString();
      if (status != 'completed') {
        throw Exception('Оставить отзыв можно только для завершённой записи.');
      }
      final serviceId = appointment['service_id'];
      if (serviceId is! int) {
        throw Exception('Не удалось определить услугу для записи.');
      }
      final existingReviews = await SupabaseConfig.client
          .from('reviews')
          .select('id, master_id, appointments!inner(service_id)')
          .eq('client_id', authValue.user.id)
          .eq('appointments.service_id', serviceId)
          .limit(1);
      final existing = List<Map<String, dynamic>>.from(existingReviews);
      if (existing.isNotEmpty) {
        final existingMasterId = existing.first['master_id'];
        if (!mounted) return;
        AppSnackbar.showInfo(
          context,
          'Отзыв на эту услугу уже оставлен. Открываю страницу мастера.',
        );
        final targetMasterId = existingMasterId is int
            ? existingMasterId
            : appointment['master_id'];
        if (targetMasterId is int) {
          context.go('/masters/$targetMasterId?scrollTo=reviews');
          return;
        }
        context.go(AppRoutes.myAppointments);
        return;
      }
      await SupabaseService.insert('reviews', {
        'appointment_id': widget.appointmentId,
        'client_id': authValue.user.id,
        'master_id': appointment['master_id'],
        'rating': _rating,
        'text': _controller.text.trim(),
      });
      if (!mounted) return;
      AppSnackbar.showInfo(context, 'Отзыв отправлен.');
      context.go(AppRoutes.myAppointments);
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.showError(context, 'Не удалось отправить отзыв: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Оставить отзыв')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              'Запись #${widget.appointmentId}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Оценка', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: List.generate(5, (index) {
                final star = index + 1;
                return IconButton(
                  onPressed: () => setState(() => _rating = star),
                  icon: Icon(
                    star <= _rating ? Icons.star : Icons.star_outline,
                    color: Colors.amber,
                  ),
                );
              }),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _controller,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Ваш отзыв',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Отправить отзыв',
              isLoading: _loading,
              onPressed: _loading ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
