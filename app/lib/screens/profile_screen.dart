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

    // Extract CGPA and Credits from allDataProvider
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
        title: Text(
          'Student Profile',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: AppTheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.invalidate(profileProvider);
              ref.invalidate(allDataProvider);
            },
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
              padding: const EdgeInsets.all(18),
              children: [
                // ─── Profile Header Card with CGPA & Credits Corner Badges ────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppTheme.cardGradient,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: Column(
                    children: [
                      // Flanking Corner Badges + Centered Avatar Area
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                        // Left Corner: CGPA Badge
                        _buildCornerBadge(
                          label: 'CGPA',
                          value: _showAcademicStats ? cgpa : '•••',
                          color: const Color(0xFFF59E0B),
                          icon: Icons.emoji_events_rounded,
                          onTap: () {
                            if (_showAcademicStats) {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const GradesScreen()),
                              );
                            } else {
                              setState(() => _showAcademicStats = true);
                            }
                          },
                        ),
                        const SizedBox(width: 14),

                        // Center: Avatar (Fully visible with glowing ring)
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppTheme.primaryGradient,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary.withValues(alpha: 0.35),
                                blurRadius: 18,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: base64Pfp != null && base64Pfp.isNotEmpty
                                ? Image.memory(
                                    base64Decode(base64Pfp),
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => const Icon(
                                      Icons.person_rounded,
                                      size: 50,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.person_rounded,
                                    size: 50,
                                    color: Colors.white,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Right Corner: Credits Badge
                        _buildCornerBadge(
                          label: 'Credits',
                          value: _showAcademicStats ? creditsEarned : '•••',
                          color: AppTheme.cyanAccent,
                          icon: Icons.stars_rounded,
                          onTap: () {
                            if (_showAcademicStats) {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const GradesScreen()),
                              );
                            } else {
                              setState(() => _showAcademicStats = true);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Privacy Visibility Toggle
                    GestureDetector(
                      onTap: () => setState(() => _showAcademicStats = !_showAcademicStats),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF24344D)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _showAcademicStats ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                              size: 14,
                              color: _showAcademicStats ? AppTheme.cyanAccent : const Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _showAcademicStats ? 'Hide Academic Stats' : 'Reveal CGPA & Credits',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _showAcademicStats ? AppTheme.cyanAccent : const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Text(
                      studentName,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      appNo,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryAccent,
                      ),
                    ),
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08, end: 0),
              const SizedBox(height: 16),

              // Personal Details Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Personal Details',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (dob.isNotEmpty) _buildDetailRow(Icons.cake_outlined, 'Date of Birth', dob),
                    if (bloodGroup.isNotEmpty) _buildDetailRow(Icons.bloodtype_outlined, 'Blood Group', bloodGroup),
                    _buildDetailRow(Icons.domain_rounded, 'Campus', 'VIT-AP University'),
                  ],
                ),
              ).animate(delay: 60.ms).fadeIn(duration: 350.ms).slideY(begin: 0.06, end: 0),
              const SizedBox(height: 16),

              // Mentor Info Card
              if (mentor != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.school_outlined, color: AppTheme.cyanAccent, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Faculty Mentor',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        Icons.person_outline,
                        'Name',
                        mentor['mentor_name'] ?? mentor['faculty_name'] ?? 'Assigned Faculty',
                      ),
                      if (mentor['mentor_email'] != null)
                        _buildDetailRow(Icons.email_outlined, 'Email', mentor['mentor_email']),
                      if (mentor['cabin_number'] != null || mentor['cabin'] != null)
                        _buildDetailRow(Icons.room_outlined, 'Cabin', mentor['cabin_number'] ?? mentor['cabin']),
                    ],
                  ),
                ).animate(delay: 120.ms).fadeIn(duration: 350.ms).slideY(begin: 0.06, end: 0),
                const SizedBox(height: 16),
              ],

              // Logout Button
              SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppTheme.surface,
                        title: const Text('Logout'),
                        content: const Text('Are you sure you want to log out from VITAP Nexus?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Logout'),
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
                  },
                  icon: const Icon(Icons.logout_rounded, color: AppTheme.error),
                  label: Text(
                    'Logout from VTOP',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.error,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.error),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ).animate(delay: 180.ms).fadeIn(duration: 350.ms),
              const SizedBox(height: 24),
            ],
          );
        },
        loading: () => _buildSkeletonLoading(),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
                const SizedBox(height: 16),
                Text('Failed to load profile', style: GoogleFonts.outfit(fontSize: 18, color: Colors.white)),
                const SizedBox(height: 8),
                Text(err.toString(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(profileProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildSkeletonLoading() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Container(
          height: 220,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.cardBorder),
          ),
        ),
        Container(
          height: 140,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.cardBorder),
          ),
        ),
        Container(
          height: 140,
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.cardBorder),
          ),
        ),
      ],
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: 0.08));
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 12, color: color),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 10),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF94A3B8),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
