import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/error_formatter.dart';

class BiometricScreen extends ConsumerStatefulWidget {
  const BiometricScreen({super.key});

  @override
  ConsumerState<BiometricScreen> createState() => _BiometricScreenState();
}

class _BiometricScreenState extends ConsumerState<BiometricScreen> {
  DateTime _selectedDate = DateTime.now();
  late Future<List<dynamic>> _biometricFuture;

  AppPalette get _palette => AppPalette.of(context);
  Color get _paper => _palette.paper;
  Color get _surface => _palette.surface;
  Color get _ink => _palette.ink;
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
    _fetchBiometric();
  }

  void _fetchBiometric({bool forceRefresh = false}) {
    _biometricFuture = _getBiometricData(forceRefresh: forceRefresh);
  }

  Future<List<dynamic>> _getBiometricData({
    bool forceRefresh = false,
  }) async {
    final dateStr = DateFormat('dd/MM/yyyy').format(_selectedDate);
    final cacheKey = 'biometric_${DateFormat('yyyy-MM-dd').format(_selectedDate)}';

    if (!forceRefresh) {
      final mem = StorageService.getMemoryCache(cacheKey);
      if (mem is List && mem.isNotEmpty) {
        return List<dynamic>.from(mem);
      }

      final disk = await StorageService.getCache(cacheKey);
      if (disk is List && disk.isNotEmpty) {
        return List<dynamic>.from(disk);
      }
    }

    final auth = ref.read(authProvider);

    try {
      final fresh = await apiService.fetchBiometric(
        username: auth.username ?? '',
        password: auth.password ?? '',
        date: dateStr,
      );

      if (fresh.isNotEmpty) {
        await StorageService.setCache(cacheKey, fresh);
        return fresh;
      }
    } catch (e) {
      debugPrint(
        'BiometricScreen: Network fetch failed ($e). '
        'Checking offline cache...',
      );

      final fallback = StorageService.getMemoryCache(cacheKey) ??
          await StorageService.getCache(cacheKey);

      if (fallback is List && fallback.isNotEmpty) {
        return List<dynamic>.from(fallback);
      }

      rethrow;
    }

    final fallback = StorageService.getMemoryCache(cacheKey) ??
        await StorageService.getCache(cacheKey);

    if (fallback is List && fallback.isNotEmpty) {
      return List<dynamic>.from(fallback);
    }

    return [];
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _navy,
              onPrimary: Colors.white,
              surface: _surface,
              onSurface: _ink,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
        _fetchBiometric(forceRefresh: true);
      });
    }
  }

  bool _isEntry(String direction, String location, int index) {
    final normalizedDir = direction.trim().toUpperCase();
    if (normalizedDir == 'IN' || normalizedDir == 'ENTRY') return true;
    if (normalizedDir == 'OUT' || normalizedDir == 'EXIT') return false;

    final locUpper = location.toUpperCase();
    if (locUpper.contains('ENTRY') || locUpper.contains(' IN')) return true;
    if (locUpper.contains('EXIT') || locUpper.contains(' OUT')) return false;

    return index.isEven;
  }

  int _entryCount(List<dynamic> logs) {
    return logs.asMap().entries.where((entry) {
      final direction = entry.value['direction']?.toString() ?? '';
      final location = entry.value['location']?.toString() ??
          entry.value['punch_location']?.toString() ??
          '';
      return _isEntry(direction, location, entry.key);
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _paper,
      body: SafeArea(
        child: RefreshIndicator(
          color: _blue,
          backgroundColor: _surface,
          onRefresh: () async {
            setState(() => _fetchBiometric(forceRefresh: true));
            await _biometricFuture;
          },
          child: FutureBuilder<List<dynamic>>(
            future: _biometricFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoading();
              }

              if (snapshot.hasError) {
                return _buildError(snapshot.error!);
              }

              final logs = snapshot.data ?? [];

              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader()),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 2, 20, 30),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildDateCard(logs),
                        const SizedBox(height: 20),
                        if (logs.isNotEmpty) ...[
                          _buildSummary(logs),
                          const SizedBox(height: 24),
                          _buildSectionHeader(logs.length),
                          const SizedBox(height: 11),
                          ...logs.asMap().entries.map(
                                (entry) => Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 10),
                                  child: _buildPunchCard(
                                    entry.value,
                                    entry.key,
                                  ),
                                ),
                              ),
                        ] else
                          _buildEmpty(),
                      ]),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _line),
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                color: _navy,
                size: 19,
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ATTENDANCE',
                  style: GoogleFonts.spaceGrotesk(
                    color: _orange,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.05,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Biometric Punch Logs',
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
          InkWell(
            onTap: () => setState(() => _fetchBiometric(forceRefresh: true)),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _line),
              ),
              child: Icon(
                Icons.refresh_rounded,
                color: _navy,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateCard(List<dynamic> logs) {
    final dateLabel =
        DateFormat('EEE, dd MMM yyyy').format(_selectedDate);
    final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF0FD),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              Icons.calendar_month_rounded,
              color: _blue,
              size: 21,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isToday ? 'TODAY' : 'SELECTED DATE',
                  style: GoogleFonts.spaceGrotesk(
                    color: _muted,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .8,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  dateLabel,
                  style: GoogleFonts.dmSans(
                    color: _ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: _selectDate,
            icon: Icon(Icons.edit_calendar_rounded, size: 15),
            label: Text(
              'Change',
              style: GoogleFonts.dmSans(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: _navy,
              side: BorderSide(color: _line),
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 9,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(List<dynamic> logs) {
    final entries = _entryCount(logs);
    final exits = logs.length - entries;

    return Row(
      children: [
        Expanded(
          child: _summaryMetric(
            icon: Icons.fingerprint_rounded,
            label: 'TOTAL PUNCHES',
            value: logs.length.toString(),
            color: _blue,
            background: const Color(0xFFEAF0FD),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _summaryMetric(
            icon: Icons.login_rounded,
            label: 'ENTRIES',
            value: entries.toString(),
            color: _green,
            background: const Color(0xFFE8F4EF),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _summaryMetric(
            icon: Icons.logout_rounded,
            label: 'EXITS',
            value: exits.toString(),
            color: _orange,
            background: const Color(0xFFF9ECE7),
          ),
        ),
      ],
    );
  }

  Widget _summaryMetric({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Color background,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 11, 10, 12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 27,
            height: 27,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.dmSans(
              color: _ink,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.spaceGrotesk(
              color: _muted,
              fontSize: 6.8,
              fontWeight: FontWeight.w800,
              letterSpacing: .45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(int count) {
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
          child: Icon(
            Icons.history_rounded,
            color: _blue,
            size: 16,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            'PUNCH HISTORY',
            style: GoogleFonts.spaceGrotesk(
              color: _ink,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color: _soft,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            '$count LOGS',
            style: GoogleFonts.spaceGrotesk(
              color: _navy,
              fontSize: 7.5,
              fontWeight: FontWeight.w800,
              letterSpacing: .55,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPunchCard(dynamic log, int index) {
    final time = log['in_time']?.toString() ??
        log['punch_time']?.toString() ??
        log['time']?.toString() ??
        'Punch';
    final location = log['location']?.toString() ??
        log['punch_location']?.toString() ??
        'Turnstile Gate';
    final direction = log['direction']?.toString() ??
        (index.isEven ? 'IN' : 'OUT');

    final isEntry = _isEntry(direction, location, index);
    final color = isEntry ? _green : _orange;
    final background =
        isEntry ? const Color(0xFFE8F4EF) : const Color(0xFFF9ECE7);
    final icon =
        isEntry ? Icons.login_rounded : Icons.logout_rounded;

    return Container(
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
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 21,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  location,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    color: _ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      color: _muted,
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      time,
                      style: GoogleFonts.spaceGrotesk(
                        color: _muted,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 9,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              direction.toUpperCase(),
              style: GoogleFonts.spaceGrotesk(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: .55,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 34, 22, 36),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: _line),
      ),
      child: Column(
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: _soft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.fingerprint_rounded,
              size: 31,
              color: _muted,
            ),
          ),
          const SizedBox(height: 15),
          Text(
            'No Biometric Punches',
            style: GoogleFonts.dmSans(
              color: _ink,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'No activity was recorded for '
            '${DateFormat('dd MMM yyyy').format(_selectedDate)}.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              color: _muted,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: _blue,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Loading biometric logs...',
            style: GoogleFonts.dmSans(
              color: _muted,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(Object error) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * .75,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFCEDEA),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.error_outline_rounded,
                      color: _red,
                      size: 31,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to Load Biometric Logs',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      color: _ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    ErrorFormatter.format(
                      error,
                      fallback: 'Unable to load biometric attendance logs. Please check your connection.',
                    ),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      color: _muted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: () {
                      setState(() => _fetchBiometric(forceRefresh: true));
                    },
                    icon: Icon(Icons.refresh_rounded, size: 18),
                    label: Text(
                      'Try Again',
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _navy,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
