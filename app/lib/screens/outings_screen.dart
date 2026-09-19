import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/mesh_ambient_background.dart';

class OutingsScreen extends ConsumerStatefulWidget {
  const OutingsScreen({super.key});

  @override
  ConsumerState<OutingsScreen> createState() => _OutingsScreenState();
}

class _OutingsScreenState extends ConsumerState<OutingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Form state
  String _outingType = 'general'; // 'general' or 'weekend'
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final outDateStr = DateFormat('dd-MM-yyyy').format(_outDate);
      final outTimeStr = '${_outTime.hour.toString().padLeft(2, '0')}:${_outTime.minute.toString().padLeft(2, '0')}';

      String message = '';
      if (_outingType == 'general') {
        final inDateStr = DateFormat('dd-MM-yyyy').format(_inDate);
        final inTimeStr = '${_inTime.hour.toString().padLeft(2, '0')}:${_inTime.minute.toString().padLeft(2, '0')}';

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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please provide contact number for weekend outing.')),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF10B981),
          content: Text(message, style: GoogleFonts.inter(color: Colors.white)),
        ),
      );

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.error,
          content: Text('Error: ${e.toString()}', style: GoogleFonts.inter(color: Colors.white)),
        ),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Outing application cancelled successfully.')),
      );
      setState(() {
        _loadOutings();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppTheme.error, content: Text('Failed: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Outings Portal', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryAccent,
          labelColor: AppTheme.primaryAccent,
          unselectedLabelColor: const Color(0xFF94A3B8),
          tabs: const [
            Tab(icon: Icon(Icons.history_rounded, size: 18), text: 'Outing History'),
            Tab(icon: Icon(Icons.add_circle_outline_rounded, size: 18), text: 'Apply Outing'),
          ],
        ),
      ),
      body: MeshAmbientBackground(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildHistoryTab(),
            _buildApplyTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonOutings() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          SizedBox(height: 12),
          Text('Loading outings...', style: TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }

  // ─── History Tab ──────────────────────────────────────────────────────────
  Widget _buildHistoryTab() {
    return RefreshIndicator(
      onRefresh: () async => setState(() => _loadOutings()),
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text('General Outings', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 10),
          FutureBuilder<Map<String, dynamic>>(
            future: _generalOutingsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildSkeletonOutings();
              }
              final requests = (snapshot.data?['requests'] as List<dynamic>?) ?? [];
              if (requests.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(14)),
                  child: const Center(child: Text('No general outing records.', style: TextStyle(color: Colors.white60))),
                );
              }
              return Column(
                children: requests.map((req) => _buildOutingCard(req, false)).toList(),
              );
            },
          ),
          const SizedBox(height: 24),
          Text('Weekend Outings', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 10),
          FutureBuilder<Map<String, dynamic>>(
            future: _weekendOutingsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildSkeletonOutings();
              }
              final requests = (snapshot.data?['requests'] as List<dynamic>?) ?? [];
              if (requests.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(14)),
                  child: const Center(child: Text('No weekend outing records.', style: TextStyle(color: Colors.white60))),
                );
              }
              return Column(
                children: requests.map((req) => _buildOutingCard(req, true)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOutingCard(Map<String, dynamic> req, bool isWeekend) {
    final status = req['status']?.toString() ?? 'Pending';
    final isApproved = status.toLowerCase().contains('approved');
    final isPending = status.toLowerCase().contains('pending') || status.toLowerCase().contains('applied');
    final leaveId = req['leave_id']?.toString() ?? req['booking_id']?.toString() ?? req['appl_id']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                req['out_place'] ?? req['place'] ?? 'Outing',
                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isApproved
                      ? const Color(0xFF10B981).withValues(alpha: 0.2)
                      : (isPending ? const Color(0xFFF59E0B).withValues(alpha: 0.2) : AppTheme.error.withValues(alpha: 0.2)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isApproved ? const Color(0xFF10B981) : (isPending ? const Color(0xFFF59E0B) : AppTheme.error),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded, size: 13, color: AppTheme.primaryAccent),
              const SizedBox(width: 6),
              Text(
                'Out: ${req['out_date'] ?? ''} ${req['out_time'] ?? ''}',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
              ),
              if (req['in_date'] != null) ...[
                const SizedBox(width: 12),
                const Icon(Icons.home_rounded, size: 13, color: AppTheme.cyanAccent),
                const SizedBox(width: 6),
                Text(
                  'In: ${req['in_date'] ?? ''} ${req['in_time'] ?? ''}',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                ),
              ],
            ],
          ),
          if (req['purpose_of_visit'] != null || req['reason'] != null) ...[
            const SizedBox(height: 6),
            Text(
              'Purpose: ${req['purpose_of_visit'] ?? req['reason'] ?? ''}',
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
            ),
          ],
          if (isPending && leaveId.isNotEmpty) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _deleteOuting(leaveId, isWeekend),
                icon: const Icon(Icons.delete_outline_rounded, size: 14, color: AppTheme.error),
                label: Text('Cancel Request', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.error)),
              ),
            ),
          ],
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 350.ms)
        .slideY(begin: 0.05, end: 0);
  }

  // ─── Apply Tab ────────────────────────────────────────────────────────────
  Widget _buildApplyTab() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        // Outing Type Selector
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: const Text('General / Day Outing'),
                selected: _outingType == 'general',
                selectedColor: AppTheme.primary,
                backgroundColor: AppTheme.surface,
                onSelected: (val) => setState(() => _outingType = 'general'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ChoiceChip(
                label: const Text('Weekend Outing'),
                selected: _outingType == 'weekend',
                selectedColor: AppTheme.primary,
                backgroundColor: AppTheme.surface,
                onSelected: (val) => setState(() => _outingType = 'weekend'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Place of Visit
        _buildTextField(label: 'Place of Visit (Destination)', controller: _placeController, hint: 'e.g., Vijayawada, Guntur'),
        const SizedBox(height: 14),

        // Purpose of Visit
        _buildTextField(label: 'Purpose of Visit', controller: _purposeController, hint: 'e.g., Personal work, Family visit, Shopping'),
        const SizedBox(height: 14),

        if (_outingType == 'weekend') ...[
          _buildTextField(label: 'Emergency / Contact Number', controller: _contactController, hint: 'e.g., 9876543210', keyboardType: TextInputType.phone),
          const SizedBox(height: 14),
        ],

        // Out Date & Time
        Row(
          children: [
            Expanded(
              child: _buildDateTimePicker(
                label: 'Out Date',
                valueText: DateFormat('dd MMM yyyy').format(_outDate),
                icon: Icons.calendar_today_rounded,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _outDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 60)),
                  );
                  if (picked != null) setState(() => _outDate = picked);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildDateTimePicker(
                label: 'Out Time',
                valueText: _outTime.format(context),
                icon: Icons.access_time_rounded,
                onTap: () async {
                  final picked = await showTimePicker(context: context, initialTime: _outTime);
                  if (picked != null) setState(() => _outTime = picked);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        if (_outingType == 'general') ...[
          // In Date & Time
          Row(
            children: [
              Expanded(
                child: _buildDateTimePicker(
                  label: 'In Date',
                  valueText: DateFormat('dd MMM yyyy').format(_inDate),
                  icon: Icons.calendar_today_rounded,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _inDate,
                      firstDate: _outDate,
                      lastDate: DateTime.now().add(const Duration(days: 60)),
                    );
                    if (picked != null) setState(() => _inDate = picked);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildDateTimePicker(
                  label: 'In Time',
                  valueText: _inTime.format(context),
                  icon: Icons.access_time_rounded,
                  onTap: () async {
                    final picked = await showTimePicker(context: context, initialTime: _inTime);
                    if (picked != null) setState(() => _inTime = picked);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],

        // Submit Button
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submitOuting,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _isSubmitting
                ? const CircularProgressIndicator(color: Colors.white)
                : Text('Submit Outing Request', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ),
      ],
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
        Text(label, style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white70)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF24344D)),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 13),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: InputBorder.none,
            ),
          ),
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
        Text(label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF24344D)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 16, color: AppTheme.primaryAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    valueText,
                    style: GoogleFonts.inter(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
