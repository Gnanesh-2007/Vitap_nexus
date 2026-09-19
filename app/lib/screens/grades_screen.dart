import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/mesh_ambient_background.dart';

class GradesScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? initialData;

  const GradesScreen({super.key, this.initialData});

  @override
  ConsumerState<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends ConsumerState<GradesScreen> {
  late Future<Map<String, dynamic>> _gradesFuture;

  @override
  void initState() {
    super.initState();
    _fetchGrades();
  }

  void _fetchGrades({bool forceRefresh = false}) {
    _gradesFuture = _getGradesData(forceRefresh: forceRefresh);
  }

  Future<Map<String, dynamic>> _getGradesData({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      if (widget.initialData != null && widget.initialData!.isNotEmpty) {
        return widget.initialData!;
      }
      final mem = StorageService.getMemoryCache('grades');
      if (mem is Map && mem.isNotEmpty) {
        return Map<String, dynamic>.from(mem);
      }
      final disk = await StorageService.getCache('grades');
      if (disk is Map && disk.isNotEmpty) {
        return Map<String, dynamic>.from(disk);
      }
    }

    final auth = ref.read(authProvider);
    try {
      final fresh = await apiService.fetchGradeHistory(
        username: auth.username ?? '',
        password: auth.password ?? '',
      );
      if (fresh.isNotEmpty) {
        await StorageService.setCache('grades', fresh);
        return fresh;
      }
    } catch (e) {
      debugPrint('GradesScreen: Network fetch failed ($e). Checking offline cache...');
      final fallback = widget.initialData ??
          StorageService.getMemoryCache('grades') ??
          await StorageService.getCache('grades');
      if (fallback is Map && fallback.isNotEmpty) {
        return Map<String, dynamic>.from(fallback);
      }
      rethrow;
    }

    final fallback = widget.initialData ??
        StorageService.getMemoryCache('grades') ??
        await StorageService.getCache('grades');
    if (fallback is Map && fallback.isNotEmpty) {
      return Map<String, dynamic>.from(fallback);
    }
    return {};
  }

  Color _getGradeColor(String grade) {
    switch (grade.toUpperCase().trim()) {
      case 'S':
        return const Color(0xFF10B981);
      case 'A':
        return const Color(0xFF388BFD);
      case 'B':
        return const Color(0xFF8B5CF6);
      case 'C':
        return const Color(0xFFF59E0B);
      case 'D':
      case 'E':
        return const Color(0xFFF97316);
      case 'F':
      case 'N':
        return AppTheme.error;
      case 'P':
        return const Color(0xFF06B6D4);
      default:
        return AppTheme.cyanAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Grades & CGPA',
          style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              setState(() {
                _fetchGrades(forceRefresh: true);
              });
            },
          ),
        ],
      ),
      body: MeshAmbientBackground(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _gradesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildSkeletonLoading();
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        'Failed to load grade history',
                        style: GoogleFonts.outfit(fontSize: 18, color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        snapshot.error.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => setState(() => _fetchGrades(forceRefresh: true)),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final data = snapshot.data ?? {};
            final cgpa = data['cgpa']?.toString() ?? 'N/A';
            final creditsEarned = data['credits_earned']?.toString() ?? 'N/A';
            final creditsReg = data['credits_registered']?.toString() ?? 'N/A';
            final courses = (data['courses'] as List<dynamic>?) ?? [];

            return ListView(
              padding: const EdgeInsets.all(18),
              children: [
                // ─── CGPA Summary Cards ──────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF854D0E), Color(0xFF1E293B)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.emoji_events_rounded, color: Color(0xFFF59E0B), size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  'CGPA',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              cgpa,
                              style: GoogleFonts.outfit(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFF59E0B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Credits Earned',
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.white60),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              creditsEarned,
                              style: GoogleFonts.outfit(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryAccent,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Registered: $creditsReg',
                              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08, end: 0),
                const SizedBox(height: 24),

              // ─── Subject Wise Section Header ─────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Subject-Wise Grades',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${courses.length} Courses',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.cyanAccent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ─── Courses List ────────────────────────────────────────────
              if (courses.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      'No grade history records found in VTOP.',
                      style: GoogleFonts.inter(color: Colors.white60),
                    ),
                  ),
                )
              else
                ...courses.asMap().entries.map((entry) {
                  final index = entry.key;
                  final c = entry.value;
                  final grade = c['grade']?.toString() ?? '-';
                  final gradeColor = _getGradeColor(grade);
                  final credits = c['credits']?.toString() ?? '0';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Grade Badge
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: gradeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: gradeColor.withValues(alpha: 0.4), width: 1.5),
                          ),
                          child: Center(
                            child: Text(
                              grade,
                              style: GoogleFonts.outfit(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: gradeColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      c['course_code'] ?? '',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryAccent,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '$credits Credits',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                c['course_title'] ?? 'Course',
                                style: GoogleFonts.inter(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    c['course_type'] ?? '',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: Colors.white54,
                                    ),
                                  ),
                                  if (c['exam_month'] != null && c['exam_month'].toString().isNotEmpty) ...[
                                    const Text(' • ', style: TextStyle(color: Colors.white30)),
                                    Text(
                                      c['exam_month'].toString(),
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                      .animate(delay: (30 * index).ms)
                      .fadeIn(duration: 350.ms)
                      .slideY(begin: 0.05, end: 0);
                }),
            ],
          );
        },
      ),
    ),
  );
}

  Widget _buildSkeletonLoading() {
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
          Text('Loading grades...', style: TextStyle(color: Colors.white54, fontSize: 13)),
        ],
      ),
    );
  }
}
