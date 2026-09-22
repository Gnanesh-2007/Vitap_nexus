import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/error_formatter.dart';

class MentorScreen extends ConsumerStatefulWidget {
  const MentorScreen({super.key});

  @override
  ConsumerState<MentorScreen> createState() => _MentorScreenState();
}

class _MentorScreenState extends ConsumerState<MentorScreen> {
  late Future<Map<String, dynamic>> _mentorFuture;

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
    _fetchMentor();
  }

  void _fetchMentor({bool forceRefresh = false}) {
    _mentorFuture = _getMentorData(forceRefresh: forceRefresh);
  }

  Future<Map<String, dynamic>> _getMentorData({
    bool forceRefresh = false,
  }) async {
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
      debugPrint(
        'MentorScreen: Network fetch failed ($e). '
        'Checking offline cache...',
      );

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
    try {
      final uri = Uri.parse('mailto:$email');
      final launched = await launchUrl(uri);

      if (!launched && mounted) {
        _showMessage('Could not open email client for $email');
      }
    } catch (_) {
      if (mounted) {
        _showMessage('Could not open email client for $email');
      }
    }
  }

  Future<void> _launchCall(String phone) async {
    try {
      final uri = Uri.parse('tel:$phone');
      final launched = await launchUrl(uri);

      if (!launched && mounted) {
        _showMessage('Could not dial $phone');
      }
    } catch (_) {
      if (mounted) {
        _showMessage('Could not dial $phone');
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.dmSans(fontSize: 12),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _navy,
      ),
    );
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
            setState(() => _fetchMentor(forceRefresh: true));
            await _mentorFuture;
          },
          child: FutureBuilder<Map<String, dynamic>>(
            future: _mentorFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoading();
              }

              if (snapshot.hasError) {
                return _buildError(snapshot.error!);
              }

              final mentor = snapshot.data ?? {};

              final name =
                  mentor['faculty_name'] ?? mentor['name'] ?? 'Faculty Mentor';
              final email = mentor['faculty_email'] ??
                  mentor['email'] ??
                  'Not Available';
              final phone = mentor['faculty_mobile_number'] ??
                  mentor['mobile'] ??
                  'Not Available';
              final cabin =
                  mentor['cabin'] ?? mentor['faculty_cabin'] ?? 'Faculty Block';
              final designation = mentor['faculty_designation'] ??
                  mentor['designation'] ??
                  'Professor / Proctor';
              final school = mentor['school'] ??
                  mentor['faculty_department'] ??
                  'School of Computer Science & Engineering';

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
                        _buildProfileCard(
                          name: name.toString(),
                          designation: designation.toString(),
                          school: school.toString(),
                        ),
                        const SizedBox(height: 14),
                        _buildContactActions(
                          email: email.toString(),
                          phone: phone.toString(),
                        ),
                        const SizedBox(height: 28),
                        _buildSectionTitle(),
                        const SizedBox(height: 11),
                        _buildDetailTile(
                          Icons.person_outline_rounded,
                          'FULL NAME',
                          name.toString(),
                        ),
                        _buildDetailTile(
                          Icons.alternate_email_rounded,
                          'OFFICIAL EMAIL',
                          email.toString(),
                        ),
                        _buildDetailTile(
                          Icons.phone_outlined,
                          'MOBILE NUMBER',
                          phone.toString(),
                        ),
                        _buildDetailTile(
                          Icons.meeting_room_outlined,
                          'CABIN / OFFICE',
                          cabin.toString(),
                        ),
                        _buildDetailTile(
                          Icons.domain_outlined,
                          'DEPARTMENT / SCHOOL',
                          school.toString(),
                        ),
                        const SizedBox(height: 8),
                        _buildNote(),
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
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 17),
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
                  style: GoogleFonts.spaceGrotesk(
                    color: _orange,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.05,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Faculty Mentor',
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
            onTap: () => setState(() => _fetchMentor(forceRefresh: true)),
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

  Widget _buildProfileCard({
    required String name,
    required String designation,
    required String school,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _navy,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x17172B4D),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .07),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFF2B35B),
                width: 1.5,
              ),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Color(0xFFF2B35B),
              size: 36,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FACULTY MENTOR / PROCTOR',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white54,
                    fontSize: 7.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.08,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  designation,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    color: const Color(0xFF8CB9FF),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  school,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    color: Colors.white54,
                    fontSize: 10.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactActions({
    required String email,
    required String phone,
  }) {
    final hasEmail = email.contains('@');
    final hasPhone = phone != 'Not Available' && phone.trim().isNotEmpty;

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: hasEmail ? () => _launchEmail(email) : null,
              icon: const Icon(Icons.email_outlined, size: 17),
              label: Text(
                'Email Mentor',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _soft,
                disabledForegroundColor: _muted,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
        if (hasPhone) ...[
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => _launchCall(phone),
                icon: const Icon(
                  Icons.phone_outlined,
                  size: 17,
                  color: _green,
                ),
                label: Text(
                  'Call',
                  style: GoogleFonts.dmSans(
                    color: _green,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: _surface,
                  side: const BorderSide(color: Color(0xFFB8DCCF)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSectionTitle() {
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
            Icons.badge_outlined,
            color: _blue,
            size: 16,
          ),
        ),
        const SizedBox(width: 9),
        Text(
          'MENTOR INFORMATION',
          style: GoogleFonts.spaceGrotesk(
            color: _ink,
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailTile(
    IconData icon,
    String label,
    String value,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          Container(
            width: 37,
            height: 37,
            decoration: BoxDecoration(
              color: _soft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 18,
              color: _navy,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.spaceGrotesk(
                    color: _muted,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .75,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    color: _ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNote() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF9ECE7),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFE8C9BD)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: _orange,
            size: 17,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Use the contact actions above to reach your assigned faculty mentor.',
              style: GoogleFonts.dmSans(
                color: _muted,
                fontSize: 11,
                height: 1.4,
              ),
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
            'Loading mentor details...',
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
                    'Failed to Load Mentor Details',
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
                      fallback: 'Unable to load mentor details. Please check your connection and try again.',
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
                      setState(() => _fetchMentor(forceRefresh: true));
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
