import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../providers/auth_provider.dart';
import '../providers/vtop_providers.dart';
import '../services/api_client.dart';
import '../utils/download_helper.dart';

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

  // Controllers & Form State
  final _placeController = TextEditingController();
  final _purposeController = TextEditingController();
  final _contactController = TextEditingController();
  final _searchController = TextEditingController();

  // Weekend Time Slots
  final List<String> _weekendSlots = [
    '9:30 AM- 3:30PM',
    '10:30 AM- 4:30PM',
    '11:30 AM- 5:30PM',
    '12:30 PM- 6:30PM',
  ];
  String _selectedWeekendSlot = '9:30 AM- 3:30PM';

  // Schedule Dates & Times
  DateTime _outingDate = DateTime.now().add(const Duration(days: 1));
  DateTime _leavingDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _leavingTime = const TimeOfDay(hour: 9, minute: 30);
  DateTime _returningDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _returningTime = const TimeOfDay(hour: 18, minute: 30);

  bool _isSubmitting = false;

  late Future<dynamic> _generalOutingsFuture;
  late Future<dynamic> _weekendOutingsFuture;

  // Editorial campus palette
  static const _paper = Color(0xFFF4F2ED);
  static const _surface = Color(0xFFFFFEFB);
  static const _ink = Color(0xFF17202A);
  static const _inkSoft = Color(0xFF56616D);
  static const _navy = Color(0xFF172B4D);
  static const _blue = Color(0xFF356AE6);
  static const _orange = Color(0xFFE47543);
  static const _green = Color(0xFF278B68);
  static const _red = Color(0xFFC84C43);
  static const _muted = Color(0xFF6E7681);
  static const _line = Color(0xFFE2DED5);
  static const _soft = Color(0xFFEAE7DF);

  @override
  void initState() {
    super.initState();
    _loadOutings();
  }

  void _loadOutings() {
    final auth = ref.read(authProvider);
    _generalOutingsFuture = apiService.fetchGeneralOutings(
      username: auth.username ?? '',
      password: auth.password ?? '',
    );
    _weekendOutingsFuture = apiService.fetchWeekendOutings(
      username: auth.username ?? '',
      password: auth.password ?? '',
    );
  }

  List<Map<String, dynamic>> _extractRequests(dynamic data) {
    if (data == null) return [];
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList();
    }
    if (data is Map) {
      final reqs = data['requests'] ?? data['root'] ?? data['data'];
      if (reqs is List) {
        return reqs.whereType<Map<String, dynamic>>().toList();
      }
    }
    return [];
  }

  @override
  void dispose() {
    _placeController.dispose();
    _purposeController.dispose();
    _contactController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _submitOuting() async {
    final auth = ref.read(authProvider);
    final username = auth.username ?? '';
    final password = auth.password ?? '';

    final purpose = _purposeController.text.trim();
    if (purpose.isEmpty) {
      _showMessage('Please enter the purpose of visit.', color: _red);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      String message = '';

      if (_outingType == 'weekend') {
        final contact = _contactController.text.trim();
        if (contact.isEmpty) {
          _showMessage('Please enter parent / emergency contact number.', color: _red);
          setState(() => _isSubmitting = false);
          return;
        }

        final outDateStr = DateFormat('dd-MM-yyyy').format(_outingDate);
        message = await apiService.submitWeekendOuting(
          username: username,
          password: password,
          outPlace: _placeController.text.trim().isEmpty ? 'Vijayawada' : _placeController.text.trim(),
          purposeOfVisit: purpose,
          outingDate: outDateStr,
          outTime: _selectedWeekendSlot,
          contactNumber: contact,
        );
      } else {
        final place = _placeController.text.trim();
        if (place.isEmpty) {
          _showMessage('Please enter the place of visit.', color: _red);
          setState(() => _isSubmitting = false);
          return;
        }

        final outDateStr = DateFormat('dd-MM-yyyy').format(_leavingDate);
        final inDateStr = DateFormat('dd-MM-yyyy').format(_returningDate);
        final outTimeStr =
            '${_leavingTime.hour.toString().padLeft(2, '0')}:${_leavingTime.minute.toString().padLeft(2, '0')}';
        final inTimeStr =
            '${_returningTime.hour.toString().padLeft(2, '0')}:${_returningTime.minute.toString().padLeft(2, '0')}';

        message = await apiService.submitGeneralOuting(
          username: username,
          password: password,
          outPlace: place,
          purposeOfVisit: purpose,
          outingDate: outDateStr,
          outTime: outTimeStr,
          inDate: inDateStr,
          inTime: inTimeStr,
        );
      }

      if (!mounted) return;

      _showMessage(message, color: _green);

      _placeController.clear();
      _purposeController.clear();
      _contactController.clear();

      setState(() {
        _isSubmitting = false;
        _loadOutings();
        _showHistory = true; // Switch to history view to see the submitted outing
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showMessage('Submission Error: ${e.toString()}', color: _red);
    }
  }

  Future<void> _deleteOuting(String id, bool isWeekend) async {
    final auth = ref.read(authProvider);

    try {
      if (isWeekend) {
        await apiService.deleteWeekendOuting(
          username: auth.username ?? '',
          password: auth.password ?? '',
          bookingId: id,
        );
      } else {
        await apiService.deleteGeneralOuting(
          username: auth.username ?? '',
          password: auth.password ?? '',
          leaveId: id,
        );
      }

      if (!mounted) return;

      _showMessage('Outing request cancelled successfully.', color: _green);
      setState(_loadOutings);
    } catch (e) {
      if (!mounted) return;
      _showMessage('Failed: ${e.toString()}', color: _red);
    }
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
            fontSize: 12,
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
  // APPLY VIEW (Screenshots 1 & 2)
  // ============================================================
  Widget _buildApplyView() {
    final isWeekend = _outingType == 'weekend';

    return Column(
      children: [
        _buildApplyHeader(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
            children: [
              // Outing Type Toggle (Weekend | General)
              _buildSegmentedToggle(),

              const SizedBox(height: 22),

              if (isWeekend) ...[
                // Time Slot Section
                Text(
                  'Time slot',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _inkSoft,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _weekendSlots.map((slot) {
                    final isSelected = _selectedWeekendSlot == slot;
                    return InkWell(
                      onTap: () => setState(() => _selectedWeekendSlot = slot),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? _navy : _soft,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSelected) ...[
                              const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              slot,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 12.5,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected ? Colors.white : _ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 20),

                // Outing Date Field with Calendar
                _buildDatePickerCard(
                  label: 'Outing date',
                  value: DateFormat('dd/MM/yyyy').format(_outingDate),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _outingDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 60)),
                      builder: _pickerTheme,
                    );
                    if (picked != null) {
                      setState(() => _outingDate = picked);
                    }
                  },
                ),

                const SizedBox(height: 14),

                // Purpose of visit
                _buildPillTextField(
                  hint: 'Purpose of visit',
                  controller: _purposeController,
                ),

                const SizedBox(height: 14),

                // Contact number
                _buildPillTextField(
                  hint: 'Contact number',
                  controller: _contactController,
                  keyboardType: TextInputType.phone,
                ),
              ] else ...[
                // General Outing: Place of Visit
                _buildPillTextField(
                  hint: 'Place of visit',
                  controller: _placeController,
                ),

                const SizedBox(height: 14),

                // Purpose of visit
                _buildPillTextField(
                  hint: 'Purpose of visit',
                  controller: _purposeController,
                ),

                const SizedBox(height: 18),

                // Leaving Section
                Text(
                  'Leaving',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _inkSoft,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildPillPicker(
                        hint: 'Date',
                        value: DateFormat('dd/MM/yyyy').format(_leavingDate),
                        icon: Icons.calendar_today_outlined,
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _leavingDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 60)),
                            builder: _pickerTheme,
                          );
                          if (picked != null) {
                            setState(() {
                              _leavingDate = picked;
                              if (_returningDate.isBefore(picked)) _returningDate = picked;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildPillPicker(
                        hint: 'Time',
                        value: _leavingTime.format(context),
                        icon: Icons.access_time_rounded,
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: _leavingTime,
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
                Text(
                  'Returning',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _inkSoft,
                  ),
                ),
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
                            initialDate: _returningDate,
                            firstDate: _leavingDate,
                            lastDate: DateTime.now().add(const Duration(days: 60)),
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
                        value: _returningTime.format(context),
                        icon: Icons.access_time_rounded,
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: _returningTime,
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

              const SizedBox(height: 32),

              // Big Rounded Apply Button
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitOuting,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC7DEC9), // Soft green accent pill from screenshot
                    foregroundColor: const Color(0xFF132A15),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(27),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Color(0xFF132A15),
                          ),
                        )
                      : Text(
                          'Apply',
                          style: GoogleFonts.dmSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 14),

              // Secondary Pill Button: View outing history
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _showHistory = true),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _ink,
                    side: const BorderSide(color: _line, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
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

  Widget _buildApplyHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded, size: 24, color: _ink),
          ),
          const SizedBox(width: 8),
          Text(
            'Outing',
            style: GoogleFonts.dmSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedToggle() {
    return Container(
      height: 54,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: _soft,
        borderRadius: BorderRadius.circular(27),
      ),
      child: Row(
        children: [
          Expanded(
            child: _togglePill(
              title: 'Weekend',
              selected: _outingType == 'weekend',
              onTap: () => setState(() => _outingType = 'weekend'),
            ),
          ),
          Expanded(
            child: _togglePill(
              title: 'General',
              selected: _outingType == 'general',
              onTap: () => setState(() => _outingType = 'general'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _togglePill({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _surface : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          boxShadow: selected
              ? [
                  const BoxShadow(
                    color: Color(0x0C000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          title,
          style: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? _navy : _muted,
          ),
        ),
      ),
    );
  }

  Widget _buildPillTextField({
    required String hint,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: _soft,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.centerLeft,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: _soft,
          borderRadius: BorderRadius.circular(16),
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
            const Icon(Icons.calendar_today_outlined, size: 18, color: _inkSoft),
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: _soft,
          borderRadius: BorderRadius.circular(16),
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
  // HISTORY VIEW (Screenshot 3)
  // ============================================================
  Widget _buildHistoryView() {
    final isWeekend = _outingType == 'weekend';
    final historyTitle = isWeekend ? 'Weekend Outing History' : 'General Outing History';
    final future = isWeekend ? _weekendOutingsFuture : _generalOutingsFuture;

    return Column(
      children: [
        // Header with Back arrow
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _showHistory = false),
                icon: const Icon(Icons.arrow_back_rounded, size: 24, color: _ink),
              ),
              const SizedBox(width: 8),
              Text(
                historyTitle,
                style: GoogleFonts.dmSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => setState(_loadOutings),
                icon: const Icon(Icons.refresh_rounded, size: 22, color: _ink),
              ),
            ],
          ),
        ),

        // Search Bar with Filter Icon
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _line),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, size: 20, color: _muted),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) => setState(() {}),
                          style: GoogleFonts.dmSans(fontSize: 13.5, color: _ink),
                          decoration: InputDecoration(
                            hintText: 'Search outings...',
                            hintStyle: GoogleFonts.dmSans(fontSize: 13, color: _muted),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _line),
                ),
                child: IconButton(
                  onPressed: () {
                    // Toggle between weekend and general history
                    setState(() {
                      _outingType = _outingType == 'weekend' ? 'general' : 'weekend';
                    });
                  },
                  icon: const Icon(Icons.tune_rounded, size: 20, color: _navy),
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
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: _navy),
                  );
                }

                var requests = _extractRequests(snapshot.data);

                final query = _searchController.text.trim().toLowerCase();
                if (query.isNotEmpty) {
                  requests = requests.where((req) {
                    final place = (req['place_of_visit'] ?? req['out_place'] ?? '').toString().toLowerCase();
                    final purpose = (req['purpose_of_visit'] ?? req['reason'] ?? '').toString().toLowerCase();
                    return place.contains(query) || purpose.contains(query);
                  }).toList();
                }

                if (requests.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 80),
                      Center(
                        child: Column(
                          children: [
                            const Icon(Icons.event_busy_rounded, size: 40, color: _muted),
                            const SizedBox(height: 12),
                            Text(
                              'No outing records found.',
                              style: GoogleFonts.dmSans(fontSize: 13, color: _muted),
                            ),
                          ],
                        ),
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
                    return _buildModernOutingCard(req, isWeekend);
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // Card matching Screenshot 3
  Widget _buildModernOutingCard(Map<String, dynamic> req, bool isWeekend) {
    final status = req['status']?.toString() ??
        req['leave_status']?.toString() ??
        'Approved';

    final isApproved = status.toLowerCase().contains('app') || status.toLowerCase().contains('acc');
    final isPending = status.toLowerCase().contains('pend') || status.toLowerCase().contains('appl');

    final place = req['place_of_visit']?.toString() ??
        req['out_place']?.toString() ??
        req['place']?.toString() ??
        'Vijayawada';

    final purpose = req['purpose_of_visit']?.toString() ??
        req['reason']?.toString() ??
        'Outing';

    final outDate = req['from_date']?.toString() ??
        req['out_date']?.toString() ??
        req['date']?.toString() ??
        '23-08-2026';

    final outTime = req['from_time']?.toString() ??
        req['out_time']?.toString() ??
        req['time']?.toString() ??
        '9:30 AM- 3:30PM';

    final formattedDate = _formatCardDate(outDate);

    return InkWell(
      onTap: () => _openOutingDetailsModal(req, isWeekend),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _line),
          boxShadow: const [
            BoxShadow(
              color: Color(0x06000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Date Pill on left, Status Pill on right
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _soft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 12, color: _inkSoft),
                      const SizedBox(width: 5),
                      Text(
                        formattedDate,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                  decoration: BoxDecoration(
                    color: isApproved
                        ? const Color(0xFFE5F5E9)
                        : (isPending ? const Color(0xFFFEF4E8) : const Color(0xFFFDECE8)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isApproved ? _green : (isPending ? _orange : _red),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        status,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isApproved ? _green : (isPending ? _orange : _red),
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
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),

            const SizedBox(height: 2),

            // Purpose (Subtitle)
            Text(
              purpose,
              style: GoogleFonts.dmSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: _inkSoft,
              ),
            ),

            const SizedBox(height: 12),

            // Time Row
            Row(
              children: [
                const Icon(Icons.access_time_rounded, size: 14, color: _inkSoft),
                const SizedBox(width: 6),
                Text(
                  'Time  ',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _muted,
                  ),
                ),
                Text(
                  outTime,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Pass available Chip at bottom left
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _soft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.description_outlined, size: 12, color: _inkSoft),
                  const SizedBox(width: 5),
                  Text(
                    'Pass available',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _inkSoft,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 250.ms);
  }

  // ============================================================
  // OUTING DETAILS BOTTOM SHEET MODAL (Screenshot 4)
  // ============================================================
  void _openOutingDetailsModal(Map<String, dynamic> req, bool isWeekend) {
    final auth = ref.read(authProvider);
    final dash = ref.read(dashboardProvider);
    final profile = (dash.data?['profile'] as Map<String, dynamic>?) ?? {};

    final studentName = profile['student_name'] ?? auth.username ?? 'Student';
    final regNo = profile['application_number'] ?? auth.username ?? '';
    final hostelBlock = req['hostel_block']?.toString() ?? profile['hostel_block']?.toString() ?? 'MH-5';
    final roomNo = req['room_number']?.toString() ?? profile['room_number']?.toString() ?? '1102';

    final leaveId = req['leave_id']?.toString() ??
        req['appl_id']?.toString() ??
        req['booking_id']?.toString() ??
        req['id']?.toString() ??
        'W25401094831';

    final place = req['place_of_visit']?.toString() ??
        req['out_place']?.toString() ??
        req['place']?.toString() ??
        'Vijayawada';

    final purpose = req['purpose_of_visit']?.toString() ??
        req['reason']?.toString() ??
        'Movie';

    final outDate = req['from_date']?.toString() ??
        req['out_date']?.toString() ??
        req['date']?.toString() ??
        '23-08-2026';

    final outTime = req['from_time']?.toString() ??
        req['out_time']?.toString() ??
        req['time']?.toString() ??
        '9:30 AM- 3:30PM';

    final contactNo = req['contact_number']?.toString() ??
        profile['mobile_number']?.toString() ??
        '7780632515';

    final parentContact = req['parent_phone']?.toString() ??
        profile['parent_mobile_number']?.toString() ??
        '9849322913';

    final status = req['status']?.toString() ??
        req['leave_status']?.toString() ??
        'Approved';
    final isPending = status.toLowerCase().contains('pend') || status.toLowerCase().contains('appl');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Modal Drag Handle
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

                // Title
                Text(
                  'Outing Details',
                  style: GoogleFonts.dmSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 14),

                // Section 1: Outing Details
                _buildModalSectionTitle('Outing Details'),
                _buildModalDetailRow(Icons.location_on_outlined, 'Place of Visit', place),
                _buildModalDetailRow(Icons.description_outlined, 'Purpose', purpose),
                _buildModalDetailRow(Icons.person_outline_rounded, 'Registration Number', regNo),
                _buildModalDetailRow(Icons.receipt_long_outlined, 'Booking ID', leaveId),

                const SizedBox(height: 12),

                // Section 2: Accommodation
                _buildModalSectionTitle('Accommodation'),
                _buildModalDetailRow(Icons.apartment_rounded, 'Hostel Block', hostelBlock),
                _buildModalDetailRow(Icons.meeting_room_outlined, 'Room Number', roomNo),

                const SizedBox(height: 12),

                // Section 3: Schedule
                _buildModalSectionTitle('Schedule'),
                _buildModalDetailRow(Icons.calendar_today_outlined, 'Date', outDate),
                _buildModalDetailRow(Icons.access_time_rounded, 'Time', outTime),

                const SizedBox(height: 24),

                // Action 1: View PDF (Green filled button)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.of(modalCtx).pop();
                      final pdfBytes = await DownloadHelper.generateOfficialOutingPdfBytes(
                        studentName: studentName,
                        regNo: regNo,
                        outingType: isWeekend ? 'Weekend' : 'General',
                        placeOfVisit: place,
                        purpose: purpose,
                        dateTimeSlot: '$outDate & $outTime',
                        contactNumber: contactNo,
                        parentContactNumber: parentContact,
                        bookingId: leaveId,
                        hostelBlock: hostelBlock,
                        roomNo: roomNo,
                      );

                      if (!mounted) return;
                      final fileName = 'VITAP_Outing_$leaveId.pdf';
                      await DownloadHelper.saveFile(
                        context: context,
                        fileName: fileName,
                        content: pdfBytes,
                        mimeType: 'application/pdf',
                        openImmediately: true,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC7DEC9),
                      foregroundColor: const Color(0xFF132A15),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.description_outlined, size: 18),
                    label: Text(
                      'View PDF',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Action 2: Download PDF (Green outline button)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.of(modalCtx).pop();
                      final pdfBytes = await DownloadHelper.generateOfficialOutingPdfBytes(
                        studentName: studentName,
                        regNo: regNo,
                        outingType: isWeekend ? 'Weekend' : 'General',
                        placeOfVisit: place,
                        purpose: purpose,
                        dateTimeSlot: '$outDate & $outTime',
                        contactNumber: contactNo,
                        parentContactNumber: parentContact,
                        bookingId: leaveId,
                        hostelBlock: hostelBlock,
                        roomNo: roomNo,
                      );

                      if (!mounted) return;
                      final fileName = 'VITAP_Outing_Pass_$leaveId.pdf';
                      await DownloadHelper.saveFile(
                        context: context,
                        fileName: fileName,
                        content: pdfBytes,
                        mimeType: 'application/pdf',
                        openImmediately: false,
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _green,
                      side: const BorderSide(color: _green, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: Text(
                      'Download',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),

                if (isPending && leaveId.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.of(modalCtx).pop();
                        _deleteOuting(leaveId, isWeekend);
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFFCEDEA),
                        foregroundColor: _red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, size: 16),
                      label: Text(
                        'Cancel Outing Request',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModalSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.dmSans(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: _inkSoft,
        ),
      ),
    );
  }

  Widget _buildModalDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _soft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: _navy),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _muted,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.dmSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatCardDate(String rawDate) {
    try {
      final parsed = DateFormat('dd-MM-yyyy').parse(rawDate);
      return DateFormat('EEE, MMM d').format(parsed);
    } catch (_) {
      try {
        final parsed = DateFormat('yyyy-MM-dd').parse(rawDate);
        return DateFormat('EEE, MMM d').format(parsed);
      } catch (_) {
        return rawDate;
      }
    }
  }

  Widget _pickerTheme(BuildContext context, Widget? child) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: const ColorScheme.light(
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
