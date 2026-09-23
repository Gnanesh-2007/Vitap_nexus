import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/error_formatter.dart';

class FacultyScreen extends ConsumerStatefulWidget {
  const FacultyScreen({super.key});

  @override
  ConsumerState<FacultyScreen> createState() => _FacultyScreenState();
}

class _FacultyScreenState extends ConsumerState<FacultyScreen> {
  late Future<List<dynamic>> _facultyFuture;
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String _selectedSchool = 'All';

  // Editorial campus palette
  AppPalette get _palette => AppPalette.of(context);
  Color get _paper => _palette.paper;
  Color get _surface => _palette.surface;
  Color get _ink => _palette.ink;
  Color get _inkSoft => _palette.inkSoft;
  Color get _navy => _palette.navy;
  Color get _blue => _palette.blue;
  Color get _orange => _palette.orange;
  Color get _red => _palette.red;
  Color get _muted => _palette.inkMuted;
  Color get _line => _palette.line;
  Color get _soft => _palette.soft;

  @override
  void initState() {
    super.initState();
    _fetchFaculty();
  }

  void _fetchFaculty({bool forceRefresh = false}) {
    _facultyFuture = _getFacultyData(forceRefresh: forceRefresh);
  }

  Future<List<dynamic>> _getFacultyData({bool forceRefresh = false}) async {
    const cacheKey = 'faculty_directory';

    if (!forceRefresh) {
      final mem = StorageService.getMemoryCache(cacheKey);
      if (mem is List && mem.isNotEmpty) {
        return List<dynamic>.from(mem);
      }

      final disk = await StorageService.getCache(cacheKey);
      if (disk is List && disk.isNotEmpty) {
        return List<dynamic>.from(disk);
      }
    }

    final auth = ref.read(authProvider);

    try {
      final fresh = await apiService.fetchAllFaculty(
        username: auth.username ?? '',
        password: auth.password ?? '',
      );

      if (fresh.isNotEmpty) {
        await StorageService.setCache(cacheKey, fresh);
        return fresh;
      }
    } catch (e) {
      debugPrint('FacultyScreen: Network fetch failed ($e). Checking offline cache...');
      final fallback = StorageService.getMemoryCache(cacheKey) ??
          await StorageService.getCache(cacheKey);

      if (fallback is List && fallback.isNotEmpty) {
        return List<dynamic>.from(fallback);
      }

      rethrow;
    }

    final fallback = StorageService.getMemoryCache(cacheKey) ??
        await StorageService.getCache(cacheKey);

    if (fallback is List && fallback.isNotEmpty) {
      return List<dynamic>.from(fallback);
    }

    return [];
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _launchEmail(String email) async {
    try {
      final uri = Uri.parse('mailto:$email');
      final launched = await launchUrl(uri);
      if (!launched && mounted) {
        _showMessage('Could not open email app for $email');
      }
    } catch (_) {
      if (mounted) {
        _showMessage('Could not open email app for $email');
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    _showMessage('$label copied to clipboard');
  }

  void _showMessage(String message, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.dmSans(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: color ?? _navy,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  List<String> _extractSchools(List<dynamic> list) {
    final Set<String> schools = {'All'};
    for (final item in list) {
      if (item is Map) {
        final school = item['school_or_centre']?.toString().trim() ?? '';
        if (school.isNotEmpty && school != '-') {
          schools.add(school);
        }
      }
    }
    return schools.toList();
  }

  List<Map<String, dynamic>> _filterFaculty(List<dynamic> rawList) {
    final list = rawList.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    final query = _searchQuery.toLowerCase().trim();

    return list.where((item) {
      final name = item['faculty_name']?.toString().toLowerCase() ?? '';
      final empId = item['emp_id']?.toString().toLowerCase() ?? '';
      final designation = item['designation']?.toString().toLowerCase() ?? '';
      final school = item['school_or_centre']?.toString() ?? '';

      // School filter match
      if (_selectedSchool != 'All' && school != _selectedSchool) {
        return false;
      }

      // Search query match
      if (query.isEmpty) return true;

      return name.contains(query) ||
          empId.contains(query) ||
          designation.contains(query) ||
          school.toLowerCase().contains(query);
    }).toList();
  }

  String _getInitials(String name) {
    final cleaned = name.replaceAll(RegExp(r'^(Dr\.|Prof\.|Mr\.|Ms\.|Mrs\.)\s*', caseSensitive: false), '').trim();
    final parts = cleaned.split(' ').where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return 'F';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
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
            setState(() => _fetchFaculty(forceRefresh: true));
            await _facultyFuture;
          },
          child: FutureBuilder<List<dynamic>>(
            future: _facultyFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoading();
              }

              if (snapshot.hasError) {
                return _buildError(snapshot.error!);
              }

              final allList = snapshot.data ?? [];
              final filteredList = _filterFaculty(allList);
              final schools = _extractSchools(allList);

              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  // App Bar / Header
                  SliverToBoxAdapter(
                    child: _buildHeader(allList.length),
                  ),

                  // Search Bar & Filter Chips
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSearchBar(),
                          const SizedBox(height: 12),
                          if (schools.length > 2)
                            _buildSchoolFilterChips(schools),
                        ],
                      ),
                    ),
                  ),

                  // Faculty Cards List
                  if (filteredList.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptySearch(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final faculty = filteredList[index];
                            return _buildFacultyCard(faculty, index);
                          },
                          childCount: filteredList.length,
                        ),
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

  Widget _buildHeader(int totalCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.arrow_back_rounded, size: 24, color: _ink),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Faculty Directory',
                  style: GoogleFonts.dmSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                    letterSpacing: -0.4,
                  ),
                ),
                if (totalCount > 0)
                  Text(
                    '$totalCount faculty members',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _muted,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _fetchFaculty(forceRefresh: true)),
            icon: Icon(Icons.refresh_rounded, size: 22, color: _ink),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 20, color: _muted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: GoogleFonts.dmSans(fontSize: 13.5, color: _ink),
              decoration: InputDecoration(
                hintText: 'Search by faculty name, designation, or ID...',
                hintStyle: GoogleFonts.dmSans(fontSize: 12.5, color: _muted),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              child: Icon(Icons.close_rounded, size: 18, color: _muted),
            ),
        ],
      ),
    );
  }

  Widget _buildSchoolFilterChips(List<String> schools) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: schools.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final school = schools[index];
          final isSelected = _selectedSchool == school;

          return InkWell(
            onTap: () => setState(() => _selectedSchool = school),
            borderRadius: BorderRadius.circular(17),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? _navy : _surface,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(
                  color: isSelected ? _navy : _line,
                  width: 1.2,
                ),
              ),
              child: Center(
                child: Text(
                  school,
                  style: GoogleFonts.dmSans(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected ? Colors.white : _inkSoft,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFacultyCard(Map<String, dynamic> faculty, int index) {
    final name = faculty['faculty_name']?.toString() ?? 'Faculty Member';
    final designation = faculty['designation']?.toString() ?? '-';
    final school = faculty['school_or_centre']?.toString() ?? '-';
    final empId = faculty['emp_id']?.toString() ?? '';
    final initials = _getInitials(name);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _openFacultyDetailsModal(faculty),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _line),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _blue,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.dmSans(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    if (designation != '-' && designation.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        designation,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _inkSoft,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),

                    // Badges row
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (school != '-' && school.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: _soft,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              school,
                              style: GoogleFonts.dmSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _inkSoft,
                              ),
                            ),
                          ),
                        if (empId.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: _orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'EMP: $empId',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: _orange,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: _muted,
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate(delay: (20 * (index % 10)).ms).fadeIn(duration: 250.ms).slideY(begin: 0.04, end: 0);
  }

  void _openFacultyDetailsModal(Map<String, dynamic> faculty) {
    final empId = faculty['emp_id']?.toString() ?? '';
    final initialName = faculty['faculty_name']?.toString() ?? 'Faculty Member';
    final initialDesig = faculty['designation']?.toString() ?? '-';
    final initialSchool = faculty['school_or_centre']?.toString() ?? '-';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalCtx) {
        return _FacultyDetailsSheet(
          empId: empId,
          initialName: initialName,
          initialDesignation: initialDesig,
          initialSchool: initialSchool,
          onLaunchEmail: _launchEmail,
          onCopy: _copyToClipboard,
        );
      },
    );
  }

  Widget _buildEmptySearch() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: _soft,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person_search_rounded, size: 28, color: _muted),
            ),
            const SizedBox(height: 16),
            Text(
              'No faculty members found',
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try changing your search terms or filter selection.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: _muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: _navy,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading faculty directory...',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _inkSoft,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.error_outline_rounded, color: _red, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to load faculty',
              style: GoogleFonts.dmSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              ErrorFormatter.format(error, fallback: 'Failed to retrieve faculty list.'),
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(fontSize: 12, color: _muted),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => setState(() => _fetchFaculty(forceRefresh: true)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _navy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(
                'Retry',
                style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// FACULTY DETAILS BOTTOM SHEET
// ============================================================

class _FacultyDetailsSheet extends ConsumerStatefulWidget {
  final String empId;
  final String initialName;
  final String initialDesignation;
  final String initialSchool;
  final Function(String) onLaunchEmail;
  final Function(String, String) onCopy;

  const _FacultyDetailsSheet({
    required this.empId,
    required this.initialName,
    required this.initialDesignation,
    required this.initialSchool,
    required this.onLaunchEmail,
    required this.onCopy,
  });

  @override
  ConsumerState<_FacultyDetailsSheet> createState() => _FacultyDetailsSheetState();
}

class _FacultyDetailsSheetState extends ConsumerState<_FacultyDetailsSheet> {
  late Future<Map<String, dynamic>> _detailsFuture;

  AppPalette get _palette => AppPalette.of(context);
  Color get _paper => _palette.paper;
  Color get _ink => _palette.ink;
  Color get _inkSoft => _palette.inkSoft;
  Color get _navy => _palette.navy;
  Color get _blue => _palette.blue;
  Color get _orange => _palette.orange;
  Color get _muted => _palette.inkMuted;
  Color get _line => _palette.line;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  void _fetchDetails() {
    final auth = ref.read(authProvider);
    _detailsFuture = apiService.fetchFacultyDetails(
      username: auth.username ?? '',
      password: auth.password ?? '',
      empId: widget.empId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Title
              Text(
                'Faculty Profile',
                style: GoogleFonts.dmSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 16),

              FutureBuilder<Map<String, dynamic>>(
                future: _detailsFuture,
                builder: (context, snapshot) {
                  final details = snapshot.data ?? {};
                  final isLoading = snapshot.connectionState == ConnectionState.waiting;

                  final name = details['name']?.toString().isNotEmpty == true
                      ? details['name'].toString()
                      : widget.initialName;
                  final designation = details['designation']?.toString().isNotEmpty == true
                      ? details['designation'].toString()
                      : widget.initialDesignation;
                  final department = details['department']?.toString().isNotEmpty == true
                      ? details['department'].toString()
                      : (details['school_centre']?.toString().isNotEmpty == true
                          ? details['school_centre'].toString()
                          : widget.initialSchool);
                  final email = details['email']?.toString() ?? '';
                  final cabin = details['cabin_number']?.toString() ?? '';
                  final officeHours = (details['office_hours'] as List<dynamic>?) ?? [];

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Profile Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _paper,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: _line),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: _navy.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.person_rounded,
                                  color: _navy,
                                  size: 28,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: GoogleFonts.dmSans(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: _ink,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    designation,
                                    style: GoogleFonts.dmSans(
                                      fontSize: 12,
                                      color: _inkSoft,
                                    ),
                                  ),
                                  if (widget.empId.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'ID: ${widget.empId}',
                                      style: GoogleFonts.spaceGrotesk(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: _orange,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Quick Contact Action Buttons
                      if (email.isNotEmpty)
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  widget.onLaunchEmail(email);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _navy,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                icon: const Icon(Icons.mail_outline_rounded, size: 18),
                                label: Text(
                                  'Send Email',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            IconButton.filledTonal(
                              onPressed: () => widget.onCopy(email, 'Email address'),
                              icon: const Icon(Icons.copy_rounded, size: 18),
                              tooltip: 'Copy Email',
                            ),
                          ],
                        ),

                      if (email.isNotEmpty) const SizedBox(height: 16),

                      // Section Title
                      Text(
                        'FACULTY INFORMATION',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _muted,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 10),

                      _buildDetailTile(Icons.alternate_email_rounded, 'Official Email', email.isNotEmpty ? email : (isLoading ? 'Loading...' : 'Not listed')),
                      _buildDetailTile(Icons.meeting_room_outlined, 'Cabin Number', cabin.isNotEmpty ? cabin : (isLoading ? 'Loading...' : 'Not listed')),
                      _buildDetailTile(Icons.domain_outlined, 'Department / School', department.isNotEmpty ? department : '-'),
                      if (widget.empId.isNotEmpty)
                        _buildDetailTile(Icons.badge_outlined, 'Employee ID', widget.empId),

                      const SizedBox(height: 18),

                      // Section: Office Hours
                      Text(
                        'WEEKLY OFFICE / OPEN HOURS',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: _muted,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 10),

                      if (isLoading)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: _navy),
                            ),
                          ),
                        )
                      else if (officeHours.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _paper,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _line),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline_rounded, size: 18, color: _muted),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'No specific open hours registered in VTOP for this faculty.',
                                  style: GoogleFonts.dmSans(fontSize: 12, color: _inkSoft),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ...officeHours.map((slot) {
                          final day = slot['day']?.toString() ?? '';
                          final timings = slot['timings']?.toString() ?? '';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                            decoration: BoxDecoration(
                              color: _paper,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _line),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _blue.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    day,
                                    style: GoogleFonts.spaceGrotesk(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: _blue,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    timings,
                                    style: GoogleFonts.dmSans(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: _ink,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailTile(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _paper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _navy),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _muted,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
