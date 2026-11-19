import 'package:flutter/material.dart';
import '../widgets/nexus_app_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/error_formatter.dart';
import '../widgets/shadcn/shadcn_ui.dart';
import '../widgets/motion/nexus_motion.dart';

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
  Color get _muted => _palette.inkMuted;
  Color get _line => _palette.line;
  Color get _navy => _palette.navy;
  Color get _orange => _palette.orange;
  Color get _green => _palette.green;
  Color get _soft => _palette.soft;

  @override
  void initState() {
    super.initState();
    _fetchBiometric();
  }

  void _fetchBiometric({bool forceRefresh = false}) {
    _biometricFuture = _getBiometricData(forceRefresh: forceRefresh);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<List<dynamic>> _getBiometricData({bool forceRefresh = false}) async {
    final auth = ref.read(authProvider);
    final user = auth.username ?? StorageService.currentUsername;
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final vtopDateStr = DateFormat('dd/MM/yyyy').format(_selectedDate);
    final cacheKey = 'biometric_$dateStr';
    final isToday = _isSameDay(_selectedDate, DateTime.now());

    if (!forceRefresh) {
      final mem = StorageService.getMemoryCache(cacheKey, username: user) ??
          (isToday ? StorageService.getMemoryCache('biometric', username: user) : null);
      if (mem is List && mem.isNotEmpty) {
        return List<dynamic>.from(mem);
      }
      final disk = await StorageService.getCache(cacheKey, username: user) ??
          (isToday ? await StorageService.getCache('biometric', username: user) : null);
      if (disk is List && disk.isNotEmpty) {
        return List<dynamic>.from(disk);
      }
    }

    try {
      final fresh = await apiService.fetchBiometric(
        username: auth.username ?? '',
        password: auth.password ?? '',
        date: vtopDateStr,
      );
      await StorageService.setCache(cacheKey, fresh, username: user);
      if (isToday) {
        await StorageService.setCache('biometric', fresh, username: user);
      }
      return fresh;
    } catch (e) {
      debugPrint('BiometricScreen: Network fetch failed ($e). Checking offline cache...');
      final fallback = StorageService.getMemoryCache(cacheKey, username: user) ??
          await StorageService.getCache(cacheKey, username: user) ??
          (isToday
              ? (StorageService.getMemoryCache('biometric', username: user) ??
                  await StorageService.getCache('biometric', username: user))
              : null);
      if (fallback is List && fallback.isNotEmpty) {
        return List<dynamic>.from(fallback);
      }
      rethrow;
    }
  }

  void _shiftDate(int days) {
    final target = _selectedDate.add(Duration(days: days));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDay = DateTime(target.year, target.month, target.day);
    if (targetDay.isAfter(today)) return;
    setState(() {
      _selectedDate = target;
      _fetchBiometric(forceRefresh: false);
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 180)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: _navy,
              brightness: _palette.isDark ? Brightness.dark : Brightness.light,
              surface: _surface,
              onSurface: _ink,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && !_isSameDay(picked, _selectedDate)) {
      setState(() {
        _selectedDate = picked;
        _fetchBiometric(forceRefresh: true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isToday = _isSameDay(_selectedDate, DateTime.now());

    return Scaffold(
      backgroundColor: _paper,
      appBar: NexusAppBar(
        title: 'Biometric',
        subtitle: 'Campus entry and exit logs',
        actions: [
          if (!isToday)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _selectedDate = DateTime.now();
                    _fetchBiometric(forceRefresh: false);
                  });
                },
                style: TextButton.styleFrom(
                  backgroundColor: _orange.withValues(alpha: 0.12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'TODAY',
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: _orange,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
          IconButton(
              tooltip: 'Refresh Logs',
              icon: Icon(Icons.refresh_rounded, color: _navy, size: 20),
              onPressed: () {
                setState(() => _fetchBiometric(forceRefresh: true));
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Date Selector Strip with Prev / Next / Calendar Picker
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _soft,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Previous Day',
                    onPressed: () => _shiftDate(-1),
                    icon: Icon(Icons.chevron_left_rounded, color: _ink, size: 22),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: _navy.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.calendar_today_rounded,
                                color: _navy,
                                size: 17,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${DateFormat('EEEE').format(_selectedDate).toUpperCase()}${isToday ? ' • TODAY' : ''}',
                                    style: GoogleFonts.bricolageGrotesque(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: _orange,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    DateFormat('dd MMMM yyyy').format(_selectedDate),
                                    style: GoogleFonts.dmSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: _ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: _soft,
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(color: _line),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.edit_calendar_rounded, size: 13, color: _ink),
                                  const SizedBox(width: 5),
                                  Text(
                                    'PICK',
                                    style: GoogleFonts.bricolageGrotesque(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.6,
                                      color: _ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Next Day',
                    onPressed: isToday ? null : () => _shiftDate(1),
                    icon: Icon(
                      Icons.chevron_right_rounded,
                      color: isToday ? _muted.withValues(alpha: 0.35) : _ink,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                setState(() => _fetchBiometric(forceRefresh: true));
                await _biometricFuture;
              },
              color: _navy,
              backgroundColor: _surface,
              child: FutureBuilder<List<dynamic>>(
                future: _biometricFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildLoadingState();
                  }

                  if (snapshot.hasError) {
                    return _buildErrorState(snapshot.error);
                  }

                  final logs = snapshot.data ?? [];
                  if (logs.isEmpty) {
                    return _buildEmptyState();
                  }

                  final firstLog = logs.first as Map<String, dynamic>;
                  final lastLog = logs.last as Map<String, dynamic>;
                  final firstTime = (firstLog['in_time'] ?? firstLog['punch_time'] ?? firstLog['time'] ?? '--').toString();
                  final lastTime = (lastLog['in_time'] ?? lastLog['punch_time'] ?? lastLog['time'] ?? '--').toString();

                  return ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                    itemCount: logs.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  HSLColor.fromColor(_navy).withLightness(HSLColor.fromColor(_navy).lightness.clamp(0.0, 0.42)).toColor(),
                                  Color.lerp(HSLColor.fromColor(_navy).withLightness(HSLColor.fromColor(_navy).lightness.clamp(0.0, 0.42)).toColor(), const Color(0xFF16102E), 0.72)!,
                                ],
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildSummaryStat('PUNCHES', '${logs.length}', Colors.white),
                                Container(width: 1, height: 34, color: Colors.white24),
                                _buildSummaryStat('FIRST', firstTime, Colors.white),
                                Container(width: 1, height: 34, color: Colors.white24),
                                _buildSummaryStat('LATEST', lastTime, Colors.white),
                              ],
                            ),
                          ),
                        );
                      }

                      final logIdx = index - 1;
                      final log = logs[logIdx] as Map<String, dynamic>;
                      final time = (log['in_time'] ?? log['punch_time'] ?? log['time'] ?? 'Recorded').toString();
                      final outTime = (log['out_time'] ?? '').toString().trim();
                      final location = (log['punch_location'] ?? log['location'] ?? 'Campus Gate').toString();
                      final logDate = (log['date'] ?? DateFormat('dd/MM/yyyy').format(_selectedDate)).toString();
                      final serial = (log['serial'] ?? '${logIdx + 1}').toString();
                      final rawDir = log['direction']?.toString().toUpperCase() ?? '';
                      final isEntry = rawDir.isNotEmpty
                          ? rawDir == 'IN'
                          : (location.toUpperCase().contains('OUT') ? false : logIdx % 2 == 0);

                      final accentColor = isEntry ? _green : _orange;

                      return AnimeStaggerItem(
                        index: logIdx,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: NexusCard(
                            variant: NexusCardVariant.standard,
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: accentColor.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Icon(
                                    Icons.fingerprint_rounded,
                                    color: accentColor,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        location,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.bricolageGrotesque(
                                          fontSize: 16.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.2,
                                          color: _ink,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 10,
                                        runSpacing: 4,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.schedule_rounded, size: 13, color: _navy),
                                              const SizedBox(width: 4),
                                              Text(
                                                outTime.isNotEmpty ? '$time - $outTime' : time,
                                                style: GoogleFonts.bricolageGrotesque(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: _ink,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            '•  $logDate',
                                            style: GoogleFonts.dmSans(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              color: _muted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: accentColor.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    '#$serial',
                                    style: GoogleFonts.bricolageGrotesque(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                      color: accentColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStat(String label, String value, Color accent) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Colors.white70,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.bricolageGrotesque(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: accent,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(_navy),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Retrieving punch logs...',
            style: GoogleFonts.dmSans(color: _muted, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.5,
          child: Center(
            child: NexusEmptyState(
              title: 'No Biometric Punches',
              description: 'No entry or exit activity recorded on ${DateFormat('dd MMM yyyy').format(_selectedDate)}.',
              icon: Icons.fingerprint_rounded,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(dynamic error) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.5,
          child: Center(
            child: NexusErrorState(
              message: ErrorFormatter.format(error, fallback: 'Failed to fetch biometric punch logs.'),
              onRetry: () => setState(() => _fetchBiometric(forceRefresh: true)),
            ),
          ),
        ),
      ],
    );
  }
}
