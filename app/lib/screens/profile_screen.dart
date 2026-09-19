import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/auth_provider.dart';
import '../providers/vtop_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/mesh_ambient_background.dart';
import 'grades_screen.dart';
import 'login_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _showAcademicStats = false;

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final allDataAsync = ref.watch(allDataProvider);
    final authState = ref.watch(authProvider);

    String cgpa = 'N/A';
    String creditsEarned = 'N/A';
    allDataAsync.whenData((data) {
      final gradeHistory = data['grade_history'] as Map<String, dynamic>?;
      if (gradeHistory != null) {
        cgpa = gradeHistory['cgpa']?.toString() ?? 'N/A';
        creditsEarned = gradeHistory['credits_earned']?.toString() ?? 'N/A';
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          'Student Profile',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700,
            fontSize: 22,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: AppTheme.surface.withValues(alpha: 0.6),
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded, color: AppTheme.cyanAccent, size: 20),
              tooltip: 'Sync Data',
              onPressed: () {
                ref.invalidate(profileProvider);
                ref.invalidate(allDataProvider);
              },
            ),
          ),
        ],
      ),
      body: MeshAmbientBackground(
        child: profileAsync.when(
          data: (profileData) {
            final studentName = profileData['student_name'] ?? authState.username ?? 'Student';
            final appNo = profileData['application_number'] ?? authState.username ?? '';
            final email = profileData['email'] ?? '';
            final bloodGroup = profileData['blood_group'] ?? '';
            final dob = profileData['dob'] ?? '';
            final base64Pfp = profileData['base64_pfp'] as String?;
            final mentor = profileData['mentor_details'] as Map<String, dynamic>?;

            return ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                // ─── Hero Header Card ─────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  decoration: BoxDecoration(
                    gradient: AppTheme.cardGradient,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: AppTheme.cardBorder, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Badges + Avatar Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildCornerBadge(
                            label: 'CGPA',
                            value: _showAcademicStats ? cgpa : '•••',
                            color: const Color(0xFFFFB703),
                            icon: Icons.emoji_events_rounded,
                            onTap: () => _handleStatTap(),
                          ),
                          _buildAvatar(base64Pfp),
                          _buildCornerBadge(
                            label: 'Credits',
                            value: _showAcademicStats ? creditsEarned : '•••',
                            color: AppTheme.cyanAccent,
                            icon: Icons.auto_awesome_rounded,
                            onTap: () => _handleStatTap(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Toggle Button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => setState(() => _showAcademicStats = !_showAcademicStats),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: _showAcademicStats
                                  ? AppTheme.cyanAccent.withValues(alpha: 0.12)
                                  : AppTheme.surfaceLight.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _showAcademicStats
                                    ? AppTheme.cyanAccent.withValues(alpha: 0.35)
                                    : const Color(0xFF24344D),
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
                                      ? AppTheme.cyanAccent
                                      : const Color(0xFF94A3B8),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _showAcademicStats ? 'Hide Academic Stats' : 'Reveal CGPA & Credits',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _showAcademicStats
                                        ? AppTheme.cyanAccent
                                        : const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // User Identity
                      Text(
                        studentName,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          appNo,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryAccent,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      if (email.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          email,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF94A3B8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08, end: 0),
                const SizedBox(height: 20),

                // ─── Personal Information Group ───────────────────────────
                _buildSectionHeader(title: 'Personal Details', icon: Icons.person_search_rounded),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surface.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: Column(
                    children: [
                      if (dob.isNotEmpty) ...[
                        _buildDetailRow(
                          icon: Icons.cake_outlined,
                          iconColor: const Color(0xFFF472B6),
                          label: 'Date of Birth',
                          value: dob,
                        ),
                        _buildDivider(),
                      ],
                      if (bloodGroup.isNotEmpty) ...[
                        _buildDetailRow(
                          icon: Icons.bloodtype_outlined,
                          iconColor: const Color(0xFFF87171),
                          label: 'Blood Group',
                          value: bloodGroup,
                        ),
                        _buildDivider(),
                      ],
                      _buildDetailRow(
                        icon: Icons.domain_rounded,
                        iconColor: const Color(0xFF60A5FA),
                        label: 'Campus',
                        value: 'VIT-AP University',
                      ),
                    ],
                  ),
                ).animate(delay: 80.ms).fadeIn(duration: 350.ms).slideY(begin: 0.05, end: 0),
                const SizedBox(height: 20),

                // ─── Faculty Mentor Group ─────────────────────────────────
                if (mentor != null) ...[
                  _buildSectionHeader(title: 'Faculty Mentor', icon: Icons.school_rounded),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surface.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Column(
                      children: [
                        _buildDetailRow(
                          icon: Icons.badge_outlined,
                          iconColor: AppTheme.cyanAccent,
                          label: 'Name',
                          value: mentor['mentor_name'] ?? mentor['faculty_name'] ?? 'Assigned Faculty',
                        ),
                        if (mentor['mentor_email'] != null) ...[
                          _buildDivider(),
                          _buildDetailRow(
                            icon: Icons.alternate_email_rounded,
                            iconColor: const Color(0xFF818CF8),
                            label: 'Email',
                            value: mentor['mentor_email'],
                          ),
                        ],
                        if (mentor['cabin_number'] != null || mentor['cabin'] != null) ...[
                          _buildDivider(),
                          _buildDetailRow(
                            icon: Icons.meeting_room_outlined,
                            iconColor: const Color(0xFF34D399),
                            label: 'Cabin',
                            value: mentor['cabin_number'] ?? mentor['cabin'],
                          ),
                        ],
                      ],
                    ),
                  ).animate(delay: 140.ms).fadeIn(duration: 350.ms).slideY(begin: 0.05, end: 0),
                  const SizedBox(height: 28),
                ],

                // ─── Logout Action ────────────────────────────────────────
                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () => _handleLogout(context),
                    icon: const Icon(Icons.logout_rounded, color: AppTheme.error, size: 20),
                    label: Text(
                      'Logout from VTOP',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppTheme.error,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.error, width: 1.2),
                      backgroundColor: AppTheme.error.withValues(alpha: 0.05),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ).animate(delay: 200.ms).fadeIn(duration: 350.ms),
              ],
            );
          },
          loading: () => _buildSkeletonLoading(),
          error: (err, stack) => _buildErrorState(err),
        ),
      ),
    );
  }

  // ─── Helper Widgets & Logic ───────────────────────────────────────────────

  void _handleStatTap() {
    if (_showAcademicStats) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const GradesScreen()),
      );
    } else {
      setState(() => _showAcademicStats = true);
    }
  }

  Widget _buildAvatar(String? base64Pfp) {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppTheme.primaryGradient,
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.45),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 2),
      ),
      child: ClipOval(
        child: base64Pfp != null && base64Pfp.isNotEmpty
            ? Image.memory(
                base64Decode(base64Pfp),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.person_rounded,
                  size: 48,
                  color: Colors.white,
                ),
              )
            : const Icon(
                Icons.person_rounded,
                size: 48,
                color: Colors.white,
              ),
      ),
    );
  }

  Widget _buildCornerBadge({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 78,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({required String title, required IconData icon}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.cyanAccent),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF94A3B8),
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 16,
      endIndent: 16,
      color: AppTheme.cardBorder.withValues(alpha: 0.6),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Confirm Logout',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to log out from VITAP Nexus?',
          style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Logout', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(authProvider.notifier).logout();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  Widget _buildSkeletonLoading() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          height: 240,
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppTheme.cardBorder),
          ),
        ),
        Container(
          height: 150,
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.cardBorder),
          ),
        ),
        Container(
          height: 150,
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.cardBorder),
          ),
        ),
      ],
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: 0.08));
  }

  Widget _buildErrorState(Object err) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, size: 40, color: AppTheme.error),
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load profile',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(
              err.toString(),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => ref.invalidate(profileProvider),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text('Try Again', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}