import 'package:app_template/core/ui/admin_access_icon.dart';
import 'package:app_template/core/ui/app_snackbar.dart';
import 'package:app_template/core/ui/safe_network_image.dart';
import 'package:app_template/features/auth/presentation/controllers/auth_controller.dart';
import 'package:app_template/features/auth/presentation/models/auth_state.dart';
import 'package:app_template/supabase/supabase_config.dart';
import 'package:app_template/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AdminPanelPage extends ConsumerStatefulWidget {
  const AdminPanelPage({super.key});

  @override
  ConsumerState<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends ConsumerState<AdminPanelPage>
    with SingleTickerProviderStateMixin {
  static const List<String> _appointmentStatuses = [
    'pending',
    'confirmed',
    'completed',
    'cancelled',
  ];

  late final TabController _tabController;
  bool _isBusy = false;
  late Future<List<Map<String, dynamic>>> _mastersFuture;
  late Future<List<Map<String, dynamic>>> _servicesFuture;
  late Future<List<Map<String, dynamic>>> _appointmentsFuture;
  late Future<List<Map<String, dynamic>>> _reviewsFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _reloadAllTabs();
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool get _isAdmin {
    final auth = ref.read(authControllerProvider).asData?.value;
    return auth is Authenticated && auth.user.role?.toLowerCase() == 'admin';
  }

  Future<List<Map<String, dynamic>>> _loadMasters() async {
    return SupabaseService.select(
      'masters',
      select: 'id, user_id, specialty, level, bio, avatar_url, created_at',
      orderBy: 'created_at',
      ascending: false,
    );
  }

  Future<List<Map<String, dynamic>>> _loadServices() async {
    return SupabaseService.select(
      'services',
      select: 'id, name, category, description, duration, price, image_url, created_at',
      orderBy: 'created_at',
      ascending: false,
    );
  }

  Future<List<Map<String, dynamic>>> _loadAppointments() async {
    final rows = await SupabaseConfig.client
        .from('appointments')
        .select(
          'id, client_id, appointment_time, status, created_at, '
          'masters(id, specialty), services(id, name)',
        )
        .order('created_at', ascending: false)
        .order('id', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> _loadReviews() async {
    final rows = await SupabaseConfig.client
        .from('reviews')
        .select(
          'id, appointment_id, client_id, master_id, rating, text, created_at, '
          'masters(id, specialty), appointments(id, appointment_time, services(name))',
        )
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> _loadMasterUsers({String? includeUserId}) async {
    final profiles = await SupabaseService.select(
      'profiles',
      select: 'id, email, display_name, first_name, last_name, created_at',
      orderBy: 'created_at',
      ascending: false,
    );
    final masters = await SupabaseService.select('masters', select: 'user_id');
    final usedIds = masters
        .map((row) => row['user_id'])
        .whereType<String>()
        .toSet();
    return profiles.where((profile) {
      final id = profile['id'];
      if (id is! String) return false;
      if (includeUserId != null && includeUserId == id) return true;
      return !usedIds.contains(id);
    }).toList();
  }

  Future<void> _deleteReview(int id) async {
    final shouldDelete = await _confirmDelete(
      title: 'Удалить отзыв?',
      message: 'Действие необратимо. Отзыв будет удалён из базы.',
    );
    if (!shouldDelete) return;
    await _runGuarded(() async {
      await SupabaseService.delete('reviews', filters: {'id': id});
      if (!mounted) return;
      AppSnackbar.showSuccess(context, 'Отзыв удалён');
    });
  }

  Future<void> _openReviewForm() async {
    final textCtrl = TextEditingController();
    int rating = 5;
    int? selectedAppointmentId;

    final completedAppointments = await SupabaseConfig.client
        .from('appointments')
        .select('id, client_id, master_id, appointment_time, services(name), masters(specialty)')
        .eq('status', 'completed')
        .order('appointment_time', ascending: false);
    final appointments = List<Map<String, dynamic>>.from(completedAppointments);

    if (!mounted) {
      textCtrl.dispose();
      return;
    }

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final cs = Theme.of(sheetContext).colorScheme;
        return StatefulBuilder(
          builder: (context, setModalState) => Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              top: AppSpacing.lg,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + AppSpacing.lg,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Новый отзыв',
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (appointments.isEmpty)
                    Text(
                      'Нет завершённых заказов для создания отзыва.',
                      style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    )
                  else
                    DropdownButtonFormField<int>(
                      initialValue: selectedAppointmentId,
                      decoration: const InputDecoration(
                        labelText: 'Заказ *',
                        border: OutlineInputBorder(),
                      ),
                      items: appointments.map((row) {
                        final id = row['id'] as int?;
                        final masters = row['masters'] as Map<String, dynamic>?;
                        final services = row['services'] as Map<String, dynamic>?;
                        final dt = DateTime.tryParse(
                          (row['appointment_time'] ?? '').toString(),
                        );
                        final label =
                            '#${id ?? '-'} • ${(services?['name'] ?? 'Услуга').toString()} • ${(masters?['specialty'] ?? 'Мастер').toString()} • ${_dateTimeLabel(dt)}';
                        return DropdownMenuItem<int>(
                          value: id,
                          child: Text(
                            label,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setModalState(() {
                          selectedAppointmentId = value;
                        });
                      },
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<int>(
                    initialValue: rating,
                    decoration: const InputDecoration(
                      labelText: 'Оценка *',
                      border: OutlineInputBorder(),
                    ),
                    items: const [1, 2, 3, 4, 5]
                        .map(
                          (value) => DropdownMenuItem<int>(
                            value: value,
                            child: Text('$value'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setModalState(() {
                        rating = value;
                      });
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: textCtrl,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Текст отзыва',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton.icon(
                    onPressed: () {
                      if (selectedAppointmentId == null) {
                        AppSnackbar.showError(sheetContext, 'Выберите заказ');
                        return;
                      }
                      Navigator.of(sheetContext).pop(true);
                    },
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Создать'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (result != true) {
      textCtrl.dispose();
      return;
    }

    final chosen = appointments.where((row) => row['id'] == selectedAppointmentId).toList();
    if (chosen.isEmpty) {
      textCtrl.dispose();
      return;
    }
    final appointment = chosen.first;
    final clientId = appointment['client_id'];
    final masterId = appointment['master_id'];
    final trimmedText = textCtrl.text.trim();
    textCtrl.dispose();

    await _runGuarded(() async {
      await SupabaseService.insert('reviews', {
        'appointment_id': selectedAppointmentId,
        'client_id': clientId,
        'master_id': masterId,
        'rating': rating,
        'text': trimmedText.isEmpty ? null : trimmedText,
      });
      if (!mounted) return;
      AppSnackbar.showSuccess(context, 'Отзыв добавлен');
    });
  }

  Future<Set<int>> _loadServiceIdsForMaster(int masterId) async {
    final rows = await SupabaseService.select(
      'master_services',
      select: 'service_id',
      filters: {'master_id': masterId},
    );
    return rows
        .map((row) => row['service_id'])
        .whereType<int>()
        .toSet();
  }

  Future<Set<int>> _loadMasterIdsForService(int serviceId) async {
    final rows = await SupabaseService.select(
      'master_services',
      select: 'master_id',
      filters: {'service_id': serviceId},
    );
    return rows
        .map((row) => row['master_id'])
        .whereType<int>()
        .toSet();
  }

  Future<void> _syncMasterServiceLinksForMaster({
    required int masterId,
    required Set<int> selectedServiceIds,
    required Map<int, Map<String, dynamic>> servicesById,
  }) async {
    final existing = await SupabaseService.select(
      'master_services',
      select: 'id, service_id',
      filters: {'master_id': masterId},
    );

    final existingByServiceId = <int, int>{};
    for (final row in existing) {
      final serviceId = row['service_id'];
      final linkId = row['id'];
      if (serviceId is int && linkId is int) {
        existingByServiceId[serviceId] = linkId;
      }
    }

    for (final entry in existingByServiceId.entries) {
      if (!selectedServiceIds.contains(entry.key)) {
        await SupabaseService.delete('master_services', filters: {'id': entry.value});
      }
    }

    for (final serviceId in selectedServiceIds) {
      if (existingByServiceId.containsKey(serviceId)) continue;
      final service = servicesById[serviceId];
      await SupabaseService.insert('master_services', {
        'master_id': masterId,
        'service_id': serviceId,
        'price': service?['price'],
        'duration': service?['duration'],
      });
    }
  }

  Future<void> _syncMasterServiceLinksForService({
    required int serviceId,
    required Set<int> selectedMasterIds,
    required num? price,
    required int? duration,
  }) async {
    final existing = await SupabaseService.select(
      'master_services',
      select: 'id, master_id',
      filters: {'service_id': serviceId},
    );

    final existingByMasterId = <int, int>{};
    for (final row in existing) {
      final masterId = row['master_id'];
      final linkId = row['id'];
      if (masterId is int && linkId is int) {
        existingByMasterId[masterId] = linkId;
      }
    }

    for (final entry in existingByMasterId.entries) {
      if (!selectedMasterIds.contains(entry.key)) {
        await SupabaseService.delete('master_services', filters: {'id': entry.value});
      }
    }

    for (final masterId in selectedMasterIds) {
      if (existingByMasterId.containsKey(masterId)) continue;
      await SupabaseService.insert('master_services', {
        'master_id': masterId,
        'service_id': serviceId,
        'price': price,
        'duration': duration,
      });
    }
  }

  Future<void> _runGuarded(Future<void> Function() action) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      await action();
      if (!mounted) return;
      _reloadAllTabs();
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.showError(context, 'Ошибка: $e');
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  void _reloadAllTabs() {
    _mastersFuture = _loadMasters();
    _servicesFuture = _loadServices();
    _appointmentsFuture = _loadAppointments();
    _reviewsFuture = _loadReviews();
  }

  Future<void> _updateAppointmentStatus({
    required int appointmentId,
    required String newStatus,
  }) async {
    await _runGuarded(() async {
      await SupabaseService.update(
        'appointments',
        {'status': newStatus},
        filters: {'id': appointmentId},
      );
      if (!mounted) return;
      AppSnackbar.showSuccess(context, 'Статус заказа обновлён');
    });
  }

  Future<void> _deleteMaster(int id) async {
    final shouldDelete = await _confirmDelete(
      title: 'Удалить мастера?',
      message:
          'Мастер будет удалён из базы. Если есть связанные записи, база может отклонить удаление.',
    );
    if (!shouldDelete) return;
    await _runGuarded(() async {
      await SupabaseService.delete('masters', filters: {'id': id});
      if (!mounted) return;
      AppSnackbar.showSuccess(context, 'Мастер удалён');
    });
  }

  Future<void> _deleteService(int id) async {
    final shouldDelete = await _confirmDelete(
      title: 'Удалить услугу?',
      message:
          'Услуга будет удалена. Если есть связанные записи, база может отклонить удаление.',
    );
    if (!shouldDelete) return;
    await _runGuarded(() async {
      await SupabaseService.delete('services', filters: {'id': id});
      if (!mounted) return;
      AppSnackbar.showSuccess(context, 'Услуга удалена');
    });
  }

  Future<bool> _confirmDelete({
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _openMasterForm({Map<String, dynamic>? initial}) async {
    final specialtyCtrl = TextEditingController(
      text: (initial?['specialty'] ?? '').toString(),
    );
    final levelCtrl = TextEditingController(
      text: (initial?['level'] ?? '').toString(),
    );
    final bioCtrl = TextEditingController(
      text: (initial?['bio'] ?? '').toString(),
    );
    final avatarCtrl = TextEditingController(
      text: (initial?['avatar_url'] ?? '').toString(),
    );
    final initialUserId = initial?['user_id'];
    String? selectedUserId = initialUserId is String && initialUserId.trim().isNotEmpty
        ? initialUserId.trim()
        : null;

    final availableServices = await _loadServices();
    final availableUsers = await _loadMasterUsers(includeUserId: selectedUserId);
    final servicesById = <int, Map<String, dynamic>>{
      for (final item in availableServices)
        if (item['id'] is int) item['id'] as int: item,
    };
    final initialSelectedServiceIds = initial == null
        ? <int>{}
        : await _loadServiceIdsForMaster(initial['id'] as int);
    if (!mounted) {
      specialtyCtrl.dispose();
      levelCtrl.dispose();
      bioCtrl.dispose();
      avatarCtrl.dispose();
      return;
    }

    final result = await showModalBottomSheet<_MasterFormResult>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final cs = Theme.of(sheetContext).colorScheme;
        final selectedServiceIds = {...initialSelectedServiceIds};
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.lg,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + AppSpacing.lg,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  initial == null ? 'Новый мастер' : 'Редактирование мастера',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: specialtyCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Имя мастера *',
                    hintText: 'Например: Мария',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                StatefulBuilder(
                  builder: (context, setModalState) => DropdownButtonFormField<String>(
                    initialValue: selectedUserId,
                    decoration: const InputDecoration(
                      labelText: 'Аккаунт пользователя',
                      border: OutlineInputBorder(),
                    ),
                    items: availableUsers.map((user) {
                      final id = user['id'];
                      if (id is! String) return null;
                      final displayName = (user['display_name'] ?? '').toString().trim();
                      final firstName = (user['first_name'] ?? '').toString().trim();
                      final lastName = (user['last_name'] ?? '').toString().trim();
                      final email = (user['email'] ?? '').toString().trim();
                      final fullName = '$firstName $lastName'.trim();
                      final label = displayName.isNotEmpty
                          ? displayName
                          : (fullName.isNotEmpty ? fullName : (email.isNotEmpty ? email : id));
                      return DropdownMenuItem<String>(
                        value: id,
                        child: Text(
                          label,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).whereType<DropdownMenuItem<String>>().toList(),
                    onChanged: (value) {
                      setModalState(() {
                        selectedUserId = value;
                      });
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: levelCtrl,
                  decoration: const InputDecoration(labelText: 'Уровень'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: bioCtrl,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Описание'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: avatarCtrl,
                  decoration: const InputDecoration(labelText: 'URL аватара'),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Услуги мастера',
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                if (availableServices.isEmpty)
                  Text(
                    'Сначала добавьте услуги, чтобы назначить их мастеру.',
                    style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  )
                else
                  StatefulBuilder(
                    builder: (context, setModalState) => Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: availableServices.map((service) {
                        final serviceId = service['id'];
                        if (serviceId is! int) return const SizedBox.shrink();
                        final label = (service['name'] ?? 'Услуга #$serviceId').toString();
                        return FilterChip(
                          label: Text(label),
                          selected: selectedServiceIds.contains(serviceId),
                          onSelected: (isSelected) {
                            setModalState(() {
                              if (isSelected) {
                                selectedServiceIds.add(serviceId);
                              } else {
                                selectedServiceIds.remove(serviceId);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: () {
                    if (specialtyCtrl.text.trim().isEmpty) {
                      AppSnackbar.showError(
                        sheetContext,
                        'Поле "Имя мастера" обязательно',
                      );
                      return;
                    }
                    Navigator.of(sheetContext).pop(
                      _MasterFormResult(
                        selectedServiceIds: selectedServiceIds,
                        selectedUserId: selectedUserId,
                      ),
                    );
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: Text(initial == null ? 'Создать' : 'Сохранить'),
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.primaryContainer,
                    foregroundColor: cs.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result == null) {
      specialtyCtrl.dispose();
      levelCtrl.dispose();
      bioCtrl.dispose();
      avatarCtrl.dispose();
      return;
    }

    final payload = <String, dynamic>{
      'user_id': result.selectedUserId,
      'specialty': specialtyCtrl.text.trim(),
      'level': levelCtrl.text.trim().isEmpty ? null : levelCtrl.text.trim(),
      'bio': bioCtrl.text.trim().isEmpty ? null : bioCtrl.text.trim(),
      'avatar_url': avatarCtrl.text.trim().isEmpty ? null : avatarCtrl.text.trim(),
    };

    specialtyCtrl.dispose();
    levelCtrl.dispose();
    bioCtrl.dispose();
    avatarCtrl.dispose();

    await _runGuarded(() async {
      if (initial == null) {
        final inserted = await SupabaseService.insert('masters', payload);
        final insertedMasterId = inserted.isNotEmpty ? inserted.first['id'] : null;
        if (insertedMasterId is int) {
          await _syncMasterServiceLinksForMaster(
            masterId: insertedMasterId,
            selectedServiceIds: result.selectedServiceIds,
            servicesById: servicesById,
          );
        }
        if (!mounted) return;
        AppSnackbar.showSuccess(context, 'Мастер добавлен');
      } else {
        await SupabaseService.update(
          'masters',
          payload,
          filters: {'id': initial['id']},
        );
        await _syncMasterServiceLinksForMaster(
          masterId: initial['id'] as int,
          selectedServiceIds: result.selectedServiceIds,
          servicesById: servicesById,
        );
        if (!mounted) return;
        AppSnackbar.showSuccess(context, 'Мастер обновлён');
      }
    });
  }

  Future<void> _openServiceForm({Map<String, dynamic>? initial}) async {
    final nameCtrl = TextEditingController(
      text: (initial?['name'] ?? '').toString(),
    );
    final categoryCtrl = TextEditingController(
      text: (initial?['category'] ?? '').toString(),
    );
    final descriptionCtrl = TextEditingController(
      text: (initial?['description'] ?? '').toString(),
    );
    final durationCtrl = TextEditingController(
      text: (initial?['duration'] ?? '').toString(),
    );
    final priceCtrl = TextEditingController(
      text: (initial?['price'] ?? '').toString(),
    );
    final imageCtrl = TextEditingController(
      text: (initial?['image_url'] ?? '').toString(),
    );

    final availableMasters = await _loadMasters();
    final initialSelectedMasterIds = initial == null
        ? <int>{}
        : await _loadMasterIdsForService(initial['id'] as int);
    if (!mounted) {
      nameCtrl.dispose();
      categoryCtrl.dispose();
      descriptionCtrl.dispose();
      durationCtrl.dispose();
      priceCtrl.dispose();
      imageCtrl.dispose();
      return;
    }

    final result = await showModalBottomSheet<_ServiceFormResult>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final cs = Theme.of(sheetContext).colorScheme;
        final selectedMasterIds = {...initialSelectedMasterIds};
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.lg,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + AppSpacing.lg,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  initial == null ? 'Новая услуга' : 'Редактирование услуги',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Название *'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: categoryCtrl,
                  decoration: const InputDecoration(labelText: 'Категория'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: descriptionCtrl,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Описание'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: durationCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Длительность (мин)'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Цена'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: imageCtrl,
                  decoration: const InputDecoration(labelText: 'URL изображения'),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Мастера для услуги',
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                if (availableMasters.isEmpty)
                  Text(
                    'Сначала добавьте мастеров, чтобы назначить им услугу.',
                    style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  )
                else
                  StatefulBuilder(
                    builder: (context, setModalState) => Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: availableMasters.map((master) {
                        final masterId = master['id'];
                        if (masterId is! int) return const SizedBox.shrink();
                        final label = (master['specialty'] ?? 'Мастер #$masterId').toString();
                        return FilterChip(
                          label: Text(label),
                          selected: selectedMasterIds.contains(masterId),
                          onSelected: (isSelected) {
                            setModalState(() {
                              if (isSelected) {
                                selectedMasterIds.add(masterId);
                              } else {
                                selectedMasterIds.remove(masterId);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: () {
                    if (nameCtrl.text.trim().isEmpty) {
                      AppSnackbar.showError(sheetContext, 'Поле "Название" обязательно');
                      return;
                    }
                    Navigator.of(sheetContext).pop(
                      _ServiceFormResult(selectedMasterIds: selectedMasterIds),
                    );
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: Text(initial == null ? 'Создать' : 'Сохранить'),
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.primaryContainer,
                    foregroundColor: cs.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result == null) {
      nameCtrl.dispose();
      categoryCtrl.dispose();
      descriptionCtrl.dispose();
      durationCtrl.dispose();
      priceCtrl.dispose();
      imageCtrl.dispose();
      return;
    }

    final parsedDuration = int.tryParse(durationCtrl.text.trim());
    final parsedPrice = num.tryParse(priceCtrl.text.trim());
    final payload = <String, dynamic>{
      'name': nameCtrl.text.trim(),
      'category': categoryCtrl.text.trim().isEmpty ? null : categoryCtrl.text.trim(),
      'description':
          descriptionCtrl.text.trim().isEmpty ? null : descriptionCtrl.text.trim(),
      'duration': parsedDuration,
      'price': parsedPrice,
      'image_url': imageCtrl.text.trim().isEmpty ? null : imageCtrl.text.trim(),
    };

    nameCtrl.dispose();
    categoryCtrl.dispose();
    descriptionCtrl.dispose();
    durationCtrl.dispose();
    priceCtrl.dispose();
    imageCtrl.dispose();

    await _runGuarded(() async {
      if (initial == null) {
        final inserted = await SupabaseService.insert('services', payload);
        final insertedServiceId = inserted.isNotEmpty ? inserted.first['id'] : null;
        if (insertedServiceId is int) {
          await _syncMasterServiceLinksForService(
            serviceId: insertedServiceId,
            selectedMasterIds: result.selectedMasterIds,
            price: parsedPrice,
            duration: parsedDuration,
          );
        }
        if (!mounted) return;
        AppSnackbar.showSuccess(context, 'Услуга добавлена');
      } else {
        await SupabaseService.update(
          'services',
          payload,
          filters: {'id': initial['id']},
        );
        await _syncMasterServiceLinksForService(
          serviceId: initial['id'] as int,
          selectedMasterIds: result.selectedMasterIds,
          price: parsedPrice,
          duration: parsedDuration,
        );
        if (!mounted) return;
        AppSnackbar.showSuccess(context, 'Услуга обновлена');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Админ-панель')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline_rounded, size: 48, color: cs.onSurfaceVariant),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Доступ запрещён. Раздел доступен только администраторам.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Админ-панель'),
        leading: const AdminAccessIcon(keepPlaceholderWhenHidden: false),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Мастера'),
            Tab(text: 'Услуги'),
            Tab(text: 'Заказы'),
            Tab(text: 'Отзывы'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _mastersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text('Не удалось загрузить мастеров: ${snapshot.error}'),
                  ),
                );
              }
              final masters = snapshot.data ?? const [];
              if (masters.isEmpty) {
                return const Center(child: Text('Мастера пока не добавлены.'));
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  110,
                ),
                itemCount: masters.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final item = masters[index];
                  return Container(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: ListTile(
                      leading: SafeNetworkAvatar(
                        url: (item['avatar_url'] ?? '').toString(),
                        radius: 20,
                        backgroundColor: cs.surface,
                        icon: Icons.person_outline,
                        iconSize: 20,
                      ),
                      title: Text((item['specialty'] ?? 'Мастер').toString()),
                      subtitle: Text((item['level'] ?? 'Уровень не указан').toString()),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Редактировать',
                            onPressed: _isBusy ? null : () => _openMasterForm(initial: item),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: 'Удалить',
                            onPressed: _isBusy
                                ? null
                                : () {
                                    final id = item['id'];
                                    if (id is int) {
                                      _deleteMaster(id);
                                    }
                                  },
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
          FutureBuilder<List<Map<String, dynamic>>>(
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
              final services = snapshot.data ?? const [];
              if (services.isEmpty) {
                return const Center(child: Text('Услуги пока не добавлены.'));
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  110,
                ),
                itemCount: services.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final item = services[index];
                  final rawPrice = item['price'];
                  final price = rawPrice is num
                      ? rawPrice.toStringAsFixed(0)
                      : rawPrice.toString();
                  return Container(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: ListTile(
                      title: Text((item['name'] ?? 'Услуга').toString()),
                      subtitle: Text(
                        '${item['category'] ?? 'Без категории'} • ${item['duration'] ?? '-'} мин • $price ₽',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Редактировать',
                            onPressed: _isBusy ? null : () => _openServiceForm(initial: item),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: 'Удалить',
                            onPressed: _isBusy
                                ? null
                                : () {
                                    final id = item['id'];
                                    if (id is int) {
                                      _deleteService(id);
                                    }
                                  },
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _appointmentsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text('Не удалось загрузить заказы: ${snapshot.error}'),
                  ),
                );
              }
              final appointments = snapshot.data ?? const [];
              if (appointments.isEmpty) {
                return const Center(child: Text('Заказы пока не созданы.'));
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.xl,
                ),
                itemCount: appointments.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final item = appointments[index];
                  final appointmentId = item['id'];
                  final rawStatus = (item['status'] ?? 'pending').toString();
                  final status = _appointmentStatuses.contains(rawStatus)
                      ? rawStatus
                      : 'pending';
                  final appointmentTime = DateTime.tryParse(
                    (item['appointment_time'] ?? '').toString(),
                  );
                  final masters = item['masters'] as Map<String, dynamic>?;
                  final services = item['services'] as Map<String, dynamic>?;
                  return Container(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Заказ #${item['id']}',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                              _StatusBadge(status: status),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Услуга: ${(services?['name'] ?? '—').toString()}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Мастер: ${(masters?['specialty'] ?? '—').toString()}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Клиент: ${(item['client_id'] ?? '—').toString()}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Время: ${_dateTimeLabel(appointmentTime)}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              Text(
                                'Статус:',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: status,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  items: _appointmentStatuses
                                      .map(
                                        (value) => DropdownMenuItem<String>(
                                          value: value,
                                          child: Text(_statusLabel(value)),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: _isBusy || appointmentId is! int
                                      ? null
                                      : (value) {
                                          if (value == null || value == status) return;
                                          _updateAppointmentStatus(
                                            appointmentId: appointmentId,
                                            newStatus: value,
                                          );
                                        },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _reviewsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text('Не удалось загрузить отзывы: ${snapshot.error}'),
                  ),
                );
              }
              final reviews = snapshot.data ?? const [];
              if (reviews.isEmpty) {
                return const Center(child: Text('Отзывов пока нет.'));
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.xl,
                ),
                itemCount: reviews.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final item = reviews[index];
                  final masters = item['masters'] as Map<String, dynamic>?;
                  final appointment = item['appointments'] as Map<String, dynamic>?;
                  final services = appointment?['services'] as Map<String, dynamic>?;
                  final createdAt = DateTime.tryParse((item['created_at'] ?? '').toString());
                  final rating = item['rating'];
                  final text = (item['text'] ?? '').toString();
                  return Container(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Отзыв #${item['id']}',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                              if (rating is num)
                                Text(
                                  '⭐ ${rating.toString()}',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text('Мастер: ${(masters?['specialty'] ?? '—').toString()}'),
                          const SizedBox(height: 4),
                          Text('Услуга: ${(services?['name'] ?? '—').toString()}'),
                          const SizedBox(height: 4),
                          Text('Заказ: #${item['appointment_id'] ?? '—'}'),
                          const SizedBox(height: 4),
                          Text(
                            'Дата: ${_dateTimeLabel(createdAt)}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          if (text.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              text,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                          const SizedBox(height: AppSpacing.sm),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: _isBusy
                                  ? null
                                  : () {
                                      final id = item['id'];
                                      if (id is int) {
                                        _deleteReview(id);
                                      }
                                    },
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Удалить'),
                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 2
          ? null
          : _tabController.index == 3
          ? FloatingActionButton.extended(
              onPressed: _isBusy ? null : _openReviewForm,
              icon: const Icon(Icons.rate_review_outlined),
              label: const Text('Добавить отзыв'),
            )
          : FloatingActionButton.extended(
              onPressed: _isBusy
                  ? null
                  : () {
                      if (_tabController.index == 0) {
                        _openMasterForm();
                      } else {
                        _openServiceForm();
                      }
                    },
              icon: Icon(
                _tabController.index == 0 ? Icons.person_add_alt : Icons.add_box_outlined,
              ),
              label: Text(
                _tabController.index == 0 ? 'Добавить мастера' : 'Добавить услугу',
              ),
            ),
    );
  }
}

class _MasterFormResult {
  const _MasterFormResult({
    required this.selectedServiceIds,
    required this.selectedUserId,
  });

  final Set<int> selectedServiceIds;
  final String? selectedUserId;
}

class _ServiceFormResult {
  const _ServiceFormResult({required this.selectedMasterIds});

  final Set<int> selectedMasterIds;
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = switch (status) {
      'confirmed' => const Color(0xFF6D4EA2),
      'pending' => const Color(0xFF8A8441),
      'completed' => const Color(0xFF1F8A5A),
      'cancelled' => const Color(0xFFC3423F),
      _ => cs.primary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

String _statusLabel(String status) => switch (status) {
  'confirmed' => 'Подтверждено',
  'pending' => 'Ожидает',
  'completed' => 'Завершено',
  'cancelled' => 'Отменено',
  _ => status,
};

String _dateTimeLabel(DateTime? dt) {
  if (dt == null) return 'Без даты';
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  final dd = dt.day.toString().padLeft(2, '0');
  final mon = dt.month.toString().padLeft(2, '0');
  return '$dd.$mon.${dt.year} $hh:$mm';
}
