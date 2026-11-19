import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/vtop_providers.dart';
import '../services/biometric_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/nexus_app_bar.dart';
import '../widgets/widget_character_sheet.dart';
import 'cgpa_calculator_screen.dart';
import 'diagnostics_screen.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';
import 'vtop_webview_screen.dart';

// ============================================================================
// PROFILE & ACCOUNT SCREEN (Faithfully matches vitap_student_app_ref)
// ============================================================================

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isPrivacyEnabled = false;
  bool _isSyncing = false;
  bool _biometricEnabled = false;
  String? _appLockPin;
  String? _customAvatarPath;
  List<Map<String, dynamic>> _localSemesters = [];

  static const List<String> _avatarAssets = [
    'assets/images/pfp/man.png',
    'assets/images/pfp/man_1.png',
    'assets/images/pfp/woman.png',
    'assets/images/pfp/woman_1.png',
    'assets/images/pfp/astronaut.png',
    'assets/images/pfp/ninja.png',
    'assets/images/pfp/masked.png',
    'assets/images/pfp/cat.png',
    'assets/images/pfp/dog.png',
    'assets/images/pfp/panda.png',
    'assets/images/pfp/bear.png',
    'assets/images/pfp/duck.png',
    'assets/images/pfp/chicken.png',
    'assets/images/pfp/default.png',
  ];

  @override
  void initState() {
    super.initState();
    _isPrivacyEnabled = StorageService.isPrivacyModeEnabledSync();
    _biometricEnabled = StorageService.isBiometricEnabledSync();
    _appLockPin = StorageService.getAppLockPinSync();
    _customAvatarPath = StorageService.getCustomAvatarPathSync();
    _loadLocalSemesters();
  }

  Future<void> _loadLocalSemesters() async {
    final sems = await StorageService.getAvailableSemesters();
    if (mounted && sems.isNotEmpty) {
      setState(() => _localSemesters = sems);
    }
  }

  void _togglePrivacyMode(bool val) {
    setState(() => _isPrivacyEnabled = val);
    StorageService.setPrivacyModeEnabled(val);
  }

  Future<void> _handleSync() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    final cs = Theme.of(context).colorScheme;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final auth = ref.read(authProvider);
      final user = auth.username ?? StorageService.currentUsername;
      if (user != null) {
        await StorageService.removeCache('profile', username: user);
      }
      ref.invalidate(profileProvider);
      ref.invalidate(allDataProvider);
      await Future.wait([
        ref.refresh(profileProvider.future),
        ref.read(dashboardProvider.notifier).syncAll(isUserInitiated: true),
      ]);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: cs.primary,
            content: Text(
              'Profile and academic data synced!',
              style: TextStyle(color: cs.onPrimary),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: cs.error,
            content: Text(
              'Offline: showing cached profile.',
              style: TextStyle(color: cs.onError),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _toggleBiometrics(bool enable) async {
    final cs = Theme.of(context).colorScheme;
    final messenger = ScaffoldMessenger.of(context);
    final available = await BiometricService.isBiometricAvailable();
    if (!available && enable) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: cs.error,
          content: Text(
            'No biometric hardware enrolled on this device. Use App PIN below.',
            style: TextStyle(color: cs.onError),
          ),
        ),
      );
      return;
    }

    if (available) {
      final verified = await BiometricService.authenticate(
        title: enable ? 'Enable Biometric Lock' : 'Disable Biometric Lock',
        subtitle: 'Verify with fingerprint or face unlock',
      );
      if (!verified || !mounted) return;
    }

    await StorageService.setBiometricEnabled(enable);
    if (!mounted) return;
    setState(() => _biometricEnabled = enable);
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: cs.primary,
        content: Text(
          enable ? 'Biometric Lock enabled!' : 'Biometric Lock disabled.',
          style: TextStyle(color: cs.onPrimary),
        ),
      ),
    );
  }

  Future<void> _showAppPinDialog() async {
    final cs = Theme.of(context).colorScheme;
    final pinCtrl = TextEditingController(text: _appLockPin ?? '');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
      ),
      builder: (sheetCtx) {
        final bottomInset = MediaQuery.of(sheetCtx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'App Security PIN',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Set a 4-8 digit fallback PIN to unlock VITAP Nexus when opening the app.',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pinCtrl,
                autofocus: true,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'Enter 4-8 digit PIN',
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  if (_appLockPin != null) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          await StorageService.setAppLockPin(null);
                          if (mounted) setState(() => _appLockPin = null);
                          if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: cs.error,
                          side: BorderSide(color: cs.error),
                        ),
                        child: const Text('Remove PIN'),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        final val = pinCtrl.text.trim();
                        if (val.length < 4) return;
                        await StorageService.setAppLockPin(val);
                        if (mounted) setState(() => _appLockPin = val);
                        if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                      },
                      child: const Text('Save PIN'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showLogoutDialog() {
    final cs = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text(
          'Are you sure you want to log out of VITAP Nexus? Your offline cached data will be cleared.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(authProvider.notifier).logout();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: Text('Logout', style: TextStyle(color: cs.onError)),
          ),
        ],
      ),
    );
  }

  void _showAvatarPickerSheet(String? base64Pfp) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: cs.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose Avatar',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 180,
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                    ),
                    itemCount: _avatarAssets.length + (base64Pfp != null ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (base64Pfp != null && i == 0) {
                        return GestureDetector(
                          onTap: () async {
                            await StorageService.setCustomAvatarPath(null);
                            if (mounted) setState(() => _customAvatarPath = null);
                            if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                          },
                          child: CircleAvatar(
                            backgroundImage:
                                MemoryImage(base64Decode(base64Pfp)),
                          ),
                        );
                      }
                      final assetIdx = base64Pfp != null ? i - 1 : i;
                      final asset = _avatarAssets[assetIdx];
                      return GestureDetector(
                        onTap: () async {
                          await StorageService.setCustomAvatarPath(asset);
                          if (mounted) setState(() => _customAvatarPath = asset);
                          if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                        },
                        child: CircleAvatar(
                          backgroundImage: AssetImage(asset),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final themeMode = ref.watch(themeModeProvider);
    final isDarkMode = themeMode == ThemeMode.dark;
    final selectedSeedTheme = ref.watch(seedThemeProvider);
    final isAmoled = ref.watch(amoledModeProvider);

    final profileAsync = ref.watch(profileProvider);
    final allDataAsync = ref.watch(allDataProvider);
    final authState = ref.watch(authProvider);

    String cgpa = '—';
    String credits = '—';
    allDataAsync.whenData((data) {
      final gh = data['grade_history'] as Map<String, dynamic>?;
      if (gh != null) {
        cgpa = gh['cgpa']?.toString() ?? '—';
        credits = gh['credits_earned']?.toString().split('.').first ?? '—';
      }
    });

    final profileData = profileAsync.valueOrNull ??
        (StorageService.getMemoryCache('profile') as Map<String, dynamic>? ??
            <String, dynamic>{});

    final studentName = profileData['student_name'] ??
        profileData['name'] ??
        authState.username ??
        'Student';
    final regNo = authState.username ?? profileData['application_number'] ?? '';
    final base64Pfp = profileData['base64_pfp'] as String?;
    final activeSemName = authState.activeSemesterName ?? 'Select Semester';

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _handleSync,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
          children: [
            const SizedBox(height: 24),
            // TOP PROFILE CARD (Avatar + CGPA/Credits shape badges + Name + Semester)
            _ProfileCard(
              studentName: studentName.toString(),
              cgpa: cgpa,
              credits: credits,
              isPrivate: _isPrivacyEnabled,
              onTogglePrivacy: () => _togglePrivacyMode(!_isPrivacyEnabled),
              customAvatarPath: _customAvatarPath,
              base64Pfp: base64Pfp,
              activeSemName: activeSemName,
              onTapAvatar: () => _showAvatarPickerSheet(base64Pfp),
              onChangeSemester: () => _showSemesterSheet(),
            ),
            const SizedBox(height: 28),

            // SECTION 1: ACCOUNT
            MenuSection(
              label: 'Account',
              children: [
                MenuTile(
                  icon: Icons.person_outline_rounded,
                  title: 'Profile',
                  subtitle: 'Personal dossier, blood group & mentor',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ProfileDetailPage(
                          profileData: profileData,
                          regNo: regNo,
                          customAvatarPath: _customAvatarPath,
                          base64Pfp: base64Pfp,
                          onChangeAvatar: () =>
                              _showAvatarPickerSheet(base64Pfp),
                        ),
                      ),
                    );
                  },
                ),
                MenuTile(
                  icon: Icons.key_rounded,
                  title: 'Manage Credentials',
                  subtitle: 'Update VTOP password or switch semester',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ManageCredentialsPage(
                          authState: authState,
                          localSemesters: _localSemesters,
                        ),
                      ),
                    );
                  },
                ),
                MenuTile(
                  icon: Icons.sync_rounded,
                  title: 'Sync',
                  subtitle: 'Syncs latest data from VTOP.',
                  trailing: _isSyncing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                  onTap: _isSyncing ? null : _handleSync,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // SECTION 2: APPEARANCE & THEMES
            MenuSection(
              label: 'Appearance',
              children: [
                MenuTile(
                  icon: Icons.widgets_rounded,
                  title: 'Widget character',
                  subtitle: 'Naruto, your own anime pick, or none',
                  onTap: () => showWidgetCharacterSheet(context),
                ),
                MenuTile(
                  icon: isDarkMode
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                  title: 'Dark Mode',
                  trailing: Switch.adaptive(
                    value: isDarkMode,
                    onChanged: (val) {
                      ref
                          .read(themeModeProvider.notifier)
                          .setTheme(val ? ThemeMode.dark : ThemeMode.light);
                    },
                  ),
                ),
                if (isDarkMode)
                  MenuTile(
                    icon: Icons.brightness_medium_rounded,
                    title: 'AMOLED Mode',
                    subtitle: 'Pure black background in dark mode',
                    trailing: Switch.adaptive(
                      value: isAmoled,
                      onChanged: (val) {
                        ref.read(amoledModeProvider.notifier).setAmoledMode(val);
                      },
                    ),
                  ),
                // Horizontal Theme Picker Row with CircularThemeIndicator
                Material(
                  color: cs.surfaceContainer,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'App Theme',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 104,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: NexusSeedTheme.values.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(width: 14),
                            itemBuilder: (context, index) {
                              final theme = NexusSeedTheme.values[index];
                              final isSelected = theme == selectedSeedTheme;
                              return CircularThemeIndicator(
                                theme: theme,
                                isDarkMode: isDarkMode,
                                isSelected: isSelected,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  ref
                                      .read(seedThemeProvider.notifier)
                                      .setSeedTheme(theme);
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // SECTION 3: APP & SECURITY
            MenuSection(
              label: 'App & Security',
              children: [
                MenuTile(
                  icon: Icons.visibility_off_outlined,
                  title: 'Privacy Mode',
                  subtitle:
                      'When enabled, your CGPA and credits are hidden on this page.',
                  trailing: Switch.adaptive(
                    value: _isPrivacyEnabled,
                    onChanged: _togglePrivacyMode,
                  ),
                ),
                MenuTile(
                  icon: Icons.fingerprint_rounded,
                  title: 'Biometric Login & App Lock',
                  subtitle: _biometricEnabled
                      ? 'Biometric unlock active on launch'
                      : 'Require fingerprint or face unlock',
                  trailing: Switch.adaptive(
                    value: _biometricEnabled,
                    onChanged: _toggleBiometrics,
                  ),
                ),
                MenuTile(
                  icon: Icons.pin_outlined,
                  title: 'App Security PIN',
                  subtitle: _appLockPin != null
                      ? 'Custom 4-8 digit PIN is active'
                      : 'Set a quick PIN fallback to open the app',
                  onTap: _showAppPinDialog,
                ),
                MenuTile(
                  icon: Icons.calculate_outlined,
                  title: 'CGPA & GPA Calculator',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CgpaCalculatorScreen(),
                      ),
                    );
                  },
                ),
                MenuTile(
                  icon: Icons.public_rounded,
                  title: 'VTOP Web Portal',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const VtopWebViewScreen(),
                      ),
                    );
                  },
                ),
                MenuTile(
                  icon: Icons.speed_rounded,
                  title: 'System Diagnostics & Ping',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const DiagnosticsScreen(),
                      ),
                    );
                  },
                ),
                MenuTile(
                  icon: Icons.auto_awesome_outlined,
                  title: 'Replay Welcome Tour',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const OnboardingScreen(isReplay: true),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // SECTION 4: ACTIONS
            MenuSection(
              label: 'Actions',
              children: [
                MenuTile(
                  icon: Icons.logout_rounded,
                  title: 'Logout',
                  foreground: cs.error,
                  onTap: _showLogoutDialog,
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showSemesterSheet() {
    final cs = Theme.of(context).colorScheme;
    final semesters = _localSemesters.isNotEmpty
        ? _localSemesters
        : ref.read(authProvider).availableSemesters;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: cs.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Text(
                  'Which semester?',
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: cs.onSurface,
                  ),
                ),
                Text(
                  'Everything in the app follows your pick.',
                  style: GoogleFonts.dmSans(fontSize: 13, color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 14),
                ...semesters.map((s) {
                  final id = s['id']?.toString() ?? '';
                  final name = s['name']?.toString() ?? id;
                  final isCurrent =
                      id == ref.read(authProvider).activeSemesterId;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                    color: isCurrent ? cs.primary.withValues(alpha: 0.16) : cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(22),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
                    title: Text(
                      name,
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isCurrent ? cs.primary : cs.onSurface,
                      ),
                    ),
                    trailing: isCurrent
                        ? Icon(Icons.check_circle_rounded, color: cs.primary)
                        : null,
                    onTap: () async {
                      Navigator.of(sheetCtx).pop();
                      await ref
                          .read(authProvider.notifier)
                          .changeSemester(id, name);
                      ref.invalidate(allDataProvider);
                      ref.invalidate(profileProvider);
                      ref.invalidate(attendanceProvider);
                      ref.invalidate(timetableProvider);
                      ref.invalidate(marksProvider);
                      ref.read(dashboardProvider.notifier).syncAll(
                            isUserInitiated: true,
                          );
                    },
                  ),
                  ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// PROFILE CARD COMPONENT (Matches ProfileCard with Stat Badges & Privacy)
// ============================================================================

class _ProfileCard extends StatelessWidget {
  final String studentName;
  final String cgpa;
  final String credits;
  final bool isPrivate;
  final VoidCallback onTogglePrivacy;
  final String? customAvatarPath;
  final String? base64Pfp;
  final String activeSemName;
  final VoidCallback onTapAvatar;
  final VoidCallback onChangeSemester;

  const _ProfileCard({
    required this.studentName,
    required this.cgpa,
    required this.credits,
    required this.isPrivate,
    required this.onTogglePrivacy,
    required this.customAvatarPath,
    required this.base64Pfp,
    required this.activeSemName,
    required this.onTapAvatar,
    required this.onChangeSemester,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hsl = HSLColor.fromColor(cs.primary);
    final top = hsl.withLightness(hsl.lightness.clamp(0.0, 0.42)).withSaturation(hsl.saturation.clamp(0.5, 1.0)).toColor();
    final bottom = Color.lerp(top, const Color(0xFF16102E), 0.7)!;

    ImageProvider avatarProvider;
    if (customAvatarPath != null && customAvatarPath!.isNotEmpty) {
      avatarProvider = AssetImage(customAvatarPath!);
    } else if (base64Pfp != null && base64Pfp!.isNotEmpty) {
      avatarProvider = MemoryImage(base64Decode(base64Pfp!));
    } else {
      avatarProvider = const AssetImage('assets/images/pfp/default.png');
    }

    Widget stat(String value, String label) => GestureDetector(
          onTap: onTogglePrivacy,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                isPrivate
                    ? const Icon(Icons.visibility_off_rounded, size: 20, color: Colors.white)
                    : Text(value, style: GoogleFonts.bricolageGrotesque(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, height: 1.05)),
                Text(label.toUpperCase(),
                    style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1, color: Colors.white70)),
              ],
            ),
          ),
        );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [top, bottom]),
        boxShadow: [BoxShadow(color: top.withValues(alpha: 0.35), blurRadius: 26, offset: const Offset(0, 12))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onTapAvatar,
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: Colors.white, width: 2.5),
                    image: DecorationImage(image: avatarProvider, fit: BoxFit.cover),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      studentName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.bricolageGrotesque(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, height: 1.1, letterSpacing: -0.4),
                    ),
                    const SizedBox(height: 4),
                    Text('Tap the photo to change it',
                        style: GoogleFonts.dmSans(fontSize: 12, color: Colors.white.withValues(alpha: 0.75))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              stat(cgpa, 'CGPA'),
              const SizedBox(width: 10),
              stat(credits, 'Credits'),
              const Spacer(),
              GestureDetector(
                onTap: onChangeSemester,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 92),
                        child: Text(activeSemName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w800, color: bottom)),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.unfold_more_rounded, size: 16, color: bottom),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MenuSection extends StatelessWidget {
  final String? label;
  final List<Widget> children;

  const MenuSection({super.key, this.label, required this.children});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
            child: Text(
              label!.toUpperCase(),
              style: GoogleFonts.dmSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.3,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainer,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Divider(height: 1, thickness: 1, indent: 72, endIndent: 16, color: cs.outlineVariant.withValues(alpha: 0.35)),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class MenuTile extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? background;
  final Color? foreground;

  const MenuTile({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.background,
    this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final titleColor = foreground ?? cs.onSurface;
    final accessoryColor = foreground ?? cs.onSurfaceVariant;
    final chip = foreground ?? cs.primary;

    return Material(
      color: background ?? Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: subtitle == null ? 60 : 74),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                if (icon != null) ...[
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: chip.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(icon, size: 21, color: chip),
                  ),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.bricolageGrotesque(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          color: titleColor,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: GoogleFonts.dmSans(fontSize: 12.5, color: accessoryColor),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing!,
                ] else if (onTap != null) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded, color: accessoryColor),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// PROFILE DETAIL PAGE (rows of UserInfoTile)
// ============================================================================

class ProfileDetailPage extends StatelessWidget {
  final Map<String, dynamic> profileData;
  final String regNo;
  final String? customAvatarPath;
  final String? base64Pfp;
  final VoidCallback onChangeAvatar;

  const ProfileDetailPage({
    super.key,
    required this.profileData,
    required this.regNo,
    required this.customAvatarPath,
    required this.base64Pfp,
    required this.onChangeAvatar,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final studentName =
        (profileData['student_name'] ?? profileData['name'] ?? regNo)
            .toString();
    final appNo = (profileData['application_number'] ?? regNo).toString();
    final email = (profileData['email'] ?? '').toString();
    final dob = (profileData['dob'] ?? '').toString();
    final bloodGroup = (profileData['blood_group'] ?? '').toString();
    final gender = (profileData['gender'] ?? '').toString();
    final mentor = profileData['mentor_details'] as Map<String, dynamic>?;

    ImageProvider avatarProvider;
    if (customAvatarPath != null && customAvatarPath!.isNotEmpty) {
      avatarProvider = AssetImage(customAvatarPath!);
    } else if (base64Pfp != null && base64Pfp!.isNotEmpty) {
      avatarProvider = MemoryImage(base64Decode(base64Pfp!));
    } else {
      avatarProvider = const AssetImage('assets/images/pfp/default.png');
    }

    return Scaffold(
      appBar: const NexusAppBar(title: 'Profile', subtitle: 'Your details'),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 54,
                  backgroundImage: avatarProvider,
                ),
                TextButton(
                  onPressed: onChangeAvatar,
                  child: const Text('Change avatar'),
                ),
                Text(
                  studentName,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          UserInfoTile('Full Name', studentName, copyable: true),
          UserInfoTile('Registration Number', regNo, copyable: true),
          UserInfoTile('Application Number', appNo, copyable: true),
          if (email.isNotEmpty)
            UserInfoTile('Email', email, copyable: true),
          if (dob.isNotEmpty)
            UserInfoTile('Date of Birth', dob),
          if (bloodGroup.isNotEmpty)
            UserInfoTile('Blood Group', bloodGroup),
          if (gender.isNotEmpty)
            UserInfoTile('Gender', gender),
          if (mentor != null) ...[
            const SizedBox(height: 16),
            Text(
              'Mentor Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 12),
            UserInfoTile(
              'Mentor Name',
              (mentor['name'] ?? mentor['mentor_name'] ?? 'N/A').toString(),
              copyable: true,
            ),
            UserInfoTile(
              'Mentor Email',
              (mentor['email'] ?? 'N/A').toString(),
              copyable: true,
            ),
            UserInfoTile(
              'Mentor Cabin',
              (mentor['cabin'] ?? mentor['room_no'] ?? 'N/A').toString(),
            ),
          ],
        ],
      ),
    );
  }
}

class UserInfoTile extends StatelessWidget {
  final String title;
  final String description;
  final bool copyable;

  const UserInfoTile(
    this.title,
    this.description, {
    this.copyable = false,
    super.key,
  });

  bool get _hasValue => description.trim().isNotEmpty && description != 'N/A';

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: description.trim()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title copied to clipboard'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: InkWell(
        onTap: copyable && _hasValue ? () => _copy(context) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: cs.primary,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _hasValue ? description.trim() : 'N/A',
                      style: TextStyle(
                        fontSize: 15,
                        color: _hasValue ? cs.onSurface : cs.outline,
                      ),
                    ),
                  ),
                  if (copyable && _hasValue)
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      color: cs.onSurfaceVariant,
                      onPressed: () => _copy(context),
                      tooltip: 'Copy $title',
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// MANAGE CREDENTIALS PAGE (Auto-Detect password change & semester management)
// ============================================================================

class ManageCredentialsPage extends StatefulWidget {
  final AuthState authState;
  final List<Map<String, dynamic>> localSemesters;

  const ManageCredentialsPage({
    super.key,
    required this.authState,
    required this.localSemesters,
  });

  @override
  State<ManageCredentialsPage> createState() => _ManageCredentialsPageState();
}

class _ManageCredentialsPageState extends State<ManageCredentialsPage> {
  late TextEditingController _regNoCtrl;
  late TextEditingController _passwordCtrl;
  bool _obscurePassword = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final creds = StorageService.getCredentialsSync();
    _regNoCtrl = TextEditingController(
      text: creds['username'] ?? widget.authState.username ?? '',
    );
    _passwordCtrl = TextEditingController(
      text: creds['password'] ?? widget.authState.password ?? '',
    );
  }

  @override
  void dispose() {
    _regNoCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveCredentials() async {
    final reg = _regNoCtrl.text.trim().toUpperCase();
    final pass = _passwordCtrl.text.trim();
    if (reg.isEmpty || pass.isEmpty) return;

    setState(() => _saving = true);
    final cs = Theme.of(context).colorScheme;
    final messenger = ScaffoldMessenger.of(context);

    try {
      await StorageService.saveCredentials(
        username: reg,
        password: pass,
        semesterId: widget.authState.activeSemesterId,
        semesterName: widget.authState.activeSemesterName,
      );
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: cs.primary,
            content: Text(
              'Credentials updated successfully!',
              style: TextStyle(color: cs.onPrimary),
            ),
          ),
        );
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const NexusAppBar(title: 'Credentials', subtitle: 'Stored only on this phone'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.security_rounded, color: cs.primary, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Stored securely on your device. Used to authenticate with VTOP for attendance, marks, and timetable sync.',
                    style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _regNoCtrl,
            decoration: const InputDecoration(
              labelText: 'Registration Number',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordCtrl,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'VTOP Password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: _saving ? null : _saveCredentials,
              child: _saving
                  ? const CircularProgressIndicator()
                  : const Text('Update Credentials'),
            ),
          ),
        ],
      ),
    );
  }
}
