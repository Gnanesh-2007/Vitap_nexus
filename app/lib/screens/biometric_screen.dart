import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/mesh_ambient_background.dart';

class BiometricScreen extends ConsumerStatefulWidget {
  const BiometricScreen({super.key});

  @override
  ConsumerState<BiometricScreen> createState() => _BiometricScreenState();
}

class _BiometricScreenState extends ConsumerState<BiometricScreen> {
  DateTime _selectedDate = DateTime.now();
  late Future<List<dynamic>> _biometricFuture;

  @override
  void initState() {
    super.initState();
    _fetchBiometric();
  }

  void _fetchBiometric({bool forceRefresh = false}) {
    _biometricFuture = _getBiometricData(forceRefresh: forceRefresh);
  }

  Future<List<dynamic>> _getBiometricData({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final mem = StorageService.getMemoryCache('biometric');
      if (mem is List && mem.isNotEmpty) {
        return List<dynamic>.from(mem);
      }
      final disk = await StorageService.getCache('biometric');
      if (disk is List && disk.isNotEmpty) {
        return List<dynamic>.from(disk);
      }
    }

    final auth = ref.read(authProvider);
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    try {
      final fresh = await apiService.fetchBiometric(
        username: auth.username ?? '',
        password: auth.password ?? '',
        date: dateStr,
      );
      if (fresh.isNotEmpty) {
        await StorageService.setCache('biometric', fresh);
        return fresh;
      }
    } catch (e) {
      debugPrint('BiometricScreen: Network fetch failed ($e). Checking offline cache...');
      final fallback = StorageService.getMemoryCache('biometric') ??
          await StorageService.getCache('biometric');
      if (fallback is List && fallback.isNotEmpty) {
        return List<dynamic>.from(fallback);
      }
      rethrow;
    }

    final fallback = StorageService.getMemoryCache('biometric') ??
        await StorageService.getCache('biometric');
    if (fallback is List && fallback.isNotEmpty) {
      return List<dynamic>.from(fallback);
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Biometric Punch Logs', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: const [],
      ),
      body: MeshAmbientBackground(
        child: Column(
          children: [
            // Date Selector Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              color: AppTheme.surface,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded, color: AppTheme.cyanAccent, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('EEE, dd MMM yyyy').format(_selectedDate),
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 90)),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() {
                          _selectedDate = picked;
                          _fetchBiometric();
                        });
                      }
                    },
                    icon: const Icon(Icons.edit_calendar_rounded, size: 16),
                    label: const Text('Change Date'),
                  ),
                ],
              ),
            ),

            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  setState(() => _fetchBiometric(forceRefresh: true));
                  await _biometricFuture;
                },
                color: AppTheme.primary,
                backgroundColor: AppTheme.surface,
                child: FutureBuilder<List<dynamic>>(
                  future: _biometricFuture,
                  builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildSkeletonLogs();
                  }

                  if (snapshot.hasError) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.5,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text('Failed to load biometric punches: ${snapshot.error}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60)),
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  final logs = snapshot.data ?? [];
                  if (logs.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.5,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.fingerprint_rounded, size: 54, color: Color(0xFF64748B)),
                                const SizedBox(height: 12),
                                Text('No Biometric Punches Recorded', style: GoogleFonts.outfit(fontSize: 16, color: Colors.white)),
                                const SizedBox(height: 4),
                                Text('No activity recorded for ${DateFormat('dd MMM yyyy').format(_selectedDate)}', style: GoogleFonts.inter(fontSize: 12, color: Colors.white54)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  return ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(18),
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      final time = log['punch_time'] ?? 'Punch';
                      final location = log['punch_location'] ?? 'Turnstile Gate';
                      final direction = log['direction'] ?? (index % 2 == 0 ? 'IN' : 'OUT');
                      final isEntry = direction.toString().toUpperCase() == 'IN';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isEntry ? const Color(0xFF10B981).withValues(alpha: 0.15) : const Color(0xFFF97316).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isEntry ? Icons.login_rounded : Icons.logout_rounded,
                                color: isEntry ? const Color(0xFF10B981) : const Color(0xFFF97316),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(location, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                                  const SizedBox(height: 2),
                                  Text(time, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8))),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isEntry ? const Color(0xFF10B981).withValues(alpha: 0.2) : const Color(0xFFF97316).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                direction.toString().toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isEntry ? const Color(0xFF10B981) : const Color(0xFFF97316),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                          .animate(delay: (30 * index).ms)
                          .fadeIn(duration: 350.ms)
                          .slideY(begin: 0.05, end: 0);
                    },
                  );
                },
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonLogs() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          SizedBox(height: 16),
          Text('Loading biometric logs...', style: TextStyle(color: Colors.white54, fontSize: 13)),
        ],
      ),
    );
  }
}
