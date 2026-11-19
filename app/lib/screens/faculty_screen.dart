import 'dart:convert';
import 'package:flutter/material.dart';
import '../widgets/nexus_app_bar.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class FacultyScreen extends ConsumerStatefulWidget {
  const FacultyScreen({super.key});

  @override
  ConsumerState<FacultyScreen> createState() => _FacultyScreenState();
}

class _FacultyScreenState extends ConsumerState<FacultyScreen> {
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = false;
  List<dynamic> _allFaculties = [];
  List<dynamic> _filteredFaculties = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _initFacultyDirectory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<dynamic>? _readFromMemory(String? username) {
    final candidates = [
      StorageService.getMemoryCache('faculty_permanent', username: username),
      StorageService.getMemoryCache('faculty_directory', username: username),
      StorageService.getMemoryCache('faculty', username: username),
      StorageService.getMemoryCache('faculty_permanent', username: 'GLOBAL'),
      StorageService.getMemoryCache('faculty_directory', username: 'GLOBAL'),
      StorageService.getMemoryCache('faculty', username: 'GLOBAL'),
    ];
    for (final c in candidates) {
      if (c is List && c.isNotEmpty) {
        return List<dynamic>.from(c);
      }
    }
    return null;
  }

  Future<List<dynamic>?> _readFromDisk(String? username) async {
    final candidates = [
      await StorageService.getCache('faculty_permanent', username: username),
      await StorageService.getCache('faculty_directory', username: username),
      await StorageService.getCache('faculty', username: username),
      await StorageService.getCache('faculty_permanent', username: 'GLOBAL'),
      await StorageService.getCache('faculty_directory', username: 'GLOBAL'),
      await StorageService.getCache('faculty', username: 'GLOBAL'),
    ];
    for (final c in candidates) {
      if (c is List && c.isNotEmpty) {
        return List<dynamic>.from(c);
      }
    }
    return null;
  }

  Future<void> _savePermanently(List<dynamic> list, String? username) async {
    if (list.isEmpty) return;
    if (username != null && username.isNotEmpty) {
      await StorageService.setCache('faculty', list, username: username);
      await StorageService.setCache(
        'faculty_directory',
        list,
        username: username,
      );
      await StorageService.setCache(
        'faculty_permanent',
        list,
        username: username,
      );
    }
    await StorageService.setCache('faculty', list, username: 'GLOBAL');
    await StorageService.setCache(
      'faculty_directory',
      list,
      username: 'GLOBAL',
    );
    await StorageService.setCache(
      'faculty_permanent',
      list,
      username: 'GLOBAL',
    );
  }

  List<dynamic> _sortFaculties(List<dynamic> raw) {
    final copy = List<dynamic>.from(raw);
    copy.sort((a, b) {
      final nameA = ((a is Map ? (a['name'] ?? a['faculty_name']) : '') ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final nameB = ((b is Map ? (b['name'] ?? b['faculty_name']) : '') ?? '')
          .toString()
          .trim()
          .toLowerCase();
      return nameA.compareTo(nameB);
    });
    return copy;
  }

  Future<void> _initFacultyDirectory() async {
    final auth = ref.read(authProvider);
    final username = auth.username ?? StorageService.currentUsername;

    // 1. Instant 0ms memory check
    final mem = _readFromMemory(username);
    if (mem != null && mem.isNotEmpty) {
      final sorted = _sortFaculties(mem);
      setState(() {
        _allFaculties = sorted;
        _filteredFaculties = sorted;
        _isLoading = false;
      });
      return;
    }

    // 2. Permanent disk cache check
    final disk = await _readFromDisk(username);
    if (disk != null && disk.isNotEmpty) {
      final sorted = _sortFaculties(disk);
      await _savePermanently(sorted, username);
      if (!mounted) return;
      setState(() {
        _allFaculties = sorted;
        _filteredFaculties = sorted;
        _isLoading = false;
      });
      return;
    }

    // 3. Instant bundled offline faculty_list.json seed (700+ VIT-AP faculties in <5ms)
    try {
      final bundledRaw = await rootBundle.loadString('assets/faculty_list.json');
      final decoded = jsonDecode(bundledRaw);
      if (decoded is List && decoded.isNotEmpty) {
        final sorted = _sortFaculties(decoded);
        await _savePermanently(sorted, username);
        if (!mounted) return;
        setState(() {
          _allFaculties = sorted;
          _filteredFaculties = sorted;
          _isLoading = false;
        });
        return;
      }
    } catch (_) {}

    // 4. Network fetch if never cached before
    await _loadAllFaculty(forceRefresh: true);
  }

  Future<void> _loadAllFaculty({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = _allFaculties.isEmpty;
      _error = null;
    });

    try {
      final authState = ref.read(authProvider);
      final creds = await StorageService.getCredentials();
      final username = authState.username ?? creds['username'] ?? '';
      final password = authState.password ?? creds['password'] ?? '';

      if (username.isEmpty || password.isEmpty) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          if (_allFaculties.isEmpty) {
            _error = 'Please log in to load the faculty directory.';
          }
        });
        return;
      }

      List<dynamic> results = await apiService.fetchAllFaculty(
        username: username,
        password: password,
      );

      if (results.isEmpty) {
        final searchMap = await apiService.searchFaculty(
          username: username,
          password: password,
          searchTerm: 'a',
        );
        if (searchMap['results'] is List) {
          results = List<dynamic>.from(searchMap['results'] as List);
        }
      }

      if (results.isNotEmpty) {
        final sorted = _sortFaculties(results);
        await _savePermanently(sorted, username);
        if (!mounted) return;
        setState(() {
          _allFaculties = sorted;
          _isLoading = false;
        });
        _filterFaculties(_searchController.text);
      } else {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          if (_allFaculties.isEmpty) {
            _error = 'No faculty profiles returned from VTOP. Pull to retry.';
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (_allFaculties.isEmpty) {
          _error = 'Unable to load faculty directory right now. Pull to retry.';
        }
      });
    }
  }

  void _filterFaculties(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() {
        _filteredFaculties = _allFaculties;
      });
      return;
    }

    setState(() {
      _filteredFaculties = _allFaculties.where((fac) {
        if (fac is! Map) return false;
        final name = (fac['name'] ?? fac['faculty_name'] ?? '')
            .toString()
            .toLowerCase();
        final desig = (fac['designation'] ?? '').toString().toLowerCase();
        final school = (fac['school'] ?? fac['department'] ?? '')
            .toString()
            .toLowerCase();
        final empId = (fac['emp_id'] ?? '').toString().toLowerCase();
        final cabin = (fac['cabin'] ?? fac['cabin_number'] ?? '')
            .toString()
            .toLowerCase();
        return name.contains(q) ||
            desig.contains(q) ||
            school.contains(q) ||
            empId.contains(q) ||
            cabin.contains(q);
      }).toList();
    });
  }

  void _showFacultyDetailsSheet(Map<String, dynamic> facultySummary) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FacultyDetailsSheet(facultySummary: facultySummary),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Scaffold(
      backgroundColor: palette.paper,
      body: SafeArea(
        child: Column(
          children: [
            const NexusAppBar(title: 'Faculty', subtitle: 'Find and contact faculty'),

            // Search bar: Rounded stadium outline styled with AppPalette
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: palette.line,
                    width: 1.2,
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _filterFaculties,
                  style: GoogleFonts.dmSans(
                    color: palette.ink,
                    fontSize: 15,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search faculty...',
                    hintStyle: GoogleFonts.dmSans(
                      color: palette.inkMuted,
                      fontSize: 15,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: palette.inkMuted,
                      size: 22,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              color: palette.inkMuted,
                              size: 19,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              _filterFaculties('');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                  ),
                ),
              ),
            ),

            // Faculty list
            Expanded(
              child: RefreshIndicator(
                color: palette.blue,
                backgroundColor: palette.surface,
                onRefresh: () => _loadAllFaculty(forceRefresh: true),
                child: _buildListBody(palette),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListBody(AppPalette palette) {
    if (_isLoading && _allFaculties.isEmpty) {
      return Center(child: CircularProgressIndicator(color: palette.blue));
    }

    if (_error != null && _allFaculties.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 80),
        children: [
          Icon(
            Icons.people_outline_rounded,
            size: 48,
            color: palette.inkMuted,
          ),
          const SizedBox(height: 16),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              color: palette.inkSoft,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: FilledButton.icon(
              onPressed: () => _loadAllFaculty(forceRefresh: true),
              style: FilledButton.styleFrom(backgroundColor: palette.blue),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Load Faculties'),
            ),
          ),
        ],
      );
    }

    if (_filteredFaculties.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 80),
        children: [
          Center(
            child: Text(
              'No matching faculty found.',
              style: GoogleFonts.dmSans(
                color: palette.inkMuted,
                fontSize: 15,
              ),
            ),
          ),
        ],
      );
    }

    final avatarAccents = [
      palette.blue,
      palette.green,
      palette.orange,
      palette.navy,
    ];

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: _filteredFaculties.length,
      itemBuilder: (context, index) {
        final raw = _filteredFaculties[index];
        if (raw is! Map) return const SizedBox.shrink();
        final fac = Map<String, dynamic>.from(raw);

        final name = (fac['name'] ?? fac['faculty_name'] ?? 'Unknown Faculty')
            .toString()
            .trim();
        final designation = (fac['designation'] ?? '').toString().trim();
        final school = (fac['school'] ?? fac['department'] ?? '')
            .toString()
            .trim();

        final initial = name.isNotEmpty ? name[0].toUpperCase() : 'F';
        final accent = avatarAccents[index % avatarAccents.length];

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Material(
            color: palette.surface,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
              side: BorderSide(color: palette.line),
            ),
            child: InkWell(
          onTap: () => _showFacultyDetailsSheet(fac),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: palette.isDark ? 0.22 : 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initial,
                    style: GoogleFonts.bricolageGrotesque(
                      color: accent,
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.bricolageGrotesque(
                          color: palette.ink,
                          fontSize: 17,
                          letterSpacing: -0.2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (designation.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          designation,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            color: palette.inkSoft,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      if (school.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          school,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            color: palette.inkMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
      },
    );
  }
}

class _FacultyDetailsSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> facultySummary;

  const _FacultyDetailsSheet({required this.facultySummary});

  @override
  ConsumerState<_FacultyDetailsSheet> createState() =>
      _FacultyDetailsSheetState();
}

class _FacultyDetailsSheetState extends ConsumerState<_FacultyDetailsSheet> {
  late Map<String, dynamic> _details;
  bool _isFetchingDetail = false;

  @override
  void initState() {
    super.initState();
    _details = Map<String, dynamic>.from(widget.facultySummary);
    _loadOrFetchDetail();
  }

  Future<void> _loadOrFetchDetail() async {
    final empId = (_details['emp_id'] ?? '').toString().trim();
    if (empId.isEmpty) return;

    final auth = ref.read(authProvider);
    final username = auth.username ?? StorageService.currentUsername;
    final detailKey = 'faculty_detail_$empId';

    // 1. Check permanent memory/disk cache for this faculty's detailed profile
    final cached =
        StorageService.getMemoryCache(detailKey, username: username) ??
        StorageService.getMemoryCache(detailKey, username: 'GLOBAL') ??
        await StorageService.getCache(detailKey, username: username) ??
        await StorageService.getCache(detailKey, username: 'GLOBAL');

    if (cached is Map && cached.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _details = {..._details, ...Map<String, dynamic>.from(cached)};
      });
      return;
    }

    // 2. If email/cabin are already populated in summary, cache & return
    final hasCabin =
        (_details['cabin_number'] ?? _details['cabin'] ?? '')
            .toString()
            .trim()
            .isNotEmpty;
    final hasEmail = (_details['email'] ?? '').toString().trim().isNotEmpty;
    if (hasCabin && hasEmail) {
      await StorageService.setCache(detailKey, _details, username: 'GLOBAL');
      if (username != null) {
        await StorageService.setCache(detailKey, _details, username: username);
      }
      return;
    }

    // 3. Fetch full detail from VTOP and permanently cache it
    final creds = await StorageService.getCredentials();
    final u = auth.username ?? creds['username'] ?? '';
    final p = auth.password ?? creds['password'] ?? '';
    if (u.isEmpty || p.isEmpty) return;

    if (mounted) {
      setState(() => _isFetchingDetail = true);
    }

    try {
      final fetched = await apiService.fetchFacultyDetails(
        username: u,
        password: p,
        empId: empId,
      );
      if (fetched.isNotEmpty) {
        final merged = {..._details, ...fetched};
        await StorageService.setCache(detailKey, merged, username: 'GLOBAL');
        await StorageService.setCache(detailKey, merged, username: u);
        if (mounted) {
          setState(() {
            _details = merged;
            _isFetchingDetail = false;
          });
        }
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isFetchingDetail = false);
    }
  }

  String _pickField(List<String> keys, {String fallback = 'N/A'}) {
    for (final k in keys) {
      final v = _details[k];
      if (v != null) {
        if (v is List) {
          if (v.isEmpty) continue;
          final joined = v
              .map((item) {
                if (item is Map) {
                  return item.values
                      .map((e) => e?.toString().trim() ?? '')
                      .where((s) => s.isNotEmpty)
                      .join(' - ');
                }
                return item.toString().trim();
              })
              .where((s) => s.isNotEmpty)
              .join('\n');
          if (joined.isNotEmpty) return joined;
        } else {
          final str = v.toString().trim();
          if (str.isNotEmpty && str.toLowerCase() != 'null') {
            return str;
          }
        }
      }
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    final name = _pickField([
      'name',
      'faculty_name',
      'Name of the Faculty',
    ], fallback: 'Faculty Member');
    final designation = _pickField(['designation', 'Designation']);
    final department = _pickField([
      'department',
      'Name of the Department',
      'Department',
    ]);
    final school = _pickField([
      'school',
      'School / Centre Name',
      'School',
      'centre',
    ]);
    final email = _pickField(['email', 'E-Mail Id', 'Email']);
    final cabin = _pickField([
      'cabin_number',
      'cabin',
      'Cabin Number',
      'room_number',
    ]);
    final openHours = _pickField([
      'open_hours',
      'Open Hours',
      'office_hours',
    ], fallback: 'N/A');

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        24,
        28,
        24,
        28 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
        border: Border(top: BorderSide(color: palette.line, width: 1.2)),
        boxShadow: palette.elevatedShadow,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: GoogleFonts.bricolageGrotesque(
                      color: palette.ink,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                ),
                if (_isFetchingDetail)
                  Padding(
                    padding: const EdgeInsets.only(left: 12, top: 4),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: palette.blue,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 22),

            _buildSection(
              title: 'Designation',
              value: designation,
              palette: palette,
            ),
            const SizedBox(height: 16),

            _buildSection(
              title: 'Department',
              value: department,
              palette: palette,
            ),
            const SizedBox(height: 16),

            _buildSection(
              title: 'School',
              value: school,
              palette: palette,
            ),
            const SizedBox(height: 16),

            _buildSection(
              title: 'Email',
              value: email,
              palette: palette,
              isLink: email != 'N/A',
              onTap: email != 'N/A'
                  ? () {
                      Clipboard.setData(ClipboardData(text: email));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Copied $email to clipboard'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  : null,
            ),
            const SizedBox(height: 16),

            _buildSection(
              title: 'Cabin Number',
              value: cabin,
              palette: palette,
            ),
            const SizedBox(height: 16),

            _buildSection(
              title: 'Open Hours:',
              value: openHours,
              palette: palette,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String value,
    required AppPalette palette,
    bool isLink = false,
    VoidCallback? onTap,
  }) {
    final valueWidget = Text(
      value,
      style: GoogleFonts.dmSans(
        color: isLink ? palette.blue : palette.inkSoft,
        fontSize: 14.5,
        fontWeight: isLink ? FontWeight.w600 : FontWeight.w400,
        height: 1.35,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.bricolageGrotesque(
            color: palette.ink,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        onTap != null
            ? GestureDetector(onTap: onTap, child: valueWidget)
            : valueWidget,
      ],
    );
  }
}
