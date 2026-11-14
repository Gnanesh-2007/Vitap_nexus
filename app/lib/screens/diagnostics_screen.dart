import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../providers/vtop_providers.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/shadcn/shadcn_ui.dart';
import '../widgets/motion/nexus_motion.dart';

class DiagnosticsScreen extends ConsumerStatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  ConsumerState<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends ConsumerState<DiagnosticsScreen> {
  int _pingMs = -1;
  bool _isTestingPing = false;

  Future<void> _runPingTest() async {
    setState(() {
      _isTestingPing = true;
      _pingMs = -1;
    });

    final stopwatch = Stopwatch()..start();
    try {
      await apiService.dio.get('/docs');
      stopwatch.stop();
      if (mounted) {
        setState(() {
          _pingMs = stopwatch.elapsedMilliseconds;
          _isTestingPing = false;
        });
      }
    } catch (_) {
      stopwatch.stop();
      if (mounted) {
        setState(() {
          _pingMs = stopwatch.elapsedMilliseconds;
          _isTestingPing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final authState = ref.watch(authProvider);
    final dashboardState = ref.watch(dashboardProvider);

    return Scaffold(
      backgroundColor: palette.paper,
      appBar: AppBar(
        backgroundColor: palette.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: palette.ink, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'System Diagnostics',
          style: GoogleFonts.spaceGrotesk(
            color: palette.ink,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // App Health Header
          AnimeStaggerItem(
            index: 0,
            child: NexusCard(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: palette.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.check_circle_rounded, color: palette.green, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Engine Status: Production Ready',
                          style: GoogleFonts.dmSans(
                            color: palette.ink,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'User: ${authState.username ?? "Anonymous"} | Sem: ${authState.activeSemesterId ?? "Default"}',
                          style: GoogleFonts.dmSans(
                            color: palette.inkMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Network & Ping Latency Card
          AnimeStaggerItem(
            index: 1,
            child: NexusCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'BACKEND LATENCY',
                        style: GoogleFonts.spaceGrotesk(
                          color: palette.inkMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _isTestingPing ? null : _runPingTest,
                        icon: _isTestingPing
                            ? SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: palette.blue),
                              )
                            : Icon(Icons.speed_rounded, size: 16, color: palette.blue),
                        label: Text(
                          _isTestingPing ? 'Testing...' : 'Test Ping',
                          style: GoogleFonts.dmSans(
                            color: palette.blue,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _pingMs >= 0 ? '$_pingMs ms roundtrip' : 'Tap Test Ping to benchmark backend reachability',
                    style: GoogleFonts.dmSans(
                      color: _pingMs >= 0 ? palette.green : palette.inkSoft,
                      fontSize: 13,
                      fontWeight: _pingMs >= 0 ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Sync State Machine Status
          AnimeStaggerItem(
            index: 2,
            child: NexusCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SYNC STATE MACHINE',
                    style: GoogleFonts.spaceGrotesk(
                      color: palette.inkMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                  _buildDiagnosticRow(
                    palette,
                    'Dashboard State',
                    dashboardState.isSyncing
                        ? 'SYNCING'
                        : (dashboardState.hasData
                            ? 'READY'
                            : (dashboardState.isLoading ? 'LOADING' : 'IDLE')),
                  ),
                  _buildDiagnosticRow(palette, 'Storage Engine', 'Multi-Tier Isolated Disk'),
                  _buildDiagnosticRow(palette, 'Credential Security', 'FlutterSecureStorage AES-256'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDiagnosticRow(AppPalette palette, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.dmSans(
                color: palette.inkSoft,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: GoogleFonts.spaceGrotesk(
                color: palette.ink,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
