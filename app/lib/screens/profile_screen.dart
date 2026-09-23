import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/vtop_providers.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/error_formatter.dart';
import 'grades_screen.dart';
import 'login_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _showAcademicStats = false;
  bool _isSyncing = false;
  List<Map<String, dynamic>> _localSemesters = [];

  TextStyle get _micro => GoogleFonts.spaceGrotesk(
        fontSize: 9,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
      );

  @override
  void initState() {
    super.initState();
    _loadLocalSemesters();
  }

  Future<void> _loadLocalSemesters() async {
    final semesters = await StorageService.getAvailableSemesters();

    if (!mounted || semesters.isEmpty) return;

    setState(() {
      _localSemesters = semesters;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final profileAsync = ref.watch(profileProvider);
    final allDataAsync = ref.watch(allDataProvider);
    final authState = ref.watch(authProvider);

    String cgpa = 'N/A';
    String creditsEarned = 'N/A';

    allDataAsync.whenData((data) {
      final gradeHistory = data['grade_history'] as Map<String, dynamic>?;
      if (gradeHistory != null) {
        cgpa = gradeHistory['cgpa']?.toString() ?? 'N/A';
        creditsEarned =
            gradeHistory['credits_earned']?.toString() ?? 'N/A';
      }
    });

    return Scaffold(
      backgroundColor: palette.paper,
      body: SafeArea(
        child: profileAsync.when(
          data: (profileData) {
            final studentName = profileData['student_name'] ??
                authState.username ??
                'Student';
            final appNo = profileData['application_number'] ??
                authState.username ??
                '';
            final email = profileData['email'] ?? '';
            final bloodGroup = profileData['blood_group'] ?? '';
            final dob = profileData['dob'] ?? '';
            final base64Pfp = profileData['base64_pfp'] as String?;
            final mentor =
                profileData['mentor_details'] as Map<String, dynamic>?;

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _buildTopBar(palette),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildHero(
                        palette: palette,
                        studentName: studentName.toString(),
                        appNo: appNo.toString(),
                        email: email.toString(),
                        base64Pfp: base64Pfp,
                        cgpa: cgpa,
                        creditsEarned: creditsEarned,
                      ),
                      const SizedBox(height: 24),

                      // PREFERENCES SECTION (Theme toggle)
                      _buildSectionHeader(
                        palette,
                        'PREFERENCES',
                        Icons.palette_outlined,
                      ),
                      const SizedBox(height: 10),
                      _buildPreferencesCard(palette),

                      const SizedBox(height: 24),

                      _buildSectionHeader(
                        palette,
                        'PERSONAL DETAILS',
                        Icons.person_outline_rounded,
                      ),
                      const SizedBox(height: 10),
                      _buildPersonalCard(
                        palette: palette,
                        dob: dob.toString(),
                        bloodGroup: bloodGroup.toString(),
                      ),

                      if (mentor != null) ...[
                        const SizedBox(height: 24),
                        _buildSectionHeader(
                          palette,
                          'FACULTY MENTOR',
                          Icons.school_outlined,
                        ),
                        const SizedBox(height: 10),
                        _buildMentorCard(palette, mentor),
                      ],

                      const SizedBox(height: 28),
                      _buildSyncButton(palette),
                      const SizedBox(height: 12),
                      _buildLogoutButton(palette),
                    ]),
                  ),
                ),
              ],
            );
          },
          loading: () => _buildSkeletonLoading(palette),
          error: (err, stack) => _buildErrorState(palette, err),
        ),
      ),
    );
  }

  Widget _buildTopBar(AppPalette palette) {
    final authState = ref.watch(authProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      child: Row(
        children: [
          if (Navigator.of(context).canPop())
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: palette.line),
                ),
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: palette.navy,
                  size: 20,
                ),
              ),
            )
          else
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.line),
              ),
              child: Icon(
                Icons.person_outline_rounded,
                color: palette.navy,
                size: 20,
              ),
            ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ACCOUNT',
                  style: _micro.copyWith(color: palette.orange),
                ),
                const SizedBox(height: 3),
                Text(
                  'Student Profile',
                  style: GoogleFonts.dmSans(
                    color: palette.ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                  ),
                ),
              ],
            ),
          ),
          if (_localSemesters.isNotEmpty ||
              authState.availableSemesters.isNotEmpty)
            _buildSemesterSelector(palette, authState),
        ],
      ),
    );
  }

  Widget _buildSemesterSelector(AppPalette palette, AuthState authState) {
    final semesters = _localSemesters.isNotEmpty
        ? _localSemesters
        : authState.availableSemesters;

    final activeId = authState.activeSemesterId;

    String? selectedId;
    if (semesters.any(
      (s) => s['id']?.toString() == activeId,
    )) {
      selectedId = activeId;
    } else if (semesters.isNotEmpty) {
      selectedId = semesters.first['id']?.toString();
    }

    return Flexible(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 210),
        padding: const EdgeInsets.only(left: 11, right: 7),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.line),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: selectedId,
            isExpanded: true,
            isDense: true,
            dropdownColor: palette.surface,
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: palette.inkMuted,
              size: 18,
            ),
            style: GoogleFonts.dmSans(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: palette.ink,
            ),
            items: semesters.map((sem) {
              final id = sem['id']?.toString() ?? '';
              final name = sem['name']?.toString() ?? id;

              return DropdownMenuItem<String>(
                value: id,
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (newSemId) async {
              if (newSemId == null) return;

              final match = semesters.firstWhere(
                (s) => s['id']?.toString() == newSemId,
              );

              final name = match['name']?.toString() ?? newSemId;

              await ref.read(authProvider.notifier).changeSemester(
                    newSemId,
                    name,
                  );

              if (mounted) {
                setState(() {
                  _localSemesters = List<Map<String, dynamic>>.from(semesters);
                });
              }

              ref.invalidate(allDataProvider);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPreferencesCard(AppPalette palette) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          ref.read(themeModeProvider.notifier).toggleTheme();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.line),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeInOutCubic,
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: (isDark ? palette.blue : palette.orange).withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  color: isDark ? palette.blue : palette.orange,
                  size: 19,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dark Appearance',
                      style: GoogleFonts.dmSans(
                        color: palette.ink,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isDark ? 'Matte Slate theme active' : 'Warm Paper theme active',
                      style: GoogleFonts.dmSans(
                        color: palette.inkSoft,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              // Smooth custom animated toggle pill
              _buildSmoothSwitch(isDark, palette),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmoothSwitch(bool isDark, AppPalette palette) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeInOutCubic,
      width: 48,
      height: 28,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isDark ? palette.blue : palette.line,
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeInOutCubic,
        alignment: isDark ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              isDark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
              size: 11,
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE47543),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHero({
    required AppPalette palette,
    required String studentName,
    required String appNo,
    required String email,
    required String? base64Pfp,
    required String cgpa,
    required String creditsEarned,
  }) {
    final heroBg = palette.isDark ? palette.surface : const Color(0xFF172B4D);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: heroBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _buildStatCard(
                  palette: palette,
                  label: 'CGPA',
                  value: _showAcademicStats ? cgpa : '•••',
                  icon: Icons.auto_graph_rounded,
                  accent: const Color(0xFFF2B35B),
                  onTap: _handleStatTap,
                ),
              ),
              const SizedBox(width: 12),
              _buildAvatar(palette, base64Pfp),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  palette: palette,
                  label: 'CREDITS',
                  value: _showAcademicStats ? creditsEarned : '•••',
                  icon: Icons.school_outlined,
                  accent: const Color(0xFF72B4FF),
                  onTap: _handleStatTap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(
                () => _showAcademicStats = !_showAcademicStats,
              ),
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                decoration: BoxDecoration(
                  color: _showAcademicStats
                      ? Colors.white.withValues(alpha: .11)
                      : Colors.white.withValues(alpha: .06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .13),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _showAcademicStats
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                      size: 14,
                      color: _showAcademicStats
                          ? const Color(0xFF9AC6FF)
                          : Colors.white60,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _showAcademicStats
                          ? 'Hide Academic Stats'
                          : 'Reveal CGPA & Credits',
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.white70,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 17),
          Text(
            studentName,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
          if (appNo.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: Colors.white.withValues(alpha: .13),
                ),
              ),
              child: Text(
                appNo,
                style: GoogleFonts.spaceGrotesk(
                  color: const Color(0xFFA9C9FF),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .8,
                ),
              ),
            ),
          ],
          if (email.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              email,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                color: Colors.white60,
                fontSize: 11.5,
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: .04, end: 0);
  }

  Widget _buildAvatar(AppPalette palette, String? base64Pfp) {
    return Container(
      width: 88,
      height: 88,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: palette.surface,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: .25),
          width: 1.5,
        ),
      ),
      child: ClipOval(
        child: base64Pfp != null && base64Pfp.isNotEmpty
            ? Image.memory(
                base64Decode(base64Pfp),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _avatarFallback(palette),
              )
            : _avatarFallback(palette),
      ),
    );
  }

  Widget _avatarFallback(AppPalette palette) {
    return Container(
      color: palette.soft,
      alignment: Alignment.center,
      child: Icon(
        Icons.person_rounded,
        size: 45,
        color: palette.navy,
      ),
    );
  }

  Widget _buildStatCard({
    required AppPalette palette,
    required String label,
    required String value,
    required IconData icon,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .055),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: Colors.white.withValues(alpha: .11),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: accent),
            const SizedBox(height: 5),
            Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white54,
                fontSize: 7.5,
                fontWeight: FontWeight.w700,
                letterSpacing: .8,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: GoogleFonts.dmSans(
                color: accent,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(AppPalette palette, String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: palette.line),
          ),
          child: Icon(icon, size: 16, color: palette.blue),
        ),
        const SizedBox(width: 9),
        Text(
          title,
          style: GoogleFonts.spaceGrotesk(
            color: palette.ink,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalCard({
    required AppPalette palette,
    required String dob,
    required String bloodGroup,
  }) {
    final rows = <Widget>[];

    if (dob.isNotEmpty) {
      rows.add(
        _buildDetailRow(
          palette: palette,
          icon: Icons.cake_outlined,
          iconColor: palette.orange,
          label: 'Date of Birth',
          value: dob,
        ),
      );
    }

    if (bloodGroup.isNotEmpty) {
      if (rows.isNotEmpty) rows.add(_buildDivider(palette));
      rows.add(
        _buildDetailRow(
          palette: palette,
          icon: Icons.bloodtype_outlined,
          iconColor: palette.red,
          label: 'Blood Group',
          value: bloodGroup,
        ),
      );
    }

    if (rows.isNotEmpty) rows.add(_buildDivider(palette));
    rows.add(
      _buildDetailRow(
        palette: palette,
        icon: Icons.domain_outlined,
        iconColor: palette.blue,
        label: 'Campus',
        value: 'VIT-AP University',
      ),
    );

    return _buildInfoCard(palette, rows)
        .animate(delay: 70.ms)
        .fadeIn(duration: 300.ms)
        .slideY(begin: .025, end: 0);
  }

  Widget _buildMentorCard(AppPalette palette, Map<String, dynamic> mentor) {
    final rows = <Widget>[
      _buildDetailRow(
        palette: palette,
        icon: Icons.badge_outlined,
        iconColor: palette.blue,
        label: 'Name',
        value: (mentor['mentor_name'] ??
                mentor['faculty_name'] ??
                'Assigned Faculty')
            .toString(),
      ),
    ];

    if (mentor['mentor_email'] != null) {
      rows.add(_buildDivider(palette));
      rows.add(
        _buildDetailRow(
          palette: palette,
          icon: Icons.alternate_email_rounded,
          iconColor: palette.orange,
          label: 'Email',
          value: mentor['mentor_email'].toString(),
        ),
      );
    }

    if (mentor['cabin_number'] != null || mentor['cabin'] != null) {
      rows.add(_buildDivider(palette));
      rows.add(
        _buildDetailRow(
          palette: palette,
          icon: Icons.meeting_room_outlined,
          iconColor: palette.green,
          label: 'Cabin',
          value: (mentor['cabin_number'] ?? mentor['cabin']).toString(),
        ),
      );
    }

    return _buildInfoCard(palette, rows)
        .animate(delay: 120.ms)
        .fadeIn(duration: 300.ms)
        .slideY(begin: .025, end: 0);
  }

  Widget _buildInfoCard(AppPalette palette, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.line),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDetailRow({
    required AppPalette palette,
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: .09),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 17, color: iconColor),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.spaceGrotesk(
                    color: palette.inkMuted,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .65,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    color: palette.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(AppPalette palette) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 15,
      endIndent: 15,
      color: palette.line,
    );
  }

  Widget _buildSyncButton(AppPalette palette) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        onPressed: _isSyncing ? null : _syncAllData,
        icon: _isSyncing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(Icons.sync_rounded, size: 20),
        label: Text(
          _isSyncing ? 'Syncing All Data...' : 'Sync Now',
          style: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: palette.isDark ? palette.blue : const Color(0xFF172B4D),
          foregroundColor: Colors.white,
          disabledBackgroundColor: palette.blue.withValues(alpha: .55),
          disabledForegroundColor: Colors.white70,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      ),
    ).animate(delay: 160.ms).fadeIn(duration: 300.ms);
  }

  Future<void> _syncAllData() async {
    final palette = AppPalette.of(context);
    setState(() => _isSyncing = true);

    try {
      await ref.read(dashboardProvider.notifier).syncAll();
      ref.invalidate(profileProvider);
      ref.invalidate(allDataProvider);

      if (!mounted) return;
      _showSnack(
        'All data synced successfully!',
        palette.green,
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack(
        ErrorFormatter.format(e, fallback: 'Data sync failed. Please try again.'),
        palette.red,
        seconds: 3,
      );
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  void _showSnack(
    String message,
    Color color, {
    int seconds = 2,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(11),
        ),
        duration: Duration(seconds: seconds),
      ),
    );
  }

  Widget _buildLogoutButton(AppPalette palette) {
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: () => _handleLogout(context, palette),
        icon: Icon(
          Icons.logout_rounded,
          color: palette.red,
          size: 19,
        ),
        label: Text(
          'Logout from VTOP',
          style: GoogleFonts.dmSans(
            color: palette.red,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: palette.red.withValues(alpha: .3)),
          backgroundColor: palette.red.withValues(alpha: .08),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      ),
    ).animate(delay: 200.ms).fadeIn(duration: 300.ms);
  }

  void _handleStatTap() {
    if (_showAcademicStats) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const GradesScreen(),
        ),
      );
    } else {
      setState(() => _showAcademicStats = true);
    }
  }

  Future<void> _handleLogout(BuildContext context, AppPalette palette) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: Text(
          'Confirm Logout',
          style: GoogleFonts.dmSans(
            color: palette.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          'Are you sure you want to log out from VITAP Nexus?',
          style: GoogleFonts.dmSans(
            color: palette.inkSoft,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.dmSans(
                color: palette.inkMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: palette.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Logout',
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      resetAllVtopProviders(ref);
      await ref.read(authProvider.notifier).logout();

      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const LoginScreen(),
          ),
          (route) => false,
        );
      }
    }
  }

  Widget _buildSkeletonLoading(AppPalette palette) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: palette.blue,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Loading profile...',
            style: GoogleFonts.dmSans(
              color: palette.inkMuted,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(AppPalette palette, Object err) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: palette.red.withValues(alpha: .12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 31,
                color: palette.red,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load profile',
              style: GoogleFonts.dmSans(
                color: palette.ink,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              ErrorFormatter.format(err, fallback: 'Unable to load profile. Please try again.'),
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                color: palette.inkMuted,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: palette.isDark ? palette.blue : const Color(0xFF172B4D),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => ref.invalidate(profileProvider),
              icon: Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                'Try Again',
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
