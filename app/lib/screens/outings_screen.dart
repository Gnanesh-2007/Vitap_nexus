import 'dart:io';

import 'package:flutter/material.dart';
import '../widgets/nexus_segmented.dart';
import '../widgets/nexus_app_bar.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../providers/auth_provider.dart';
import '../providers/vtop_providers.dart';
import '../services/api_client.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/download_helper.dart';
import '../utils/error_formatter.dart';
import '../widgets/motion/nexus_motion.dart';
import '../widgets/shadcn/shadcn_ui.dart';

/// Outing constants modeled after vitap_student_app_ref AppConstants
class OutingConstants {
  static const List<String> outingPlaces = [
    'Vijayawada',
    'Guntur',
    'Tenali',
    'Eluru',
    'Others',
  ];

  static const List<String> outingTimeSlots = [
    '9:30 AM- 3:30PM',
    '10:30 AM- 4:30PM',
    '11:30 AM- 5:30PM',
    '12:30 PM- 6:30PM',
  ];
}

class OutingsScreen extends ConsumerStatefulWidget {
  const OutingsScreen({super.key});

  @override
  ConsumerState<OutingsScreen> createState() => _OutingsScreenState();
}

class _OutingsScreenState extends ConsumerState<OutingsScreen> {
  // 'apply' or 'history'
  bool _showHistory = false;

  // Selected Outing Type: 'weekend' or 'general'
  String _outingType = 'weekend';

  // Weekend Form State
  String _selectedWeekendPlace = OutingConstants.outingPlaces.first;
  final _customWeekendPlaceController = TextEditingController();
  String _selectedWeekendSlot = OutingConstants.outingTimeSlots.first;
  late DateTime _outingDate;

  // General Form State
  final _generalPlaceController = TextEditingController();
  late DateTime _leavingDate;
  TimeOfDay _leavingTime = const TimeOfDay(hour: 9, minute: 30);
  late DateTime _returningDate;
  TimeOfDay _returningTime = const TimeOfDay(hour: 18, minute: 30);

  // Shared Controllers
  final _purposeController = TextEditingController();
  final _contactController = TextEditingController();
  final _searchController = TextEditingController();

  // History Sort State (Recent first vs Oldest first)
  bool _isRecentFirst = true;

  bool _isSubmitting = false;

  late Future<dynamic> _generalOutingsFuture;
  late Future<dynamic> _weekendOutingsFuture;
  dynamic _cachedGeneral;
  dynamic _cachedWeekend;

  // Editorial campus palette
  AppPalette get _palette => AppPalette.of(context);
  Color get _paper => _palette.paper;
  Color get _surface => _palette.surface;
  Color get _ink => _palette.ink;
  Color get _inkSoft => _palette.inkSoft;
  Color get _navy => _palette.navy;
  Color get _blue => _palette.blue;
  Color get _orange => _palette.orange;
  Color get _green => _palette.green;
  Color get _red => _palette.red;
  Color get _muted => _palette.inkMuted;
  Color get _line => _palette.line;
  Color get _soft => _palette.soft;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _outingDate = _nextAllowedWeekendDate(now);
    _leavingDate = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    _returningDate = _leavingDate;

    _cachedGeneral = StorageService.getMemoryCache('general_outings');
    _cachedWeekend = StorageService.getMemoryCache('weekend_outings');
    _prefillContactFromProfile();
    _loadOutings();
  }

  void _prefillContactFromProfile() {
    final memProfile = StorageService.getMemoryCache('profile');
    if (memProfile is Map) {
      final mobile = (memProfile['mobile_number'] ?? memProfile['phone'] ?? '').toString().trim();
      final digits = mobile.replaceAll(RegExp(r'\D'), '');
      if (digits.length >= 10) {
        _contactController.text = digits.substring(digits.length - 10);
      }
    }
  }

  static DateTime _nextAllowedWeekendDate(DateTime from) {
    var cursor = DateTime(from.year, from.month, from.day);
    for (var i = 0; i < 8; i++) {
      if (cursor.weekday == DateTime.sunday || cursor.weekday == DateTime.monday) {
        return cursor;
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    return DateTime(from.year, from.month, from.day).add(const Duration(days: 1));
  }

  void _loadOutings() {
    final auth = ref.read(authProvider);
    _generalOutingsFuture = apiService
        .fetchGeneralOutings(
          username: auth.username ?? '',
          password: auth.password ?? '',
        )
        .then((data) {
          if (data != null) {
            StorageService.setCache('general_outings', data);
            if (mounted) setState(() => _cachedGeneral = data);
          }
          return data;
        });
    _weekendOutingsFuture = apiService
        .fetchWeekendOutings(
          username: auth.username ?? '',
          password: auth.password ?? '',
        )
        .then((data) {
          if (data != null) {
            StorageService.setCache('weekend_outings', data);
            if (mounted) setState(() => _cachedWeekend = data);
          }
          return data;
        });
  }

  List<Map<String, dynamic>> _extractRequests(dynamic data) {
    if (data == null) return [];
    List<dynamic> list = [];
    if (data is List) {
      list = data;
    } else if (data is Map) {
      final reqs = data['root'] ?? data['requests'] ?? data['data'] ?? data['history'];
      if (reqs is List) {
        list = reqs;
      }
    }
    return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  @override
  void dispose() {
    _customWeekendPlaceController.dispose();
    _generalPlaceController.dispose();
    _purposeController.dispose();
    _contactController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String? _validateContactNumber(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Please enter a 10-digit contact number.';
    }
    final digitsOnly = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length != 10) {
      return 'Contact number must be 10 digits.';
    }
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(digitsOnly)) {
      return 'Enter a valid Indian mobile number.';
    }
    return null;
  }

  String? _validateGeneralSpan({
    required DateTime leaveDate,
    required TimeOfDay leaveTime,
    required DateTime returnDate,
    required TimeOfDay returnTime,
  }) {
    final leave = DateTime(
      leaveDate.year,
      leaveDate.month,
      leaveDate.day,
      leaveTime.hour,
      leaveTime.minute,
    );
    final ret = DateTime(
      returnDate.year,
      returnDate.month,
      returnDate.day,
      returnTime.hour,
      returnTime.minute,
    );
    if (!ret.isAfter(leave)) {
      return 'Return date & time must be after departure.';
    }
    return null;
  }

  Future<void> _handleApplyPressed() async {
    FocusScope.of(context).unfocus();

    final purpose = _purposeController.text.trim();
    if (purpose.isEmpty) {
      _showMessage('Please enter the purpose of visit.', color: _red);
      return;
    }

    if (_outingType == 'weekend') {
      final contactErr = _validateContactNumber(_contactController.text);
      if (contactErr != null) {
        _showMessage(contactErr, color: _red);
        return;
      }

      final place = _selectedWeekendPlace == 'Others' &&
              _customWeekendPlaceController.text.trim().isNotEmpty
          ? _customWeekendPlaceController.text.trim()
          : _selectedWeekendPlace;

      final confirmed = await _showOutingConfirmSheet(
        title: 'Weekend Outing',
        fields: [
          MapEntry(
            'Date',
            '${DateFormat('dd MMM yyyy').format(_outingDate)} (${DateFormat('EEEE').format(_outingDate)})',
          ),
          MapEntry('Time slot', _selectedWeekendSlot),
          MapEntry('Place', place),
          MapEntry('Purpose', purpose),
          MapEntry('Contact', _contactController.text.trim()),
        ],
      );
      if (!confirmed) return;

      await _submitWeekend(place: place, purpose: purpose);
    } else {
      final place = _generalPlaceController.text.trim();
      if (place.isEmpty) {
        _showMessage('Please enter the place of visit.', color: _red);
        return;
      }

      final spanErr = _validateGeneralSpan(
        leaveDate: _leavingDate,
        leaveTime: _leavingTime,
        returnDate: _returningDate,
        returnTime: _returningTime,
      );
      if (spanErr != null) {
        _showMessage(spanErr, color: _red);
        return;
      }

      final leaveTimeStr =
          '${_leavingTime.hour.toString().padLeft(2, '0')}:${_leavingTime.minute.toString().padLeft(2, '0')}';
      final returnTimeStr =
          '${_returningTime.hour.toString().padLeft(2, '0')}:${_returningTime.minute.toString().padLeft(2, '0')}';

      final days = _returningDate.difference(_leavingDate).inDays;
      final durationLabel = days == 0
          ? 'Same day'
          : '$days ${days == 1 ? "day" : "days"}';

      final confirmed = await _showOutingConfirmSheet(
        title: 'General Outing',
        fields: [
          MapEntry(
            'Leaving',
            '${DateFormat('dd MMM yyyy').format(_leavingDate)} at $leaveTimeStr',
          ),
          MapEntry(
            'Returning',
            '${DateFormat('dd MMM yyyy').format(_returningDate)} at $returnTimeStr',
          ),
          MapEntry('Duration', durationLabel),
          MapEntry('Place', place),
          MapEntry('Purpose', purpose),
        ],
      );
      if (!confirmed) return;

      await _submitGeneral(
        place: place,
        purpose: purpose,
        outTimeStr: leaveTimeStr,
        inTimeStr: returnTimeStr,
      );
    }
  }

  Future<bool> _showOutingConfirmSheet({
    required String title,
    required List<MapEntry<String, String>> fields,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
      ),
      builder: (modalCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _line,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Check the details before this goes to VTOP',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _inkSoft,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: _soft,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < fields.length; i++) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 96,
                                child: Text(
                                  fields[i].key,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: _muted,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  fields[i].value,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: _ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (i < fields.length - 1)
                          Divider(height: 1, thickness: 0.6, color: _line),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 50,
                  child: FilledButton(
                    onPressed: () => Navigator.of(modalCtx).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: _navy,
                      foregroundColor: _palette.isDark
                          ? const Color(0xFF0F172A)
                          : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Confirm and apply',
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 44,
                  child: TextButton(
                    onPressed: () => Navigator.of(modalCtx).pop(false),
                    style: TextButton.styleFrom(
                      foregroundColor: _inkSoft,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'Go back and edit',
                      style: GoogleFonts.dmSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    return result ?? false;
  }

  Future<void> _submitWeekend({
    required String place,
    required String purpose,
  }) async {
    final auth = ref.read(authProvider);
    final username = auth.username ?? '';
    final password = auth.password ?? '';
    final contact = _contactController.text.trim();

    setState(() => _isSubmitting = true);
    try {
      final outDateStr = DateFormat('dd-MMM-yyyy').format(_outingDate);
      final message = await apiService.submitWeekendOuting(
        username: username,
        password: password,
        outPlace: place,
        purposeOfVisit: purpose,
        outingDate: outDateStr,
        outTime: _selectedWeekendSlot,
        contactNumber: contact,
      );

      if (!mounted) return;

      final isError = message.toLowerCase().startsWith('error') ||
          message.toLowerCase().contains('failed') ||
          message.toLowerCase().contains('not allowed');

      _showMessage(
        ErrorFormatter.cleanRawMessage(message),
        color: isError ? _red : _green,
      );

      if (!isError) {
        _purposeController.clear();
        _customWeekendPlaceController.clear();
      }

      setState(() {
        _isSubmitting = false;
        _loadOutings();
        if (!isError) {
          _showHistory = true;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showMessage(
        ErrorFormatter.format(
          e,
          fallback: 'Unable to submit weekend outing request. Please try again.',
        ),
        color: _red,
      );
    }
  }

  Future<void> _submitGeneral({
    required String place,
    required String purpose,
    required String outTimeStr,
    required String inTimeStr,
  }) async {
    final auth = ref.read(authProvider);
    final username = auth.username ?? '';
    final password = auth.password ?? '';

    setState(() => _isSubmitting = true);
    try {
      final outDateStr = DateFormat('dd-MMM-yyyy').format(_leavingDate);
      final inDateStr = DateFormat('dd-MMM-yyyy').format(_returningDate);

      final message = await apiService.submitGeneralOuting(
        username: username,
        password: password,
        outPlace: place,
        purposeOfVisit: purpose,
        outingDate: outDateStr,
        outTime: outTimeStr,
        inDate: inDateStr,
        inTime: inTimeStr,
      );

      if (!mounted) return;

      final isError = message.toLowerCase().startsWith('error') ||
          message.toLowerCase().contains('failed') ||
          message.toLowerCase().contains('not allowed');

      _showMessage(
        ErrorFormatter.cleanRawMessage(message),
        color: isError ? _red : _green,
      );

      if (!isError) {
        _generalPlaceController.clear();
        _purposeController.clear();
      }

      setState(() {
        _isSubmitting = false;
        _loadOutings();
        if (!isError) {
          _showHistory = true;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showMessage(
        ErrorFormatter.format(
          e,
          fallback: 'Unable to submit general outing request. Please try again.',
        ),
        color: _red,
      );
    }
  }

  Future<void> _deleteOuting(String id, bool isWeekend) async {
    final auth = ref.read(authProvider);

    try {
      String msg;
      if (isWeekend) {
        msg = await apiService.deleteWeekendOuting(
          username: auth.username ?? '',
          password: auth.password ?? '',
          bookingId: id,
        );
      } else {
        msg = await apiService.deleteGeneralOuting(
          username: auth.username ?? '',
          password: auth.password ?? '',
          leaveId: id,
        );
      }

      if (!mounted) return;

      _showMessage(
        msg.isNotEmpty ? ErrorFormatter.cleanRawMessage(msg) : 'Outing request cancelled successfully.',
        color: _green,
      );
      setState(_loadOutings);
    } catch (e) {
      if (!mounted) return;
      _showMessage(
        ErrorFormatter.format(
          e,
          fallback: 'Failed to cancel outing request. Please try again.',
        ),
        color: _red,
      );
    }
  }

  /// Fetches REAL PDF bytes from VTOP for Weekend or General Outing
  Future<Uint8List> _fetchRealOutingPdfBytes({
    required String id,
    required bool isWeekend,
  }) async {
    final auth = ref.read(authProvider);
    final creds = await StorageService.getCredentials();
    final username = auth.username ?? creds['username'] ?? '';
    final password = auth.password ?? creds['password'] ?? '';

    if (id.trim().isEmpty) {
      throw Exception('Outing pass ID is missing. Please refresh outing history and try again.');
    }

    final List<int> rawBytes = isWeekend
        ? await apiService.downloadWeekendOutingForm(
            username: username,
            password: password,
            bookingId: id.trim(),
          )
        : await apiService.downloadGeneralOutingPass(
            username: username,
            password: password,
            leaveId: id.trim(),
          );

    if (rawBytes.isEmpty) {
      throw Exception('VTOP returned an empty outing pass file.');
    }

    // Check if VTOP returned an HTML error/login page instead of a PDF
    if (rawBytes.length < 1500) {
      final text = String.fromCharCodes(rawBytes);
      if (text.contains('<html') ||
          text.contains('<!DOCTYPE') ||
          text.contains('Session expired') ||
          text.contains('Invalid session')) {
        throw Exception('VTOP session expired or pass is not ready yet. Please refresh and try again.');
      }
    }

    return Uint8List.fromList(rawBytes);
  }

  void _showMessage(String message, {required Color color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(
          message,
          style: GoogleFonts.dmSans(
            color: Colors.white,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _paper,
      body: SafeArea(
        child: _showHistory ? _buildHistoryView() : _buildApplyView(),
      ),
    );
  }

  // ============================================================
  // APPLY VIEW (vitap_student_app_ref Weekend & General Tabs)
  // ============================================================
  Widget _buildApplyView() {
    final isWeekend = _outingType == 'weekend';

    return Column(
      children: [
        _buildApplyHeader(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
            children: [
              // Outing Type Toggle (Weekend | General)
              _buildSegmentedToggle(),

              const SizedBox(height: 16),
              _buildPassPreview(isWeekend),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: _line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              if (isWeekend) ...[
                // 1. Time Slot Choice Chips (OutingConstants.outingTimeSlots)
                _buildFieldLabel('Time slot'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: OutingConstants.outingTimeSlots.map((slot) {
                    final isSelected = _selectedWeekendSlot == slot;
                    return _buildChoiceChip(
                      label: slot,
                      selected: isSelected,
                      onTap: () => setState(() => _selectedWeekendSlot = slot),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 20),

                // 2. Outing Date Picker Card
                _buildFieldLabel('Outing date'),
                const SizedBox(height: 8),
                _buildDatePickerCard(
                  label: 'Select outing date',
                  value:
                      '${DateFormat('dd/MM/yyyy').format(_outingDate)} · ${DateFormat('EEEE').format(_outingDate)}',
                  onTap: () async {
                    final now = DateTime.now();
                    final today = DateTime(now.year, now.month, now.day);
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _outingDate.isBefore(today) ? today : _outingDate,
                      firstDate: today,
                      lastDate: today.add(const Duration(days: 60)),
                      helpText: 'Select outing date (Sundays & Mondays)',
                      builder: _pickerTheme,
                    );
                    if (picked != null) {
                      setState(() => _outingDate = picked);
                    }
                  },
                ),

                const SizedBox(height: 20),

                // 3. Place of Visit Choice Chips (OutingConstants.outingPlaces)
                _buildFieldLabel('Place of visit'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: OutingConstants.outingPlaces.map((place) {
                    final isSelected = _selectedWeekendPlace == place;
                    return _buildChoiceChip(
                      label: place,
                      selected: isSelected,
                      onTap: () => setState(() => _selectedWeekendPlace = place),
                    );
                  }).toList(),
                ),

                if (_selectedWeekendPlace == 'Others') ...[
                  const SizedBox(height: 12),
                  _buildPillTextField(
                    hint: 'Specify place of visit',
                    controller: _customWeekendPlaceController,
                  ),
                ],

                const SizedBox(height: 20),

                // 4. Purpose of visit
                _buildFieldLabel('Purpose of visit'),
                const SizedBox(height: 8),
                _buildPillTextField(
                  hint: 'Shopping, family visit, medical...',
                  controller: _purposeController,
                ),

                const SizedBox(height: 16),

                // 5. Contact number
                _buildFieldLabel('Contact number'),
                const SizedBox(height: 8),
                _buildPillTextField(
                  hint: '10-digit mobile number',
                  controller: _contactController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                ),
              ] else ...[
                // General Outing Form
                _buildFieldLabel('Place of visit'),
                const SizedBox(height: 8),
                _buildPillTextField(
                  hint: 'Home town, hospital, event venue...',
                  controller: _generalPlaceController,
                ),

                const SizedBox(height: 16),

                _buildFieldLabel('Purpose of visit'),
                const SizedBox(height: 8),
                _buildPillTextField(
                  hint: 'Family function, medical checkup...',
                  controller: _purposeController,
                ),

                const SizedBox(height: 20),

                // Leaving Section
                _buildFieldLabel('Leaving'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildPillPicker(
                        hint: 'Date',
                        value: DateFormat('dd/MM/yyyy').format(_leavingDate),
                        icon: Icons.calendar_today_outlined,
                        onTap: () async {
                          final now = DateTime.now();
                          final today = DateTime(now.year, now.month, now.day);
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _leavingDate.isBefore(today) ? today : _leavingDate,
                            firstDate: today,
                            lastDate: today.add(const Duration(days: 60)),
                            helpText: 'Select departure date',
                            builder: _pickerTheme,
                          );
                          if (picked != null) {
                            setState(() {
                              _leavingDate = picked;
                              if (_returningDate.isBefore(picked)) {
                                _returningDate = picked;
                              }
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildPillPicker(
                        hint: 'Time',
                        value:
                            '${_leavingTime.hour.toString().padLeft(2, '0')}:${_leavingTime.minute.toString().padLeft(2, '0')}',
                        icon: Icons.access_time_rounded,
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: _leavingTime,
                            helpText: 'Select departure time',
                            builder: _pickerTheme,
                          );
                          if (picked != null) {
                            setState(() => _leavingTime = picked);
                          }
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Returning Section
                _buildFieldLabel('Returning'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildPillPicker(
                        hint: 'Date',
                        value: DateFormat('dd/MM/yyyy').format(_returningDate),
                        icon: Icons.calendar_today_outlined,
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _returningDate.isBefore(_leavingDate)
                                ? _leavingDate
                                : _returningDate,
                            firstDate: _leavingDate,
                            lastDate: DateTime.now().add(const Duration(days: 60)),
                            helpText: 'Select return date',
                            builder: _pickerTheme,
                          );
                          if (picked != null) {
                            setState(() => _returningDate = picked);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildPillPicker(
                        hint: 'Time',
                        value:
                            '${_returningTime.hour.toString().padLeft(2, '0')}:${_returningTime.minute.toString().padLeft(2, '0')}',
                        icon: Icons.access_time_rounded,
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: _returningTime,
                            helpText: 'Select return time',
                            builder: _pickerTheme,
                          );
                          if (picked != null) {
                            setState(() => _returningTime = picked);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
                  ],
                ),
              ),

              const SizedBox(height: 22),

              // Primary Apply Button
              SizedBox(
                height: 58,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _handleApplyPressed,
                  style: FilledButton.styleFrom(
                    backgroundColor: _navy,
                    foregroundColor:
                        _palette.isDark ? const Color(0xFF0F172A) : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(29),
                    ),
                  ),
                  child: _isSubmitting
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: _palette.isDark
                                ? const Color(0xFF0F172A)
                                : Colors.white,
                          ),
                        )
                      : Text(
                          'Apply for outing',
                          style: GoogleFonts.bricolageGrotesque(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 12),

              // Secondary Button: View outing history
              SizedBox(
                height: 54,
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _showHistory = true),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _ink,
                    side: BorderSide(color: _line, width: 1.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(27),
                    ),
                  ),
                  icon: const Icon(Icons.history_rounded, size: 18),
                  label: Text(
                    'View outing history',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// A small ticket that shows what you are about to apply for, live.
  Widget _buildPassPreview(bool isWeekend) {
    final hsl = HSLColor.fromColor(_navy);
    final top = hsl.withLightness(hsl.lightness.clamp(0.0, 0.42)).withSaturation(hsl.saturation.clamp(0.5, 1.0)).toColor();
    final bottom = Color.lerp(top, const Color(0xFF16102E), 0.72)!;
    final from = isWeekend ? _outingDate : _leavingDate;
    final place = isWeekend
        ? (_selectedWeekendPlace == 'Others' ? 'Other place' : _selectedWeekendPlace)
        : (_generalPlaceController.text.trim().isEmpty ? 'Where to?' : _generalPlaceController.text.trim());
    final subtitle = isWeekend
        ? _selectedWeekendSlot
        : 'Back ${DateFormat('d MMM').format(_returningDate)}';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [top, bottom]),
        boxShadow: [BoxShadow(color: top.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 9))],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${from.day}',
                  style: GoogleFonts.bricolageGrotesque(fontSize: 44, fontWeight: FontWeight.w800, color: Colors.white, height: 0.95, letterSpacing: -1.5)),
              Text('${DateFormat('MMM').format(from).toUpperCase()}  ·  ${DateFormat('EEE').format(from).toUpperCase()}',
                  style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1, color: Colors.white70)),
            ],
          ),
          const Spacer(),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(isWeekend ? 'WEEKEND OUTING' : 'GENERAL OUTING',
                    style: GoogleFonts.dmSans(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1.1, color: Colors.white70)),
                const SizedBox(height: 4),
                Text(place,
                    maxLines: 2,
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.bricolageGrotesque(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white, height: 1.1)),
                const SizedBox(height: 3),
                Text(subtitle, style: GoogleFonts.dmSans(fontSize: 12, color: Colors.white.withValues(alpha: 0.82))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.bricolageGrotesque(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
        color: _ink,
      ),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final selectedFg = _palette.isDark ? const Color(0xFF0F172A) : Colors.white;
    return Material(
      color: selected ? _navy : _soft,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? _navy : _line,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                Icon(Icons.check_rounded, size: 15, color: selectedFg),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? selectedFg : _ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildApplyHeader() {
    return NexusAppBar(
      title: 'Outing',
      subtitle: 'Apply for a pass',
      actions: [
        IconButton(
          tooltip: 'Outing History',
          onPressed: () => setState(() => _showHistory = true),
          icon: const Icon(Icons.history_rounded),
        ),
      ],
    );
  }

  Widget _buildSegmentedToggle() {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: _outingType == 'weekend' ? 0.0 : 1.0),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (_, pos, _) => NexusSegmented(
        labels: const ['Weekend', 'General'],
        position: pos,
        onSelect: (i) => setState(() => _outingType = i == 0 ? 'weekend' : 'general'),
      ),
    );
  }

  Widget _buildPillTextField({
    required String hint,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: _soft,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _line),
      ),
      alignment: Alignment.centerLeft,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        style: GoogleFonts.dmSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: _ink,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.dmSans(
            fontSize: 13.5,
            color: _muted,
            fontWeight: FontWeight.w500,
          ),
          border: InputBorder.none,
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildDatePickerCard({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: _soft,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _line),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              value.isNotEmpty ? value : label,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
            ),
            Icon(Icons.calendar_today_outlined, size: 18, color: _inkSoft),
          ],
        ),
      ),
    );
  }

  Widget _buildPillPicker({
    required String hint,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: _soft,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _line),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              value.isNotEmpty ? value : hint,
              style: GoogleFonts.dmSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
            ),
            Icon(icon, size: 18, color: _inkSoft),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HISTORY VIEW (vitap_student_app_ref Weekend & General History)
  // ============================================================
  Widget _buildHistoryView() {
    final isWeekend = _outingType == 'weekend';
    final historyTitle =
        isWeekend ? 'Weekend Outing History' : 'General Outing History';
    final future = isWeekend ? _weekendOutingsFuture : _generalOutingsFuture;

    return Column(
      children: [
        NexusAppBar(
          title: 'History',
          subtitle: historyTitle,
          onBack: () => setState(() => _showHistory = false),
          actions: [
            IconButton(
              onPressed: () => setState(_loadOutings),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),

        // Type Switcher in History View
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: _buildSegmentedToggle(),
        ),

        // Search Bar + Sort Toggle Button (matching vitap_student_app_ref)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: NexusSearchBar(
                  controller: _searchController,
                  hintText: 'Search outings...',
                  onChanged: (_) => setState(() {}),
                  onClear: () {
                    _searchController.clear();
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(width: 10),
              Tooltip(
                message: _isRecentFirst ? 'Recent first' : 'Oldest first',
                child: InkWell(
                  onTap: () => setState(() => _isRecentFirst = !_isRecentFirst),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _line),
                    ),
                    child: Icon(
                      _isRecentFirst
                          ? Icons.vertical_align_top_rounded
                          : Icons.vertical_align_bottom_rounded,
                      size: 20,
                      color: _navy,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // History List
        Expanded(
          child: RefreshIndicator(
            color: _blue,
            backgroundColor: _surface,
            onRefresh: () async => setState(_loadOutings),
            child: FutureBuilder<dynamic>(
              future: future,
              builder: (context, snapshot) {
                final rawData =
                    snapshot.data ?? (isWeekend ? _cachedWeekend : _cachedGeneral);
                var requests = _extractRequests(rawData);

                if (snapshot.connectionState == ConnectionState.waiting &&
                    requests.isEmpty) {
                  return Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: _navy,
                    ),
                  );
                }

                final query = _searchController.text.trim().toLowerCase();
                if (query.isNotEmpty) {
                  requests = requests.where((req) {
                    final place =
                        (req['place_of_visit'] ?? req['out_place'] ?? '')
                            .toString()
                            .toLowerCase();
                    final purpose =
                        (req['purpose_of_visit'] ?? req['reason'] ?? '')
                            .toString()
                            .toLowerCase();
                    final status = (req['status'] ?? '').toString().toLowerCase();
                    final date = (req['date'] ?? req['from_date'] ?? '')
                        .toString()
                        .toLowerCase();
                    final id = (req['booking_id'] ?? req['leave_id'] ?? '')
                        .toString()
                        .toLowerCase();
                    return place.contains(query) ||
                        purpose.contains(query) ||
                        status.contains(query) ||
                        date.contains(query) ||
                        id.contains(query);
                  }).toList();
                }

                // Sort by date according to _isRecentFirst
                requests.sort((a, b) {
                  final dateAStr = isWeekend
                      ? (a['date'] ?? a['from_date'] ?? '').toString()
                      : (a['from_date'] ?? a['date'] ?? '').toString();
                  final dateBStr = isWeekend
                      ? (b['date'] ?? b['from_date'] ?? '').toString()
                      : (b['from_date'] ?? b['date'] ?? '').toString();
                  final dtA = _parseOutingDate(dateAStr);
                  final dtB = _parseOutingDate(dateBStr);
                  if (dtA == null && dtB == null) return 0;
                  if (dtA == null) return 1;
                  if (dtB == null) return -1;
                  return _isRecentFirst ? dtB.compareTo(dtA) : dtA.compareTo(dtB);
                });

                if (requests.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 60),
                      NexusEmptyState(
                        title: query.isNotEmpty
                            ? 'No matching outings'
                            : 'No outing records found',
                        description: query.isNotEmpty
                            ? 'No outings matched "$query". Try a different search term.'
                            : 'You have no ${isWeekend ? 'weekend' : 'general'} outing requests on record.',
                        icon: Icons.event_busy_rounded,
                      ),
                    ],
                  );
                }

                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final req = requests[index];
                    return AnimeStaggerItem(
                      index: index,
                      child: _buildOutingCard(req, isWeekend),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  DateTime? _parseOutingDate(String rawDate) {
    if (rawDate.trim().isEmpty || rawDate == '-') return null;
    const formats = [
      'dd-MMM-yyyy',
      'dd-MM-yyyy',
      'yyyy-MM-dd',
      'dd/MM/yyyy',
      'd-MMM-yyyy',
      'd-MM-yyyy',
      'd/M/yyyy',
    ];
    for (final fmt in formats) {
      try {
        return DateFormat(fmt).parse(rawDate.trim());
      } catch (_) {}
    }
    try {
      return DateTime.parse(rawDate.trim());
    } catch (_) {
      return null;
    }
  }

  bool _isApprovedStatus(String status) {
    final s = status.trim().toLowerCase();
    if (s.contains('applied') && !s.contains('accepted') && !s.contains('approved')) {
      return false;
    }
    return s.contains('approved') ||
        s.contains('accepted') ||
        s == 'acc' ||
        s == 'appr';
  }

  bool _isRejectedStatus(String status) {
    final s = status.trim().toLowerCase();
    return s.contains('reject') || s.contains('denied') || s.contains('declined');
  }

  bool _isCancelledStatus(String status) {
    final s = status.trim().toLowerCase();
    return s.contains('cancel') || s.contains('deleted') || s.contains('closed');
  }

  String _getStatusShortText(String status) {
    if (_isApprovedStatus(status)) return 'Approved';
    if (_isRejectedStatus(status)) return 'Rejected';
    if (_isCancelledStatus(status)) return 'Cancelled';
    return 'Pending';
  }

  // Outing Card modeled after vitap_student_app_ref/weekend_outing_card.dart
  Widget _buildOutingCard(Map<String, dynamic> req, bool isWeekend) {
    final status =
        req['status']?.toString() ?? req['leave_status']?.toString() ?? 'Pending';

    final isApproved = _isApprovedStatus(status);
    final isRejected = _isRejectedStatus(status);
    final isCancelled = _isCancelledStatus(status);
    final isPending = !isApproved && !isRejected && !isCancelled;

    final place = req['place_of_visit']?.toString() ??
        req['out_place']?.toString() ??
        req['place']?.toString() ??
        '-';

    final purpose =
        req['purpose_of_visit']?.toString() ?? req['reason']?.toString() ?? '-';

    final outDate = isWeekend
        ? (req['date']?.toString() ?? req['from_date']?.toString() ?? '')
        : (req['from_date']?.toString() ?? req['date']?.toString() ?? '');

    final outTime = isWeekend
        ? (req['time']?.toString() ?? req['from_time']?.toString() ?? '')
        : (req['from_time']?.toString() ?? req['time']?.toString() ?? '');

    final toDate = !isWeekend ? (req['to_date']?.toString() ?? '') : '';
    final toTime = !isWeekend ? (req['to_time']?.toString() ?? '') : '';

    final leaveId = (req['booking_id'] ??
            req['leave_id'] ??
            req['appl_id'] ??
            req['id'] ??
            '')
        .toString()
        .trim();

    final canDownload =
        (req['can_download'] == true) || (isApproved && leaveId.isNotEmpty);

    final parsedDate = _parseOutingDate(outDate);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isToday = parsedDate != null &&
        parsedDate.year == today.year &&
        parsedDate.month == today.month &&
        parsedDate.day == today.day;
    final isUpcoming = parsedDate != null && parsedDate.isAfter(today);

    final formattedDate = parsedDate != null
        ? DateFormat('EEE, MMM d, yyyy').format(parsedDate)
        : (outDate.isNotEmpty ? outDate : 'Outing Date');

    final statusColor = isApproved
        ? _green
        : (isPending ? _orange : (isCancelled ? _muted : _red));

    final statusBg = isApproved
        ? _green.withValues(alpha: 0.14)
        : (isPending
            ? _orange.withValues(alpha: 0.14)
            : (isCancelled
                ? _muted.withValues(alpha: 0.14)
                : _red.withValues(alpha: 0.14)));

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NexusCard(
        variant: NexusCardVariant.standard,
        padding: const EdgeInsets.all(18),
        borderColor: isToday ? _blue : _line,
        onTap: () => _openOutingDetailsModal(req, isWeekend),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Date Chip (+ TODAY/UPCOMING badge) on left, Status Badge on right
            Row(
              children: [
                Flexible(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _soft,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 13,
                              color: _inkSoft,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              formattedDate,
                              style: GoogleFonts.bricolageGrotesque(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isToday || isUpcoming)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isToday
                                ? _blue
                                : _blue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            isToday ? 'TODAY' : 'UPCOMING',
                            style: GoogleFonts.bricolageGrotesque(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: isToday ? Colors.white : _blue,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _getStatusShortText(status),
                        style: GoogleFonts.bricolageGrotesque(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Place of Visit (Large title)
            Text(
              place,
              style: GoogleFonts.dmSans(
                fontSize: 17.5,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),

            if (purpose.isNotEmpty && purpose != '-') ...[
              const SizedBox(height: 3),
              Text(
                purpose,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: _inkSoft,
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Schedule Info Row
            if (isWeekend && outTime.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.access_time_rounded, size: 15, color: _inkSoft),
                  const SizedBox(width: 6),
                  Text(
                    'Time  ',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _muted,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      outTime,
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (!isWeekend) ...[
              Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 15, color: _inkSoft),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '$outDate $outTime  →  $toDate $toTime',
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // Pass available Chip (when real PDF download is available)
            if (canDownload) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _soft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _line),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.description_outlined, size: 13, color: _navy),
                    const SizedBox(width: 5),
                    Text(
                      'Pass available',
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _navy,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // OUTING DETAILS BOTTOM SHEET MODAL (Real VTOP PDF View & Download)
  // ============================================================
  void _openOutingDetailsModal(Map<String, dynamic> req, bool isWeekend) {
    final auth = ref.read(authProvider);
    final dash = ref.read(dashboardProvider);
    final profile = (dash.data?['profile'] as Map<String, dynamic>?) ?? {};

    final regNo = req['registration_number']?.toString() ??
        profile['application_number']?.toString() ??
        auth.username ??
        '';
    final hostelBlock =
        req['hostel_block']?.toString() ?? profile['hostel_block']?.toString() ?? '';
    final roomNo =
        req['room_number']?.toString() ?? profile['room_number']?.toString() ?? '';

    final leaveId = (req['booking_id'] ??
            req['leave_id'] ??
            req['appl_id'] ??
            req['id'] ??
            '')
        .toString()
        .trim();

    final place = req['place_of_visit']?.toString() ??
        req['out_place']?.toString() ??
        req['place']?.toString() ??
        '-';

    final purpose =
        req['purpose_of_visit']?.toString() ?? req['reason']?.toString() ?? '-';

    final outDate = isWeekend
        ? (req['date']?.toString() ?? '-')
        : (req['from_date']?.toString() ?? req['date']?.toString() ?? '-');

    final outTime = isWeekend
        ? (req['time']?.toString() ?? '-')
        : (req['from_time']?.toString() ?? req['time']?.toString() ?? '-');

    final toDate = !isWeekend ? req['to_date']?.toString() : null;
    final toTime = !isWeekend ? req['to_time']?.toString() : null;

    final contactNo = req['contact_number']?.toString() ?? '';
    final parentContact = req['parent_contact_number']?.toString() ?? '';

    final status =
        req['status']?.toString() ?? req['leave_status']?.toString() ?? 'Pending';
    final isApproved = _isApprovedStatus(status);
    final isRejected = _isRejectedStatus(status);
    final isCancelled = _isCancelledStatus(status);
    final isPending = !isApproved && !isRejected && !isCancelled;

    final canDownload =
        (req['can_download'] == true) || (isApproved && leaveId.isNotEmpty);

    final statusColor = isApproved
        ? _green
        : (isPending ? _orange : (isCancelled ? _muted : _red));
    final statusIcon = isApproved
        ? Icons.check_circle_rounded
        : (isPending ? Icons.schedule_rounded : Icons.cancel_rounded);

    String? activePdfAction; // 'view' or 'download'

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
      ),
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final isBusy = activePdfAction != null;

            Future<void> handlePdfAction({required bool openOnly}) async {
              if (isBusy) return;
              setModalState(() {
                activePdfAction = openOnly ? 'view' : 'download';
              });

              try {
                final pdfBytes = await _fetchRealOutingPdfBytes(
                  id: leaveId,
                  isWeekend: isWeekend,
                );

                final fileName = isWeekend
                    ? 'weekend_outing_$leaveId.pdf'
                    : 'general_outing_$leaveId.pdf';

                if (openOnly) {
                  final tempDir = await getTemporaryDirectory();
                  final tempPath = '${tempDir.path}/$fileName';
                  final file = File(tempPath);
                  await file.writeAsBytes(pdfBytes, flush: true);
                  if (ctx.mounted) {
                    setModalState(() => activePdfAction = null);
                  }
                  await DownloadHelper.openFile(tempPath);
                } else {
                  if (ctx.mounted) {
                    setModalState(() => activePdfAction = null);
                    Navigator.of(modalCtx).pop();
                  }
                  if (!mounted) return;
                  await DownloadHelper.saveFile(
                    context: context,
                    fileName: fileName,
                    content: pdfBytes,
                    mimeType: 'application/pdf',
                    openImmediately: false,
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  setModalState(() => activePdfAction = null);
                }
                if (!mounted) return;
                _showMessage(
                  ErrorFormatter.format(
                    e,
                    fallback: 'Failed to download official outing pass from VTOP.',
                  ),
                  color: _red,
                );
              }
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Drag Handle
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: _line,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Header Banner (modeled after vitap_student_app_ref detail bottom sheet)
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              HSLColor.fromColor(statusColor).withLightness(HSLColor.fromColor(statusColor).lightness.clamp(0.0, 0.40)).toColor(),
                              Color.lerp(HSLColor.fromColor(statusColor).withLightness(HSLColor.fromColor(statusColor).lightness.clamp(0.0, 0.40)).toColor(), const Color(0xFF16102E), 0.72)!,
                            ],
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                statusIcon,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isWeekend ? 'Weekend Outing' : 'General Outing',
                                    style: GoogleFonts.bricolageGrotesque(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.4,
                                      color: Colors.white,
                                    ),
                                  ),
                                  if (purpose.isNotEmpty && purpose != '-') ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      purpose,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.dmSans(
                                        fontSize: 13,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                _getStatusShortText(status),
                                style: GoogleFonts.bricolageGrotesque(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: HSLColor.fromColor(statusColor).withLightness(HSLColor.fromColor(statusColor).lightness.clamp(0.0, 0.40)).toColor(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Outing Details Section
                      _buildModalSectionTitle('Outing Details'),
                      if (place.isNotEmpty && place != '-')
                        _buildModalDetailRow(
                          Icons.location_on_outlined,
                          'Place of Visit',
                          place,
                        ),
                      if (purpose.isNotEmpty && purpose != '-')
                        _buildModalDetailRow(
                          Icons.description_outlined,
                          'Purpose',
                          purpose,
                        ),
                      if (regNo.isNotEmpty)
                        _buildModalDetailRow(
                          Icons.badge_outlined,
                          'Registration Number',
                          regNo,
                        ),
                      if (leaveId.isNotEmpty)
                        _buildModalDetailRow(
                          Icons.confirmation_number_outlined,
                          isWeekend ? 'Booking ID' : 'Leave ID',
                          leaveId,
                        ),
                      if (contactNo.isNotEmpty)
                        _buildModalDetailRow(
                          Icons.phone_outlined,
                          'Contact Number',
                          contactNo,
                        ),
                      if (parentContact.isNotEmpty)
                        _buildModalDetailRow(
                          Icons.contact_phone_outlined,
                          'Parent Contact',
                          parentContact,
                        ),
                      _buildModalDetailRow(
                        Icons.info_outline_rounded,
                        'Status',
                        status,
                      ),

                      // Accommodation Section
                      if (hostelBlock.isNotEmpty || roomNo.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildModalSectionTitle('Accommodation'),
                        if (hostelBlock.isNotEmpty)
                          _buildModalDetailRow(
                            Icons.apartment_outlined,
                            'Hostel Block',
                            hostelBlock,
                          ),
                        if (roomNo.isNotEmpty)
                          _buildModalDetailRow(
                            Icons.door_front_door_outlined,
                            'Room Number',
                            roomNo,
                          ),
                      ],

                      // Schedule Section
                      const SizedBox(height: 16),
                      _buildModalSectionTitle('Schedule'),
                      _buildModalDetailRow(
                        Icons.calendar_today_outlined,
                        isWeekend ? 'Date' : 'From Date',
                        outDate,
                      ),
                      _buildModalDetailRow(
                        Icons.access_time_outlined,
                        isWeekend ? 'Time Slot' : 'From Time',
                        outTime,
                      ),
                      if (toDate != null && toDate.isNotEmpty)
                        _buildModalDetailRow(
                          Icons.calendar_today_outlined,
                          'To Date',
                          toDate,
                        ),
                      if (toTime != null && toTime.isNotEmpty)
                        _buildModalDetailRow(
                          Icons.access_time_outlined,
                          'To Time',
                          toTime,
                        ),

                      const SizedBox(height: 20),

                      // Real VTOP PDF View & Download Buttons
                      if (canDownload) ...[
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: FilledButton.icon(
                            onPressed: isBusy
                                ? null
                                : () => handlePdfAction(openOnly: true),
                            style: FilledButton.styleFrom(
                              backgroundColor: _green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(27),
                              ),
                            ),
                            icon: activePdfAction == 'view'
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.visibility_outlined, size: 19),
                            label: Text(
                              activePdfAction == 'view'
                                  ? 'Opening VTOP Pass...'
                                  : 'View PDF',
                              style: GoogleFonts.dmSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: OutlinedButton.icon(
                            onPressed: isBusy
                                ? null
                                : () => handlePdfAction(openOnly: false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _green,
                              side: BorderSide(color: _green, width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(27),
                              ),
                            ),
                            icon: activePdfAction == 'download'
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: _green,
                                    ),
                                  )
                                : const Icon(Icons.download_rounded, size: 19),
                            label: Text(
                              activePdfAction == 'download'
                                  ? 'Downloading from VTOP...'
                                  : 'Download',
                              style: GoogleFonts.dmSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],

                      // Cancel Outing Request (when not approved and leaveId exists)
                      if (!isApproved && !isCancelled && leaveId.isNotEmpty) ...[
                        if (canDownload) const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: isBusy
                                ? null
                                : () async {
                                    final confirmed = await showDialog<bool>(
                                      context: modalCtx,
                                      builder: (dCtx) => AlertDialog(
                                        backgroundColor: _surface,
                                        title: Text(
                                          'Delete Outing',
                                          style: GoogleFonts.dmSans(
                                            fontWeight: FontWeight.w800,
                                            color: _ink,
                                          ),
                                        ),
                                        content: Text(
                                          'Are you sure you want to cancel this ${isWeekend ? "weekend" : "general"} outing request ($leaveId)?',
                                          style: GoogleFonts.dmSans(
                                            color: _inkSoft,
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(dCtx).pop(false),
                                            child: Text(
                                              'Cancel',
                                              style: GoogleFonts.dmSans(
                                                color: _inkSoft,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(dCtx).pop(true),
                                            child: Text(
                                              'Delete',
                                              style: GoogleFonts.dmSans(
                                                color: _red,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirmed == true && modalCtx.mounted) {
                                      Navigator.of(modalCtx).pop();
                                      await _deleteOuting(leaveId, isWeekend);
                                    }
                                  },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _red,
                              side: BorderSide(color: _red, width: 1.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.delete_outline_rounded, size: 19),
                            label: Text(
                              'Delete Outing',
                              style: GoogleFonts.dmSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildModalSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: GoogleFonts.dmSans(
          fontSize: 13.5,
          fontWeight: FontWeight.w800,
          color: _inkSoft,
        ),
      ),
    );
  }

  Widget _buildModalDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _soft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 17, color: _navy),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.dmSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: _muted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pickerTheme(BuildContext context, Widget? child) {
    final isDark = _palette.isDark;
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: isDark
            ? ColorScheme.dark(
                primary: _blue,
                onPrimary: Colors.white,
                surface: _surface,
                onSurface: _ink,
              )
            : ColorScheme.light(
                primary: _navy,
                onPrimary: Colors.white,
                surface: _surface,
                onSurface: _ink,
              ),
      ),
      child: child!,
    );
  }
}
