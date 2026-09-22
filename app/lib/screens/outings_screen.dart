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

class _OutingsScreenState extends ConsumerState<OutingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String _outingType = 'general'; // 'general' or 'weekend'
  final _placeController = TextEditingController();
  final _purposeController = TextEditingController();
  final _contactController = TextEditingController();
  final _remarksController = TextEditingController();
  String _selectedModeOfTravel = 'Bus';

  DateTime _outDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _outTime = const TimeOfDay(hour: 16, minute: 30);
  DateTime _inDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _inTime = const TimeOfDay(hour: 20, minute: 0);

  bool _isSubmitting = false;

  late Future<dynamic> _generalOutingsFuture;
  late Future<dynamic> _weekendOutingsFuture;

  // Editorial campus theme
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
  static const _soft = Color(0xFFF0EEE8);

  final List<String> _commonPlaces = [
    'Vijayawada',
    'Guntur',
    'Amaravati',
    'Tadepalli',
    'Mangalagiri',
    'Home',
  ];

  final List<String> _commonPurposes = [
    'Shopping',
    'Medical / Doctor',
    'Family Visit',
    'Personal Work',
    'Project Work',
    'Home Visit',
  ];

  final List<String> _travelModes = [
    'Bus',
    'Auto',
    'Train',
    'Cab / Taxi',
    'Personal Vehicle',
  ];

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
    _tabController.dispose();
    _placeController.dispose();
    _purposeController.dispose();
    _contactController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _submitOuting() async {
    final auth = ref.read(authProvider);
    final username = auth.username ?? '';
    final password = auth.password ?? '';

    final place = _placeController.text.trim();
    final purpose = _purposeController.text.trim();

    if (place.isEmpty || purpose.isEmpty) {
      _showMessage('Please enter both Place and Purpose of visit.', color: _red);
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
            'Please provide parent / emergency contact number.',
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
      _remarksController.clear();

      setState(() {
        _isSubmitting = false;
        _loadOutings();
      });

      _tabController.animateTo(0);
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

      _showMessage(
        'Outing request cancelled successfully.',
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

  Future<void> _downloadGatePass(Map<String, dynamic> req, bool isWeekend) async {
    final auth = ref.read(authProvider);
    final dash = ref.read(dashboardProvider);
    final profile = (dash.data?['profile'] as Map<String, dynamic>?) ?? {};

    final studentName = profile['student_name'] ?? auth.username ?? 'Student';
    final regNo = auth.username ?? '';
    final leaveId = req['leave_id']?.toString() ??
        req['appl_id']?.toString() ??
        req['id']?.toString() ??
        'OUT-${DateTime.now().millisecondsSinceEpoch % 100000}';
    final place = req['place_of_visit']?.toString() ??
        req['out_place']?.toString() ??
        'Outing';
    final purpose = req['purpose_of_visit']?.toString() ??
        req['reason']?.toString() ??
        'General';
    final outDate = req['from_date']?.toString() ??
        req['out_date']?.toString() ??
        '';
    final outTime = req['from_time']?.toString() ??
        req['out_time']?.toString() ??
        '';
    final inDate = req['to_date']?.toString() ??
        req['in_date']?.toString() ??
        '';
    final inTime = req['to_time']?.toString() ??
        req['in_time']?.toString() ??
        '';
    final contact = req['contact_number']?.toString() ??
        req['contact_no']?.toString() ??
        profile['mobile_no']?.toString() ??
        'N/A';
    final status = req['status']?.toString() ??
        (req['leave_status']?.toString() ?? 'Approved');

    final html = DownloadHelper.generateOutingPassHtml(
      studentName: studentName,
      regNo: regNo,
      outingType: isWeekend ? 'Weekend Leave' : 'General Day Outing',
      placeOfVisit: place,
      purpose: purpose,
      outDateTime: '$outDate $outTime'.trim(),
      inDateTime: '$inDate $inTime'.trim(),
      contactNumber: contact,
      status: status,
      leaveId: leaveId,
    );

    await DownloadHelper.saveFile(
      context: context,
      fileName: 'VITAP_Outing_Pass_$leaveId.html',
      content: html,
      mimeType: 'text/html',
    );
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
          FutureBuilder<dynamic>(
            future: _generalOutingsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildSkeletonOutings();
              }

              final requests = _extractRequests(snapshot.data);

              if (requests.isEmpty) {
                return _buildEmpty(
                  'No general outing records found.',
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
          FutureBuilder<dynamic>(
            future: _weekendOutingsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildSkeletonOutings();
              }

              final requests = _extractRequests(snapshot.data);

              if (requests.isEmpty) {
                return _buildEmpty(
                  'No weekend outing records found.',
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
              color: const Color(0xFFF9ECE7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.shield_outlined,
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
                  'DIGITAL GATE PASS',
                  style: GoogleFonts.spaceGrotesk(
                    color: const Color(0xFFAEBBD0),
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .8,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Hostel Outings & Leave',
                  style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'View approved gate passes and download slips directly.',
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

  Widget _buildOutingCard(Map<String, dynamic> req, bool isWeekend) {
    final status = req['status']?.toString() ??
        req['leave_status']?.toString() ??
        'Approved';

    final isApproved = status.toLowerCase().contains('approved') ||
        status.toLowerCase().contains('accepted');
    final isPending = status.toLowerCase().contains('pending') ||
        status.toLowerCase().contains('applied') ||
        status.toLowerCase().contains('submitted');

    final leaveId = req['leave_id']?.toString() ??
        req['appl_id']?.toString() ??
        req['booking_id']?.toString() ??
        req['id']?.toString() ??
        '';

    final place = req['place_of_visit']?.toString() ??
        req['out_place']?.toString() ??
        req['place']?.toString() ??
        'Campus Outing';

    final outDate = req['from_date']?.toString() ??
        req['out_date']?.toString() ??
        req['date']?.toString() ??
        '';

    final outTime = req['from_time']?.toString() ??
        req['out_time']?.toString() ??
        req['time']?.toString() ??
        '';

    final inDate = req['to_date']?.toString() ??
        req['in_date']?.toString();

    final inTime = req['to_time']?.toString() ??
        req['in_time']?.toString();

    final purpose = req['purpose_of_visit']?.toString() ??
        req['reason']?.toString() ??
        '';

    final hostel = req['hostel_block']?.toString();
    final room = req['room_number']?.toString();

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        color: _ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (hostel != null && hostel.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Block: $hostel ${room != null && room.isNotEmpty ? '• Room $room' : ''}',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 8.5,
                          color: _muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
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
          const SizedBox(height: 12),
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
                    'Out: $outDate $outTime'.trim(),
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 9.5,
                      color: _ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (inDate != null && inDate.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.home_rounded,
                    size: 14,
                    color: _green,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'In: $inDate ${inTime ?? ''}'.trim(),
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
          if (purpose.isNotEmpty) ...[
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
              purpose,
              style: GoogleFonts.dmSans(
                fontSize: 11.5,
                color: _muted,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 10),
          // Actions Row: Download Gate Pass + Cancel Request
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Download Gate Pass button
              TextButton.icon(
                onPressed: () => _downloadGatePass(req, isWeekend),
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFEAF0FD),
                  foregroundColor: _blue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(
                  Icons.download_rounded,
                  size: 14,
                ),
                label: Text(
                  'Download Pass',
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (isPending && leaveId.isNotEmpty) ...[
                const SizedBox(width: 8),
                TextButton.icon(
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
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  // ============================================================
  // REAL VTOP APPLY OUTING FORM
  // ============================================================
  Widget _buildApplyTab() {
    final dash = ref.watch(dashboardProvider);
    final auth = ref.watch(authProvider);
    final profile = (dash.data?['profile'] as Map<String, dynamic>?) ?? {};
    final studentName = profile['student_name'] ?? auth.username ?? 'Student';
    final regNo = profile['application_number'] ?? auth.username ?? '';
    final hostelBlock = profile['hostel_block'] ?? profile['block'] ?? 'Campus Hostel';
    final roomNo = profile['room_number'] ?? profile['room_no'] ?? '';

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        // 1. Student Credentials Card (Real VTOP Data)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _line),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _navy.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.badge_outlined, color: _navy, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      studentName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$regNo  •  $hostelBlock ${roomNo.isNotEmpty ? "• Rm $roomNo" : ""}',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 2. Outing Category Selector
        _buildTypeSelector(),

        const SizedBox(height: 18),

        // 3. Place of Visit with quick-select chips
        _buildTextField(
          label: 'PLACE OF VISIT',
          controller: _placeController,
          hint: 'e.g. Vijayawada, Guntur, Home',
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _commonPlaces.map((place) {
            final isSelected = _placeController.text.trim() == place;
            return InkWell(
              onTap: () {
                setState(() => _placeController.text = place);
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                decoration: BoxDecoration(
                  color: isSelected ? _navy : _soft,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isSelected ? _navy : _line),
                ),
                child: Text(
                  place,
                  style: GoogleFonts.dmSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : _inkSoft,
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 16),

        // 4. Purpose of Visit with quick-select chips
        _buildTextField(
          label: 'PURPOSE OF OUTING',
          controller: _purposeController,
          hint: 'e.g. Shopping, Doctor Consultation, Family Visit',
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _commonPurposes.map((purpose) {
            final isSelected = _purposeController.text.trim() == purpose;
            return InkWell(
              onTap: () {
                setState(() => _purposeController.text = purpose);
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                decoration: BoxDecoration(
                  color: isSelected ? _navy : _soft,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isSelected ? _navy : _line),
                ),
                child: Text(
                  purpose,
                  style: GoogleFonts.dmSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : _inkSoft,
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 16),

        // 5. Mode of Travel
        Text(
          'MODE OF TRAVEL',
          style: GoogleFonts.spaceGrotesk(
            color: _ink,
            fontSize: 8.5,
            fontWeight: FontWeight.w800,
            letterSpacing: .85,
          ),
        ),
        const SizedBox(height: 7),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _travelModes.map((mode) {
            final isSelected = _selectedModeOfTravel == mode;
            return InkWell(
              onTap: () => setState(() => _selectedModeOfTravel = mode),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isSelected ? _blue : _surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isSelected ? _blue : _line),
                ),
                child: Text(
                  mode,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : _ink,
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 16),

        // 6. Contact Number (Required for Weekend, Optional for General)
        _buildTextField(
          label: _outingType == 'weekend'
              ? 'PARENT / EMERGENCY MOBILE NUMBER (REQUIRED)'
              : 'CONTACT NUMBER (OPTIONAL)',
          controller: _contactController,
          hint: 'e.g. 9876543210',
          keyboardType: TextInputType.phone,
        ),

        const SizedBox(height: 18),

        // 7. Outing Date & Time
        _buildDateTimeSection(
          title: 'DEPARTURE SCHEDULE',
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
              setState(() {
                _outDate = picked;
                if (_inDate.isBefore(_outDate)) _inDate = picked;
              });
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
            title: 'RETURN SCHEDULE (SAME DAY)',
            dateLabel: 'Return Date',
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
            timeLabel: 'Return Time',
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

        const SizedBox(height: 24),

        // 8. Submit Outing Button
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
                borderRadius: BorderRadius.circular(14),
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
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeSelector() {
    return Row(
      children: [
        Expanded(
          child: _typeCard(
            title: 'General Outing',
            subtitle: 'Day visit (Return today)',
            icon: Icons.directions_walk_rounded,
            selected: _outingType == 'general',
            onTap: () => setState(() => _outingType = 'general'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _typeCard(
            title: 'Weekend Outing',
            subtitle: 'Night leave / Overnight',
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
        padding: const EdgeInsets.all(12),
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
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: .12)
                    : _soft,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                icon,
                size: 18,
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
                      fontSize: 11,
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
                      fontSize: 8.5,
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
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.dmSans(
                color: _muted,
                fontSize: 11.5,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 13,
                vertical: 12,
              ),
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
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.spaceGrotesk(
              color: _orange,
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              letterSpacing: .85,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _pickButton(
                  label: dateLabel,
                  value: dateValue,
                  icon: icon,
                  onTap: onTap,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _pickButton(
                  label: timeLabel,
                  value: timeValue,
                  icon: Icons.access_time_rounded,
                  onTap: onTimeTap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pickButton({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: _soft,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _line),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: _navy),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.dmSans(
                      color: _muted,
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    value,
                    style: GoogleFonts.spaceGrotesk(
                      color: _ink,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
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

  Widget _buildSectionHeading(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 15, color: _navy),
        const SizedBox(width: 7),
        Text(
          title,
          style: GoogleFonts.spaceGrotesk(
            color: _ink,
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: .9,
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty(String message, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _line),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(icon, color: _muted, size: 28),
            const SizedBox(height: 8),
            Text(
              message,
              style: GoogleFonts.dmSans(color: _muted, fontSize: 11.5),
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
}
