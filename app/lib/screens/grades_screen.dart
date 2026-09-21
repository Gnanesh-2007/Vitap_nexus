import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../services/storage_service.dart';

class GradesScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? initialData;

  const GradesScreen({super.key, this.initialData});

  @override
  ConsumerState<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends ConsumerState<GradesScreen> {
  late Future<Map<String, dynamic>> _gradesFuture;

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

  TextStyle get _micro => GoogleFonts.spaceGrotesk(
        fontSize: 9,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
      );

  @override
  void initState() {
    super.initState();
    _fetchGrades();
  }

  void _fetchGrades({bool forceRefresh = false}) {
    _gradesFuture = _getGradesData(forceRefresh: forceRefresh);
  }

  Future<Map<String, dynamic>> _getGradesData({
    bool forceRefresh = false,
  }) async {
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
      debugPrint(
        'GradesScreen: Network fetch failed ($e). '
        'Checking offline cache...',
      );

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
        return _green;
      case 'A':
        return _blue;
      case 'B':
        return const Color(0xFF6575C5);
      case 'C':
        return const Color(0xFFC48A21);
      case 'D':
      case 'E':
        return _orange;
      case 'F':
      case 'N':
        return _red;
      case 'P':
        return const Color(0xFF328C9B);
      default:
        return _blue;
    }
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
            setState(() => _fetchGrades(forceRefresh: true));
            await _gradesFuture;
          },
          child: FutureBuilder<Map<String, dynamic>>(
            future: _gradesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoading();
              }

              if (snapshot.hasError) {
                return _buildError(snapshot.error!);
              }

              final data = snapshot.data ?? {};
              final cgpa = data['cgpa']?.toString() ?? 'N/A';
              final earned = data['credits_earned']?.toString() ?? 'N/A';
              final registered =
                  data['credits_registered']?.toString() ?? 'N/A';
              final courses = (data['courses'] as List<dynamic>?) ?? [];

              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader()),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 2, 20, 32),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildHero(cgpa, earned, registered),
                        const SizedBox(height: 28),
                        _buildCoursesHeader(courses.length),
                        const SizedBox(height: 12),
                        if (courses.isEmpty)
                          _buildEmpty()
                        else
                          ...courses.asMap().entries.map(
                                (entry) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _buildCourse(entry.value),
                                ),
                              ),
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
              child: const Icon(
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
                  'ACADEMICS',
                  style: _micro.copyWith(color: _orange),
                ),
                const SizedBox(height: 3),
                Text(
                  'Grades & CGPA',
                  style: GoogleFonts.dmSans(
                    color: _ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => setState(() => _fetchGrades(forceRefresh: true)),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _line),
              ),
              child: const Icon(
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

  Widget _buildHero(
    String cgpa,
    String earned,
    String registered,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _navy,
        borderRadius: BorderRadius.circular(21),
        boxShadow: const [
          BoxShadow(
            color: Color(0x17172B4D),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _HeroMetric(
                  label: 'CURRENT CGPA',
                  value: cgpa,
                  icon: Icons.auto_graph_rounded,
                  accent: const Color(0xFFF2B35B),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeroMetric(
                  label: 'CREDITS EARNED',
                  value: earned,
                  icon: Icons.school_outlined,
                  accent: const Color(0xFF79B7FF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 11,
              vertical: 9,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withValues(alpha: .10),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.fact_check_outlined,
                  color: Colors.white54,
                  size: 15,
                ),
                const SizedBox(width: 7),
                Text(
                  'Credits registered',
                  style: GoogleFonts.dmSans(
                    color: Colors.white60,
                    fontSize: 10.5,
                  ),
                ),
                const Spacer(),
                Text(
                  registered,
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoursesHeader(int count) {
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
          child: const Icon(
            Icons.menu_book_outlined,
            color: _blue,
            size: 16,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            'SUBJECT-WISE GRADES',
            style: _micro.copyWith(
              color: _ink,
              fontSize: 9.5,
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
            '$count COURSES',
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

  Widget _buildCourse(dynamic course) {
    final grade = course['grade']?.toString() ?? '-';
    final color = _getGradeColor(grade);
    final code = course['course_code']?.toString() ?? '';
    final title = course['course_title']?.toString() ?? 'Course';
    final credits = course['credits']?.toString() ?? '0';
    final type = course['course_type']?.toString() ?? '';
    final month = course['exam_month']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .09),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color.withValues(alpha: .35),
              ),
            ),
            child: Center(
              child: Text(
                grade,
                style: GoogleFonts.dmSans(
                  color: color,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (code.isNotEmpty)
                      _Pill(
                        code,
                        _blue,
                        const Color(0xFFEAF0FD),
                      ),
                    _Pill(
                      '$credits CREDITS',
                      _muted,
                      _soft,
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    color: _ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.18,
                  ),
                ),
                if (type.isNotEmpty || month.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 5,
                    children: [
                      if (type.isNotEmpty)
                        _Pill(type, _muted, _soft),
                      if (month.isNotEmpty)
                        _Pill(
                          month,
                          _orange,
                          const Color(0xFFF9ECE7),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.menu_book_outlined,
            color: _muted,
            size: 30,
          ),
          const SizedBox(height: 10),
          Text(
            'No grade history records found in VTOP.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              color: _muted,
              fontSize: 12.5,
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
          const SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: _blue,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Loading grades...',
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
                    child: const Icon(
                      Icons.error_outline_rounded,
                      color: _red,
                      size: 31,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to Load Grade History',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      color: _ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    error.toString(),
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
                      setState(() => _fetchGrades(forceRefresh: true));
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 18),
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

class _HeroMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  const _HeroMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 10, 13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .055),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: Colors.white.withValues(alpha: .11),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 16),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white54,
              fontSize: 7.5,
              fontWeight: FontWeight.w700,
              letterSpacing: .7,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  final Color background;

  const _Pill(this.text, this.color, this.background);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: GoogleFonts.spaceGrotesk(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w700,
          letterSpacing: .25,
        ),
      ),
    );
  }
}
