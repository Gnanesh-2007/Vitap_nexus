import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/mesh_ambient_background.dart';

class MentorScreen extends ConsumerStatefulWidget {
  const MentorScreen({super.key});

  @override
  ConsumerState<MentorScreen> createState() => _MentorScreenState();
}

class _MentorScreenState extends ConsumerState<MentorScreen> {
  late Future<Map<String, dynamic>> _mentorFuture;

  @override
  void initState() {
    super.initState();
    _fetchMentor();
  }

  void _fetchMentor() {
    final auth = ref.read(authProvider);
    _mentorFuture = apiService.fetchMentor(
      username: auth.username ?? '',
      password: auth.password ?? '',
    );
  }

  Future<void> _launchEmail(String email) async {
    try {
      final uri = Uri.parse('mailto:$email');
      await launchUrl(uri);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open email client for $email')),
        );
      }
    }
  }

  Future<void> _launchCall(String phone) async {
    try {
      final uri = Uri.parse('tel:$phone');
      await launchUrl(uri);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not dial $phone')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Faculty Mentor / Proctor', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => setState(() => _fetchMentor()),
          ),
        ],
      ),
      body: MeshAmbientBackground(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _mentorFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildSkeletonMentor();
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
                      Text('Failed to load mentor details', style: GoogleFonts.outfit(fontSize: 18, color: Colors.white)),
                      const SizedBox(height: 8),
                      Text(snapshot.error.toString(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => setState(() => _fetchMentor()),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final mentor = snapshot.data ?? {};
            final name = mentor['faculty_name'] ?? mentor['name'] ?? 'Faculty Mentor';
            final email = mentor['faculty_email'] ?? mentor['email'] ?? 'Not Available';
            final phone = mentor['faculty_mobile_number'] ?? mentor['mobile'] ?? 'Not Available';
            final cabin = mentor['cabin'] ?? mentor['faculty_cabin'] ?? 'Faculty Block';
            final designation = mentor['faculty_designation'] ?? mentor['designation'] ?? 'Professor / Proctor';
            final school = mentor['school'] ?? mentor['faculty_department'] ?? 'School of Computer Science & Engineering';

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Mentor Profile Header Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E3A8A), Color(0xFF0F172A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.primaryAccent.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: const Color(0xFF84CC16).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF84CC16), width: 2),
                        ),
                        child: const Icon(Icons.supervisor_account_rounded, size: 36, color: Color(0xFF84CC16)),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        name,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        designation,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(fontSize: 13, color: AppTheme.cyanAccent, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        school,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08, end: 0),
                const SizedBox(height: 20),

                // Contact Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: email.contains('@') ? () => _launchEmail(email) : null,
                        icon: const Icon(Icons.email_rounded, size: 18),
                        label: const Text('Email Mentor'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    if (phone != 'Not Available') ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _launchCall(phone),
                          icon: const Icon(Icons.phone_rounded, size: 18, color: Color(0xFF10B981)),
                          label: const Text('Call', style: TextStyle(color: Color(0xFF10B981))),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF10B981)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ).animate(delay: 70.ms).fadeIn(duration: 350.ms).slideY(begin: 0.06, end: 0),
                const SizedBox(height: 24),

                // Detailed Info Tiles
                Text('Mentor Information', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 12),

                _buildDetailTile(Icons.person_rounded, 'Full Name', name, 0),
                _buildDetailTile(Icons.email_rounded, 'Official Email', email, 1),
                _buildDetailTile(Icons.phone_rounded, 'Mobile Number', phone, 2),
                _buildDetailTile(Icons.meeting_room_rounded, 'Cabin / Office', cabin, 3),
                _buildDetailTile(Icons.domain_rounded, 'Department / School', school, 4),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSkeletonMentor() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          height: 190,
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.cardBorder),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.cardBorder),
          ),
        ),
        const SizedBox(height: 24),
        ...List.generate(
          4,
          (index) => Container(
            height: 64,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.cardBorder),
            ),
          ),
        ),
      ],
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: 0.08));
  }

  Widget _buildDetailTile(IconData icon, String label, String value, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF84CC16)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.inter(fontSize: 11, color: Colors.white54)),
              const SizedBox(height: 2),
              Text(value, style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.white)),
            ],
          ),
        ],
      ),
    )
        .animate(delay: (100 + 35 * index).ms)
        .fadeIn(duration: 350.ms)
        .slideY(begin: 0.04, end: 0);
  }
}
