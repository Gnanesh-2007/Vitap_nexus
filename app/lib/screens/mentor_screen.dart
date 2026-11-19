import 'dart:convert';
import 'package:flutter/material.dart';
import '../widgets/nexus_app_bar.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/error_formatter.dart';
import '../widgets/shadcn/shadcn_ui.dart';
import '../widgets/motion/nexus_motion.dart';

class MentorScreen extends ConsumerStatefulWidget {
  const MentorScreen({super.key});

  @override
  ConsumerState<MentorScreen> createState() => _MentorScreenState();
}

class _MentorScreenState extends ConsumerState<MentorScreen> {
  late Future<Map<String, dynamic>> _mentorFuture;

  AppPalette get _palette => AppPalette.of(context);
  Color get _background => _palette.paper;
  Color get _surface => _palette.surface;
  Color get _ink => _palette.ink;
  Color get _inkSoft => _palette.inkSoft;
  Color get _muted => _palette.inkMuted;
  Color get _line => _palette.line;
  Color get _navy => _palette.navy;
  Color get _blue => _palette.blue;
  Color get _orange => _palette.orange;
  Color get _green => _palette.green;
  Color get _red => _palette.red;
  Color get _soft => _palette.soft;

  @override
  void initState() {
    super.initState();
    _fetchMentor();
  }

  void _fetchMentor({bool forceRefresh = false}) {
    _mentorFuture = _getMentorData(forceRefresh: forceRefresh);
  }

  Future<Map<String, dynamic>> _getMentorData({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final mem = StorageService.getMemoryCache('mentor');
      if (mem is Map && mem.isNotEmpty) {
        return Map<String, dynamic>.from(mem);
      }
      final disk = await StorageService.getCache('mentor');
      if (disk is Map && disk.isNotEmpty) {
        return Map<String, dynamic>.from(disk);
      }
    }

    final auth = ref.read(authProvider);
    try {
      final fresh = await apiService.fetchMentor(
        username: auth.username ?? '',
        password: auth.password ?? '',
      );
      if (fresh.isNotEmpty) {
        await StorageService.setCache('mentor', fresh);
        return fresh;
      }
    } catch (e) {
      debugPrint('MentorScreen: Network fetch failed ($e). Checking offline cache...');
      final fallback = StorageService.getMemoryCache('mentor') ??
          await StorageService.getCache('mentor');
      if (fallback is Map && fallback.isNotEmpty) {
        return Map<String, dynamic>.from(fallback);
      }
      rethrow;
    }

    final fallback = StorageService.getMemoryCache('mentor') ??
        await StorageService.getCache('mentor');
    if (fallback is Map && fallback.isNotEmpty) {
      return Map<String, dynamic>.from(fallback);
    }
    return {};
  }

  Future<void> _launchEmail(String email) async {
    if (email.isEmpty || email == 'Not Available') return;
    try {
      final uri = Uri.parse('mailto:$email');
      await launchUrl(uri);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _palette.isDark ? const Color(0xFF2A1C1C) : const Color(0xFF1E293B),
            content: Text('Could not open email client for $email', style: GoogleFonts.dmSans(color: Colors.white)),
          ),
        );
      }
    }
  }

  Future<void> _launchCall(String phone) async {
    if (phone.isEmpty || phone == 'Not Available') return;
    try {
      final uri = Uri.parse('tel:$phone');
      await launchUrl(uri);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _palette.isDark ? const Color(0xFF2A1C1C) : const Color(0xFF1E293B),
            content: Text('Could not dial $phone', style: GoogleFonts.dmSans(color: Colors.white)),
          ),
        );
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    if (text.isEmpty || text == 'Not Available') return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(
          '$label copied to clipboard',
          style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  String _formatLastSynced(DateTime? dt) {
    return StorageService.formatLastSynced(dt);
  }

  @override
  Widget build(BuildContext context) {
    final lastSyncedTime = StorageService.getMemoryTimestamp('mentor');

    return Scaffold(
      backgroundColor: _background,
      appBar: NexusAppBar(
        title: 'Mentor',
        subtitle: _formatLastSynced(lastSyncedTime),
        actions: [
          IconButton(
              tooltip: 'Refresh Mentor',
              icon: Icon(Icons.refresh_rounded, color: _navy, size: 20),
              onPressed: () {
                setState(() => _fetchMentor(forceRefresh: true));
              },
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _fetchMentor(forceRefresh: true));
          await _mentorFuture;
        },
        color: _navy,
        backgroundColor: _surface,
        child: FutureBuilder<Map<String, dynamic>>(
          future: _mentorFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildSkeletonLoading();
            }

            if (snapshot.hasError && (!snapshot.hasData || snapshot.data!.isEmpty)) {
              return _buildErrorView(snapshot.error.toString());
            }

            final mentor = snapshot.data ?? {};
            if (mentor.isEmpty) {
              return Center(
                child: Text(
                  'No mentor details assigned yet.',
                  style: GoogleFonts.dmSans(color: _muted, fontSize: 14),
                ),
              );
            }

            final name = (mentor['faculty_name'] ?? mentor['name'] ?? 'Faculty Mentor').toString();
            final email = (mentor['faculty_email'] ?? mentor['email'] ?? 'Not Available').toString();
            final phone = (mentor['faculty_mobile_number'] ?? mentor['mobile'] ?? 'Not Available').toString();
            final cabin = (mentor['cabin'] ?? mentor['faculty_cabin'] ?? 'Faculty Block').toString();
            final designation = (mentor['faculty_designation'] ?? mentor['designation'] ?? 'Professor / Proctor').toString();
            final school = (mentor['school'] ?? mentor['faculty_department'] ?? 'School of Computer Science & Engineering').toString();
            final base64Pfp = mentor['base64_pfp']?.toString();

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                // Hero Mentor Profile Card
                AnimeStaggerItem(
                  index: 0,
                  child: _buildMentorHeroCard(
                    name: name,
                    designation: designation,
                    school: school,
                    base64Pfp: base64Pfp,
                    email: email,
                    phone: phone,
                  ),
                ),

                const SizedBox(height: 20),

                // Contact & Office Information Card
                Text(
                  'OFFICE & CONTACT DIRECTORY',
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: _muted,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),

                AnimeStaggerItem(
                  index: 1,
                  child: _buildContactCard(
                    email: email,
                    phone: phone,
                    cabin: cabin,
                    school: school,
                    designation: designation,
                  ),
                ),

                const SizedBox(height: 20),

                // Responsibilities & Proctoring Guide
                Text(
                  'PROCTORING & MENTORING',
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: _muted,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),

                AnimeStaggerItem(
                  index: 2,
                  child: _buildGuidelinesCard(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMentorHeroCard({
    required String name,
    required String designation,
    required String school,
    required String? base64Pfp,
    required String email,
    required String phone,
  }) {
    ImageProvider? imageProvider;
    if (base64Pfp != null && base64Pfp.isNotEmpty) {
      try {
        final cleanBase64 = base64Pfp.contains(',') ? base64Pfp.split(',').last : base64Pfp;
        imageProvider = MemoryImage(base64Decode(cleanBase64));
      } catch (_) {}
    }
    final hsl = HSLColor.fromColor(_navy);
    final top = hsl.withLightness(hsl.lightness.clamp(0.0, 0.42)).withSaturation(hsl.saturation.clamp(0.5, 1.0)).toColor();
    final bottom = Color.lerp(top, const Color(0xFF16102E), 0.72)!;
    final hasPhone = phone.isNotEmpty && phone != 'Not Available';

    Widget pill(IconData icon, String label, VoidCallback onTap, {required bool solid}) => Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: solid ? Colors.white : Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: solid ? bottom : Colors.white),
                  const SizedBox(width: 8),
                  Text(label,
                      style: GoogleFonts.bricolageGrotesque(fontSize: 14.5, fontWeight: FontWeight.w800, color: solid ? bottom : Colors.white)),
                ],
              ),
            ),
          ),
        );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [top, bottom]),
        boxShadow: [BoxShadow(color: top.withValues(alpha: 0.32), blurRadius: 24, offset: const Offset(0, 12))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  color: _soft,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white, width: 2.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(25),
                  child: imageProvider != null
                      ? Image(
                          image: imageProvider,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _buildAvatarFallback(),
                        )
                      : _buildAvatarFallback(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified_rounded, size: 13, color: Colors.white),
                          const SizedBox(width: 5),
                          Text('YOUR MENTOR',
                              style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.9)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(name,
                        style: GoogleFonts.bricolageGrotesque(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, height: 1.1, letterSpacing: -0.4)),
                    const SizedBox(height: 3),
                    Text(designation,
                        style: GoogleFonts.dmSans(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.82), fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              pill(Icons.email_rounded, 'Email', () => _launchEmail(email), solid: true),
              if (hasPhone) ...[
                const SizedBox(width: 10),
                pill(Icons.call_rounded, 'Call', () => _launchCall(phone), solid: false),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarFallback() {
    return Container(
      color: _soft,
      child: Center(
        child: Icon(
          Icons.person_rounded,
          color: _navy,
          size: 38,
        ),
      ),
    );
  }

  Widget _buildContactCard({
    required String email,
    required String phone,
    required String cabin,
    required String school,
    required String designation,
  }) {
    return NexusCard(
      variant: NexusCardVariant.standard,
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          _buildInfoRow(
            icon: Icons.email_outlined,
            iconColor: _blue,
            label: 'Email Address',
            value: email,
            actionIcon: Icons.copy_rounded,
            onAction: () => _copyToClipboard(email, 'Email address'),
          ),
          Divider(height: 20, color: _line),
          _buildInfoRow(
            icon: Icons.phone_outlined,
            iconColor: _green,
            label: 'Mobile Number',
            value: phone,
            actionIcon: phone != 'Not Available' ? Icons.copy_rounded : null,
            onAction: phone != 'Not Available' ? () => _copyToClipboard(phone, 'Phone number') : null,
          ),
          Divider(height: 20, color: _line),
          _buildInfoRow(
            icon: Icons.meeting_room_outlined,
            iconColor: _orange,
            label: 'Cabin / Office',
            value: cabin,
            actionIcon: Icons.copy_rounded,
            onAction: () => _copyToClipboard(cabin, 'Cabin location'),
          ),
          Divider(height: 20, color: _line),
          _buildInfoRow(
            icon: Icons.school_outlined,
            iconColor: _navy,
            label: 'School / Department',
            value: school,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    IconData? actionIcon,
    VoidCallback? onAction,
  }) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 19),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _muted,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.dmSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
            ],
          ),
        ),
        if (actionIcon != null && onAction != null)
          IconButton(
            icon: Icon(actionIcon, size: 18, color: _inkSoft),
            onPressed: onAction,
            tooltip: 'Copy',
          ),
      ],
    );
  }

  Widget _buildGuidelinesCard() {
    return NexusCard(
      variant: NexusCardVariant.standard,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 18, color: _navy),
              const SizedBox(width: 8),
              Text(
                'Mentorship Responsibilities',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildBullet('Academic progress review & semester registration guidance.'),
          const SizedBox(height: 8),
          _buildBullet('Hostel outing & weekend leave approvals on VTOP.'),
          const SizedBox(height: 8),
          _buildBullet('Disciplinary counsel and university support coordination.'),
          const SizedBox(height: 8),
          _buildBullet('Contact during official office hours for meetings.'),
        ],
      ),
    );
  }

  Widget _buildBullet(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 6),
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            color: _orange,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.dmSans(
              fontSize: 12.5,
              color: _inkSoft,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonLoading() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          height: 180,
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _line),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          height: 240,
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _line),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorView(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: _red),
            const SizedBox(height: 16),
            Text(
              'Failed to load mentor details',
              style: GoogleFonts.dmSans(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              ErrorFormatter.format(error),
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(color: _muted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _navy,
                foregroundColor: _palette.isDark ? const Color(0xFF0F172A) : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => setState(() => _fetchMentor(forceRefresh: true)),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
