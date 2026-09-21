import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../providers/auth_provider.dart';
import '../services/api_client.dart';

class OutingsScreen extends ConsumerStatefulWidget {
  const OutingsScreen({super.key});

  @override
  ConsumerState<OutingsScreen> createState() => _OutingsScreenState();
}

class _OutingsScreenState extends ConsumerState<OutingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String _outingType = 'general';
  final _placeController = TextEditingController();
  final _purposeController = TextEditingController();
  final _contactController = TextEditingController();

  DateTime _outDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _outTime = const TimeOfDay(hour: 17, minute: 0);
  DateTime _inDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _inTime = const TimeOfDay(hour: 20, minute: 0);

  bool _isSubmitting = false;

  late Future<Map<String, dynamic>> _generalOutingsFuture;
  late Future<Map<String, dynamic>> _weekendOutingsFuture;

  // Editorial campus theme
  static const _paper = Color(0xFFF4F2ED);
  static const _surface = Color(0xFFFFFEFB);
  static const _ink = Color(0xFF17202A);
  static const _navy = Color(0xFF172B4D);
  static const _blue = Color(0xFF356AE6);
  static const _orange = Color(0xFFE47543);
  static const _green = Color(0xFF278B68);
  static const _red = Color(0xFFC84C43);
  static const _muted = Color(0xFF6E7681);
  static const _line = Color(0xFFE2DED5);
  static const _soft = Color(0xFFF0EEE8);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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

  @override
  void dispose() {
    _tabController.dispose();
    _placeController.dispose();
    _purposeController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _submitOuting() async {
    final auth = ref.read(authProvider);
    final username = auth.username ?? '';
    final password = auth.password ?? '';

    final place = _placeController.text.trim();
    final purpose = _purposeController.text.trim();

    if (place.isEmpty || purpose.isEmpty) {
      _showMessage('Please fill all required fields.', color: _red);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final outDateStr = DateFormat('dd-MM-yyyy').format(_outDate);
      final outTimeStr =
          '${_outTime.hour.toString().padLeft(2, '0')}:${_outTime.minute.toString().padLeft(2, '0')}';

      String message = '';

      if (_outingType == 'general') {
        final inDateStr = DateFormat('dd-MM-yyyy').format(_inDate);
        final inTimeStr =
            '${_inTime.hour.toString().padLeft(2, '0')}:${_inTime.minute.toString().padLeft(2, '0')}';

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
      } else {
        final contact = _contactController.text.trim();

        if (contact.isEmpty) {
          _showMessage(
            'Please provide contact number for weekend outing.',
            color: _red,
          );
          setState(() => _isSubmitting = false);
          return;
        }

        message = await apiService.submitWeekendOuting(
          username: username,
          password: password,
          outPlace: place,
          purposeOfVisit: purpose,
          outingDate: outDateStr,
          outTime: outTimeStr,
          contactNumber: contact,
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
      });

      _tabController.animateTo(0);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showMessage('Error: ${e.toString()}', color: _red);
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

      _showMessage(
        'Outing application cancelled successfully.',
        color: _green,
      );

      setState(() {
        _loadOutings();
      });
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
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
        child: Column(
          children: [
            _buildHeader(),
            _buildTabs(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildHistoryTab(),
                  _buildApplyTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 13),
      child: Row(
        children: [
          _iconButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CAMPUS ACCESS',
                  style: GoogleFonts.spaceGrotesk(
                    color: _orange,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Outings Portal',
                  style: GoogleFonts.dmSans(
                    color: _ink,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                  ),
                ),
              ],
            ),
          ),
          _iconButton(
            icon: Icons.refresh_rounded,
            onTap: () => setState(_loadOutings),
          ),
        ],
      ),
    );
  }

  Widget _iconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: _surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _line),
          ),
          child: Icon(icon, color: _navy, size: 19),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Container(
        height: 48,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: _soft,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: _line),
        ),
        child: TabBar(
          controller: _tabController,
          dividerColor: Colors.transparent,
          indicator: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _line),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: _navy,
          unselectedLabelColor: _muted,
          labelStyle: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
          unselectedLabelStyle: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(
              icon: Icon(Icons.history_rounded, size: 16),
              text: 'Outing History',
            ),
            Tab(
              icon: Icon(Icons.add_circle_outline_rounded, size: 16),
              text: 'Apply Outing',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonOutings() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _line),
      ),
      child: Column(
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: _blue,
            ),
          ),
          const SizedBox(height: 11),
          Text(
            'Loading outings...',
            style: GoogleFonts.dmSans(
              color: _muted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    return RefreshIndicator(
      color: _blue,
      backgroundColor: _surface,
      onRefresh: () async => setState(() => _loadOutings()),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
        children: [
          _buildHistoryHero(),
          const SizedBox(height: 20),
          _buildSectionHeading(
            'GENERAL OUTINGS',
            Icons.directions_walk_rounded,
          ),
          const SizedBox(height: 10),
          FutureBuilder<Map<String, dynamic>>(
            future: _generalOutingsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildSkeletonOutings();
              }

              final requests =
                  (snapshot.data?['requests'] as List<dynamic>?) ?? [];

              if (requests.isEmpty) {
                return _buildEmpty(
                  'No general outing records.',
                  Icons.event_busy_rounded,
                );
              }

              return Column(
                children: requests
                    .map((req) => _buildOutingCard(req, false))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 24),
          _buildSectionHeading(
            'WEEKEND OUTINGS',
            Icons.weekend_rounded,
          ),
          const SizedBox(height: 10),
          FutureBuilder<Map<String, dynamic>>(
            future: _weekendOutingsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildSkeletonOutings();
              }

              final requests =
                  (snapshot.data?['requests'] as List<dynamic>?) ?? [];

              if (requests.isEmpty) {
                return _buildEmpty(
                  'No weekend outing records.',
                  Icons.event_busy_rounded,
                );
              }

              return Column(
                children: requests
                    .map((req) => _buildOutingCard(req, true))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryHero() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: _navy,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF0FD),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.route_rounded,
              color: _blue,
              size: 23,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'OUTING APPLICATIONS',
                  style: GoogleFonts.spaceGrotesk(
                    color: const Color(0xFFAEBBD0),
                    fontSize: 7.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Track your campus exits',
                  style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Review status and manage your requests.',
                  style: GoogleFonts.dmSans(
                    color: const Color(0xFFC1CAD7),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeading(String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 31,
          height: 31,
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: _line),
          ),
          child: Icon(icon, color: _blue, size: 16),
        ),
        const SizedBox(width: 9),
        Text(
          title,
          style: GoogleFonts.spaceGrotesk(
            color: _ink,
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _line),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: _soft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _muted, size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              color: _muted,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutingCard(Map<String, dynamic> req, bool isWeekend) {
    final status = req['status']?.toString() ?? 'Pending';
    final isApproved = status.toLowerCase().contains('approved');
    final isPending = status.toLowerCase().contains('pending') ||
        status.toLowerCase().contains('applied');

    final leaveId = req['leave_id']?.toString() ??
        req['booking_id']?.toString() ??
        req['appl_id']?.toString() ??
        '';

    final statusColor = isApproved
        ? _green
        : (isPending ? _orange : _red);

    final statusBg = isApproved
        ? const Color(0xFFE8F4EF)
        : (isPending
            ? const Color(0xFFF9ECE7)
            : const Color(0xFFFCEDEA));

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0617202A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF0FD),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  isWeekend
                      ? Icons.weekend_rounded
                      : Icons.directions_walk_rounded,
                  color: _blue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  req['out_place'] ?? req['place'] ?? 'Outing',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    color: _ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  status,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                    letterSpacing: .35,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 9,
            ),
            decoration: BoxDecoration(
              color: _soft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.logout_rounded,
                  size: 14,
                  color: _orange,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Out: ${req['out_date'] ?? ''} ${req['out_time'] ?? ''}',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 9.5,
                      color: _ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (req['in_date'] != null) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.home_rounded,
                    size: 14,
                    color: _green,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'In: ${req['in_date'] ?? ''} ${req['in_time'] ?? ''}',
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 9.5,
                        color: _ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (req['purpose_of_visit'] != null ||
              req['reason'] != null) ...[
            const SizedBox(height: 10),
            Text(
              'PURPOSE',
              style: GoogleFonts.spaceGrotesk(
                color: _muted,
                fontSize: 7.5,
                fontWeight: FontWeight.w800,
                letterSpacing: .75,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${req['purpose_of_visit'] ?? req['reason'] ?? ''}',
              style: GoogleFonts.dmSans(
                fontSize: 11.5,
                color: _muted,
                height: 1.35,
              ),
            ),
          ],
          if (isPending && leaveId.isNotEmpty) ...[
            const SizedBox(height: 9),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _deleteOuting(leaveId, isWeekend),
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFFCEDEA),
                  foregroundColor: _red,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 14,
                ),
                label: Text(
                  'Cancel Request',
                  style: GoogleFonts.dmSans(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildApplyTab() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        _buildApplyHero(),
        const SizedBox(height: 20),
        _buildTypeSelector(),
        const SizedBox(height: 19),
        _buildTextField(
          label: 'PLACE OF VISIT',
          controller: _placeController,
          hint: 'e.g. Vijayawada, Guntur',
        ),
        const SizedBox(height: 14),
        _buildTextField(
          label: 'PURPOSE OF VISIT',
          controller: _purposeController,
          hint: 'e.g. Personal work, Family visit, Shopping',
        ),
        if (_outingType == 'weekend') ...[
          const SizedBox(height: 14),
          _buildTextField(
            label: 'EMERGENCY / CONTACT NUMBER',
            controller: _contactController,
            hint: 'e.g. 9876543210',
            keyboardType: TextInputType.phone,
          ),
        ],
        const SizedBox(height: 19),
        _buildDateTimeSection(
          title: 'OUTING TIME',
          dateLabel: 'Out Date',
          dateValue: DateFormat('dd MMM yyyy').format(_outDate),
          icon: Icons.calendar_today_rounded,
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _outDate,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 60)),
              builder: _pickerTheme,
            );
            if (picked != null) {
              setState(() => _outDate = picked);
            }
          },
          timeLabel: 'Out Time',
          timeValue: _outTime.format(context),
          onTimeTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: _outTime,
              builder: _pickerTheme,
            );
            if (picked != null) {
              setState(() => _outTime = picked);
            }
          },
        ),
        if (_outingType == 'general') ...[
          const SizedBox(height: 14),
          _buildDateTimeSection(
            title: 'RETURN TIME',
            dateLabel: 'In Date',
            dateValue: DateFormat('dd MMM yyyy').format(_inDate),
            icon: Icons.calendar_today_rounded,
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _inDate,
                firstDate: _outDate,
                lastDate: DateTime.now().add(const Duration(days: 60)),
                builder: _pickerTheme,
              );
              if (picked != null) {
                setState(() => _inDate = picked);
              }
            },
            timeLabel: 'In Time',
            timeValue: _inTime.format(context),
            onTimeTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: _inTime,
                builder: _pickerTheme,
              );
              if (picked != null) {
                setState(() => _inTime = picked);
              }
            },
          ),
        ],
        const SizedBox(height: 22),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submitOuting,
            style: ElevatedButton.styleFrom(
              backgroundColor: _navy,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _navy.withValues(alpha: .55),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Submit Outing Request',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildApplyHero() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: _navy,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF9ECE7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.add_location_alt_rounded,
              color: _orange,
              size: 22,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NEW APPLICATION',
                  style: GoogleFonts.spaceGrotesk(
                    color: const Color(0xFFAEBBD0),
                    fontSize: 7.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Plan your outing',
                  style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Enter your destination, purpose and timings.',
                  style: GoogleFonts.dmSans(
                    color: const Color(0xFFC1CAD7),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Row(
      children: [
        Expanded(
          child: _typeCard(
            title: 'General / Day',
            subtitle: 'Regular outing',
            icon: Icons.directions_walk_rounded,
            selected: _outingType == 'general',
            onTap: () => setState(() => _outingType = 'general'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _typeCard(
            title: 'Weekend',
            subtitle: 'Weekend outing',
            icon: Icons.weekend_rounded,
            selected: _outingType == 'weekend',
            onTap: () => setState(() => _outingType = 'weekend'),
          ),
        ),
      ],
    );
  }

  Widget _typeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: selected ? _navy : _surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected ? _navy : _line,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 35,
              height: 35,
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: .12)
                    : _soft,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                icon,
                size: 17,
                color: selected ? Colors.white : _blue,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.dmSans(
                      color: selected ? Colors.white : _ink,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.dmSans(
                      color: selected
                          ? const Color(0xFFC1CAD7)
                          : _muted,
                      fontSize: 8,
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

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            color: _ink,
            fontSize: 8.5,
            fontWeight: FontWeight.w800,
            letterSpacing: .85,
          ),
        ),
        const SizedBox(height: 7),
        Container(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _line),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: GoogleFonts.dmSans(
              color: _ink,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.dmSans(
                color: const Color(0xFF9AA1A9),
                fontSize: 12,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 13,
                vertical: 13,
              ),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateTimeSection({
    required String title,
    required String dateLabel,
    required String dateValue,
    required IconData icon,
    required VoidCallback onTap,
    required String timeLabel,
    required String timeValue,
    required VoidCallback onTimeTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.spaceGrotesk(
            color: _ink,
            fontSize: 8.5,
            fontWeight: FontWeight.w800,
            letterSpacing: .85,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildDateTimePicker(
                label: dateLabel,
                valueText: dateValue,
                icon: icon,
                onTap: onTap,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildDateTimePicker(
                label: timeLabel,
                valueText: timeValue,
                icon: Icons.access_time_rounded,
                onTap: onTimeTap,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDateTimePicker({
    required String label,
    required String valueText,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            color: _muted,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(11),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: _line),
            ),
            child: Row(
              children: [
                Icon(icon, size: 15, color: _blue),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    valueText,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      color: _ink,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
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
