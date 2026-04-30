import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app_template/core/ui/app_snackbar.dart';
import 'package:app_template/features/auth/presentation/controllers/auth_controller.dart';
import 'package:app_template/features/auth/presentation/models/auth_state.dart';
import 'package:app_template/nav.dart';
import 'package:app_template/supabase/supabase_config.dart';

class BookingPage extends ConsumerStatefulWidget {
  final int? masterId;
  final int? serviceId;

  const BookingPage({super.key, this.masterId, this.serviceId});

  @override
  ConsumerState<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends ConsumerState<BookingPage> {
  static const _bgColor = Color(0xFFFEF7FF);
  static const _textPrimary = Color(0xFF1D1A20);
  static const _textSecondary = Color(0xFF4A4550);
  static const _surfaceSoft = Color(0xFFE7E0E8);
  static const _surfaceCard = Color(0xFFF8F1FA);
  static const _accent = Color(0xFF6D4EA2);
  static const _accentSoft = Color(0xFFC5A3FF);
  static const _accentText = Color(0xFF533487);

  int? _selectedMasterId;
  int? _selectedServiceId;
  int? _selectedSlotId;
  String? _selectedDateKey;
  bool _submitting = false;

  late Future<List<Map<String, dynamic>>> _masterServicesFuture;
  late Future<List<Map<String, dynamic>>> _slotsFuture;

  @override
  void initState() {
    super.initState();
    _selectedMasterId = widget.masterId;
    _selectedServiceId = widget.serviceId;
    _masterServicesFuture = _loadMasterServices();
    _slotsFuture = _loadSlots(masterId: _selectedMasterId);
  }

  Future<List<Map<String, dynamic>>> _loadMasterServices() async {
    final rows = await SupabaseConfig.client
        .from('master_services')
        .select(
          'master_id, service_id, price, duration, '
          'masters(id, specialty, level), '
          'services(id, name, description, price, duration)',
        )
        .order('master_id', ascending: true);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> _loadSlots({int? masterId}) async {
    dynamic query = SupabaseConfig.client
        .from('time_slots')
        .select()
        .eq('is_booked', false)
        .gte('start_time', DateTime.now().toIso8601String());
    if (masterId != null) {
      query = query.eq('master_id', masterId);
    }
    query = query.order('start_time', ascending: true).limit(200);
    final result = await query;
    return List<Map<String, dynamic>>.from(result);
  }

  Future<void> _submitBooking() async {
    final authValue = ref.read(authControllerProvider).asData?.value;
    if (authValue is! Authenticated) {
      context.go(AppRoutes.login);
      return;
    }
    if (_selectedMasterId == null ||
        _selectedServiceId == null ||
        _selectedSlotId == null) {
      AppSnackbar.showError(
        context,
        'Пожалуйста, выберите мастера, услугу и время.',
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final slot = await SupabaseService.selectSingle(
        'time_slots',
        filters: {'id': _selectedSlotId},
      );
      if (slot == null) {
        throw Exception('Выбранный слот не найден.');
      }
      final inserted = await SupabaseService.insert('appointments', {
        'client_id': authValue.user.id,
        'master_id': _selectedMasterId,
        'service_id': _selectedServiceId,
        'appointment_time': slot['start_time'],
        'status': 'pending',
      });
      final appointmentId = inserted.first['id'];
      await SupabaseService.update(
        'time_slots',
        {
          'is_booked': true,
          'appointment_id': appointmentId,
        },
        filters: {'id': _selectedSlotId},
      );
      if (!mounted) return;
      AppSnackbar.showInfo(context, 'Запись успешно создана.');
      context.go(AppRoutes.myAppointments);
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.showError(context, 'Не удалось создать запись: $e');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authValue = ref.watch(authControllerProvider).asData?.value;
    final isAuthed = authValue is Authenticated;
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _masterServicesFuture,
      builder: (context, msSnapshot) {
        if (msSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (msSnapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Запись')),
            body: Center(child: Text('Ошибка загрузки: ${msSnapshot.error}')),
          );
        }

        final relations = msSnapshot.data ?? const <Map<String, dynamic>>[];
        final masterOptions = _extractMasters(relations);
        final serviceOptions = _extractServices(relations);
        _syncSelections(masterOptions, serviceOptions, relations);

        final selectedMaster = masterOptions.firstWhere(
          (m) => m['id'] == _selectedMasterId,
          orElse: () => const {'id': null, 'name': 'Мастер'},
        );
        final selectedService = serviceOptions.firstWhere(
          (s) => s['id'] == _selectedServiceId,
          orElse: () => const {'id': null, 'name': 'Услуга'},
        );
        final link = _findRelation(
          relations,
          masterId: _selectedMasterId,
          serviceId: _selectedServiceId,
        );

        final serviceName = (selectedService['name'] ?? 'Услуга').toString();
        final serviceDescription = (selectedService['description'] ?? '—').toString();
        final servicePrice = _formatPriceFromAny(link?['price'] ?? selectedService['price']);

        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _slotsFuture,
          builder: (context, slotSnapshot) {
            if (slotSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (slotSnapshot.hasError) {
              return Scaffold(
                appBar: AppBar(title: const Text('Запись')),
                body: Center(child: Text('Ошибка слотов: ${slotSnapshot.error}')),
              );
            }

            final allSlots = slotSnapshot.data ?? const <Map<String, dynamic>>[];
            final dateKeys = _availableDateKeys(allSlots);
            _syncSelectedDateAndSlot(dateKeys, allSlots);
            final slotsForDay = allSlots.where((s) => _dateKey(s) == _selectedDateKey).toList();
            final morning = slotsForDay.where((s) => _slotHour(s) < 12).toList();
            final day = slotsForDay.where((s) => _slotHour(s) >= 12 && _slotHour(s) < 18).toList();
            final evening = slotsForDay.where((s) => _slotHour(s) >= 18).toList();

            final selectedSlot = allSlots.cast<Map<String, dynamic>?>().firstWhere(
              (s) => s?['id'] == _selectedSlotId,
              orElse: () => null,
            );
            final selectedTime = _slotLongLabel(selectedSlot);
            final barTime = _slotShortLabel(selectedSlot);

            return Scaffold(
              backgroundColor: _bgColor,
              appBar: AppBar(
                title: const Text('Запись'),
                centerTitle: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                  onPressed: () => context.pop(),
                ),
              ),
              body: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 170),
                children: [
                  if (!isAuthed)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: const Color(0xFFFFE9E9),
                      ),
                      child: const Text(
                        'Войдите в аккаунт, чтобы завершить запись.',
                        style: TextStyle(color: Color(0xFF7D1F1F)),
                      ),
                    ),
                  const Text(
                    'Выберите дату и время',
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SelectBlock(
                    label: 'Мастер',
                    value: (selectedMaster['name'] ?? '—').toString(),
                    onTap: () => _pickMaster(context, relations, masterOptions),
                  ),
                  const SizedBox(height: 10),
                  _SelectBlock(
                    label: 'Услуга',
                    value: serviceName,
                    onTap: () => _pickService(context, relations, serviceOptions),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    serviceDescription,
                    style: const TextStyle(color: _textSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  if (dateKeys.isEmpty)
                    const Text(
                      'Нет доступных дат для выбранного мастера.',
                      style: TextStyle(color: _textSecondary),
                    )
                  else
                    _DateStrip(
                      dateKeys: dateKeys,
                      selectedDateKey: _selectedDateKey,
                      onTap: (key) => setState(() {
                        _selectedDateKey = key;
                        _selectedSlotId = null;
                      }),
                    ),
                  const SizedBox(height: 16),
                  const Divider(color: _surfaceSoft),
                  const SizedBox(height: 12),
                  _TimeSection(
                    title: 'Утро',
                    slots: morning,
                    selectedSlotId: _selectedSlotId,
                    onTap: (id) => setState(() => _selectedSlotId = id),
                  ),
                  _TimeSection(
                    title: 'День',
                    slots: day,
                    selectedSlotId: _selectedSlotId,
                    onTap: (id) => setState(() => _selectedSlotId = id),
                  ),
                  _TimeSection(
                    title: 'Вечер',
                    slots: evening,
                    selectedSlotId: _selectedSlotId,
                    onTap: (id) => setState(() => _selectedSlotId = id),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _surfaceCard,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Подтверждение',
                          style: TextStyle(
                            color: _textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _summaryRow(serviceName, servicePrice),
                        const SizedBox(height: 4),
                        Text(
                          'Мастер: ${(selectedMaster['name'] ?? '—')}',
                          style: const TextStyle(color: _textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Дата и время: $selectedTime',
                          style: const TextStyle(color: _textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              bottomSheet: Container(
                decoration: const BoxDecoration(
                  color: Color(0xE6FFFFFF),
                  border: Border(top: BorderSide(color: Color(0xFFE7E0E8))),
                ),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              barTime,
                              style: const TextStyle(
                                color: _textSecondary,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              servicePrice,
                              style: const TextStyle(
                                color: _textPrimary,
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: _accent,
                          minimumSize: const Size(150, 56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _submitting ? null : _submitBooking,
                        child: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Подтвердить'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _summaryRow(String serviceName, String price) {
    return Row(
      children: [
        Expanded(
          child: Text(
            serviceName,
            style: const TextStyle(color: _textPrimary, fontSize: 16),
          ),
        ),
        Text(
          price,
          style: const TextStyle(
            color: _accent,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  void _syncSelections(
    List<Map<String, dynamic>> masterOptions,
    List<Map<String, dynamic>> serviceOptions,
    List<Map<String, dynamic>> relations,
  ) {
    if (_selectedMasterId == null && masterOptions.isNotEmpty) {
      _selectedMasterId = masterOptions.first['id'] as int?;
      _slotsFuture = _loadSlots(masterId: _selectedMasterId);
    }
    if (_selectedServiceId == null && serviceOptions.isNotEmpty) {
      _selectedServiceId = serviceOptions.first['id'] as int?;
    }
    if (_selectedMasterId != null && _selectedServiceId != null) {
      final exists = _findRelation(
            relations,
            masterId: _selectedMasterId,
            serviceId: _selectedServiceId,
          ) !=
          null;
      if (!exists) {
        final fallback = relations.firstWhere(
          (r) => r['master_id'] == _selectedMasterId,
          orElse: () => const {},
        );
        if (fallback.isNotEmpty) {
          _selectedServiceId = fallback['service_id'] as int?;
        }
      }
    }
  }

  void _syncSelectedDateAndSlot(
    List<String> dateKeys,
    List<Map<String, dynamic>> allSlots,
  ) {
    if (_selectedDateKey == null || !dateKeys.contains(_selectedDateKey)) {
      _selectedDateKey = dateKeys.isEmpty ? null : dateKeys.first;
      _selectedSlotId = null;
    }
    if (_selectedSlotId != null) {
      final hasSlot = allSlots.any((slot) => slot['id'] == _selectedSlotId);
      if (!hasSlot) _selectedSlotId = null;
    }
  }

  Future<void> _pickMaster(
    BuildContext context,
    List<Map<String, dynamic>> relations,
    List<Map<String, dynamic>> masters,
  ) async {
    if (masters.isEmpty) return;
    final chosen = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => _PickerSheet(
        title: 'Выберите мастера',
        options: masters
            .map(
              (m) => _PickerOption(
                id: m['id'] as int,
                title: (m['name'] ?? 'Мастер').toString(),
                subtitle: (m['level'] ?? '').toString(),
              ),
            )
            .toList(),
      ),
    );
    if (chosen == null || !mounted) return;
    setState(() {
      _selectedMasterId = chosen;
      _selectedSlotId = null;
      _selectedDateKey = null;
      _slotsFuture = _loadSlots(masterId: _selectedMasterId);
      if (_selectedServiceId != null &&
          _findRelation(relations, masterId: chosen, serviceId: _selectedServiceId) ==
              null) {
        final candidate = relations.firstWhere(
          (r) => r['master_id'] == chosen,
          orElse: () => const {},
        );
        _selectedServiceId = candidate.isEmpty ? null : candidate['service_id'] as int?;
      }
    });
  }

  Future<void> _pickService(
    BuildContext context,
    List<Map<String, dynamic>> relations,
    List<Map<String, dynamic>> services,
  ) async {
    final available = _selectedMasterId == null
        ? services
        : services
            .where(
              (s) => _findRelation(
                    relations,
                    masterId: _selectedMasterId,
                    serviceId: s['id'] as int?,
                  ) !=
                  null,
            )
            .toList();
    if (available.isEmpty) return;
    final chosen = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => _PickerSheet(
        title: 'Выберите услугу',
        options: available
            .map(
              (s) => _PickerOption(
                id: s['id'] as int,
                title: (s['name'] ?? 'Услуга').toString(),
                subtitle: _formatPriceFromAny(s['price']),
              ),
            )
            .toList(),
      ),
    );
    if (chosen == null || !mounted) return;
    setState(() => _selectedServiceId = chosen);
  }

  static Map<String, dynamic>? _findRelation(
    List<Map<String, dynamic>> relations, {
    int? masterId,
    int? serviceId,
  }) {
    for (final row in relations) {
      if (row['master_id'] == masterId && row['service_id'] == serviceId) {
        return row;
      }
    }
    return null;
  }

  static List<Map<String, dynamic>> _extractMasters(List<Map<String, dynamic>> relations) {
    final byId = <int, Map<String, dynamic>>{};
    for (final row in relations) {
      final id = row['master_id'] as int?;
      final master = row['masters'] as Map<String, dynamic>?;
      if (id == null || master == null) continue;
      byId[id] = {
        'id': id,
        'name': (master['specialty'] ?? 'Мастер').toString(),
        'level': (master['level'] ?? '').toString(),
      };
    }
    return byId.values.toList();
  }

  static List<Map<String, dynamic>> _extractServices(List<Map<String, dynamic>> relations) {
    final byId = <int, Map<String, dynamic>>{};
    for (final row in relations) {
      final id = row['service_id'] as int?;
      final service = row['services'] as Map<String, dynamic>?;
      if (id == null || service == null) continue;
      byId[id] = {
        'id': id,
        'name': (service['name'] ?? 'Услуга').toString(),
        'description': (service['description'] ?? '').toString(),
        'price': service['price'],
      };
    }
    return byId.values.toList();
  }

  static List<String> _availableDateKeys(List<Map<String, dynamic>> slots) {
    final keys = <String>{};
    for (final slot in slots) {
      final dt = _slotDateTime(slot);
      if (dt == null) continue;
      keys.add(_dateKey(slot)!);
    }
    final sorted = keys.toList()..sort();
    return sorted;
  }

  static int _slotHour(Map<String, dynamic> slot) {
    final dt = _slotDateTime(slot);
    return dt?.hour ?? 0;
  }

  static DateTime? _slotDateTime(Map<String, dynamic>? slot) {
    if (slot == null) return null;
    final raw = (slot['start_time'] ?? '').toString().trim();
    if (raw.isEmpty) return null;
    final direct = DateTime.tryParse(raw);
    if (direct != null) return direct;

    final normalized = raw
        .replaceFirst(' ', 'T')
        .replaceAllMapped(
          RegExp(r'([+-]\d{2})$'),
          (match) => '${match.group(1)}:00',
        );
    final normalizedParsed = DateTime.tryParse(normalized);
    if (normalizedParsed != null) return normalizedParsed;

    final zulu = normalized.replaceAll(RegExp(r'([+-]00:00)$'), 'Z');
    return DateTime.tryParse(zulu);
  }

  static String _slotTime(Map<String, dynamic> slot) {
    final dt = _slotDateTime(slot);
    if (dt == null) {
      return (slot['start_time'] ?? '').toString();
    }
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  static String _slotLongLabel(Map<String, dynamic>? slot) {
    final dt = _slotDateTime(slot);
    if (dt == null) return '15 ноября, 10:00';
    final month = _ruMonthsGenitive[dt.month - 1];
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} $month, $hh:$mm';
  }

  static String _slotShortLabel(Map<String, dynamic>? slot) {
    final dt = _slotDateTime(slot);
    if (dt == null) return 'Не выбрано';
    final month = _ruMonthsShort[dt.month - 1];
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} $month, $hh:$mm';
  }

  static String? _dateKey(Map<String, dynamic>? slot) {
    final dt = _slotDateTime(slot);
    if (dt == null) return null;
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    return '${dt.year}-$mm-$dd';
  }

  static String _formatPrice(double value) {
    final rounded = value.round();
    final digits = rounded.toString();
    final sb = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final reverseIndex = digits.length - i;
      sb.write(digits[i]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) {
        sb.write(' ');
      }
    }
    return '${sb.toString().trim()} ₽';
  }

  static String _formatPriceFromAny(dynamic price) {
    if (price is num) return _formatPrice(price.toDouble());
    final parsed = double.tryParse((price ?? '').toString());
    if (parsed == null) return '—';
    return _formatPrice(parsed);
  }

  static const _ruMonthsShort = <String>[
    'янв',
    'фев',
    'мар',
    'апр',
    'май',
    'июн',
    'июл',
    'авг',
    'сен',
    'окт',
    'ноя',
    'дек',
  ];
  static const _ruMonthsGenitive = <String>[
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

class _SelectBlock extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _SelectBlock({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _BookingPageState._textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    color: _BookingPageState._textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.keyboard_arrow_down_rounded),
        ],
      ),
    ),
    );
  }
}

class _DateStrip extends StatelessWidget {
  final List<String> dateKeys;
  final String? selectedDateKey;
  final ValueChanged<String> onTap;

  const _DateStrip({
    required this.dateKeys,
    required this.selectedDateKey,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: dateKeys.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final key = dateKeys[index];
          final dt = DateTime.tryParse(key);
          final isSelected = key == selectedDateKey;
          final label = dt == null
              ? key
              : '${dt.day} ${_BookingPageState._ruMonthsShort[dt.month - 1]}';
          return InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => onTap(key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? _BookingPageState._accent : Colors.white,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : _BookingPageState._textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TimeSection extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> slots;
  final int? selectedSlotId;
  final ValueChanged<int> onTap;

  const _TimeSection({
    required this.title,
    required this.slots,
    required this.selectedSlotId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _BookingPageState._textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        _TimeWrap(
          slots: slots,
          selectedSlotId: selectedSlotId,
          onTap: onTap,
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _PickerOption {
  final int id;
  final String title;
  final String subtitle;

  const _PickerOption({
    required this.id,
    required this.title,
    required this.subtitle,
  });
}

class _PickerSheet extends StatelessWidget {
  final String title;
  final List<_PickerOption> options;

  const _PickerSheet({required this.title, required this.options});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          for (final option in options)
            ListTile(
              title: Text(option.title),
              subtitle: option.subtitle.isEmpty ? null : Text(option.subtitle),
              onTap: () => Navigator.of(context).pop(option.id),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _TimeWrap extends StatelessWidget {
  final List<Map<String, dynamic>> slots;
  final int? selectedSlotId;
  final ValueChanged<int> onTap;

  const _TimeWrap({
    required this.slots,
    required this.selectedSlotId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) {
      return const Text(
        'Нет слотов',
        style: TextStyle(color: _BookingPageState._textSecondary),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: slots.map((slot) {
        final id = slot['id'] as int;
        final isSelected = selectedSlotId == id;
        return InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => onTap(id),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? _BookingPageState._accentSoft
                  : _BookingPageState._surfaceSoft,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _BookingPageState._slotTime(slot),
              style: TextStyle(
                color: isSelected
                    ? _BookingPageState._accentText
                    : _BookingPageState._textPrimary,
                fontSize: 14,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
