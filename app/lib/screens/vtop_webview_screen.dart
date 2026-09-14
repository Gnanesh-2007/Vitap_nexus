import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../utils/vtop_embed_helper.dart';

class VtopWebViewScreen extends ConsumerStatefulWidget {
  const VtopWebViewScreen({super.key});

  @override
  ConsumerState<VtopWebViewScreen> createState() => _VtopWebViewScreenState();
}

class _VtopWebViewScreenState extends ConsumerState<VtopWebViewScreen> {
  WebViewController? _controller;
  Widget? _webEmbedView;
  bool _isLoading = true;
  String? _errorMessage;
  String? _portalUrl;

  @override
  void initState() {
    super.initState();
    _initLoggedSession();
  }

  Future<void> _initLoggedSession() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final auth = ref.read(authProvider);
      final username = auth.username ?? '';
      final password = auth.password ?? '';

      if (username.isEmpty || password.isEmpty) {
        throw Exception('VTOP login credentials not found. Please log in again.');
      }

      // 1. Authenticate with backend and start a live proxy session
      final sessionData = await apiService.startProxySession(
        username: username,
        password: password,
      );

      final portalPath = sessionData['portal_path']?.toString() ?? '/vtop_proxy/session/default/content';
      final fullUrl = '${ApiClient.defaultBaseUrl}$portalPath';

      if (!mounted) return;

      if (kIsWeb) {
        // Web: Render the live authenticated VTOP portal inside the Flutter canvas
        setState(() {
          _portalUrl = fullUrl;
          _webEmbedView = buildVtopEmbed(fullUrl);
          _isLoading = false;
        });
      } else {
        // Mobile (Android/iOS): Native WebViewController
        final controller = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(AppTheme.background)
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageFinished: (_) {
                if (mounted) setState(() => _isLoading = false);
              },
              onWebResourceError: (error) {
                if (mounted) {
                  debugPrint('WebView Error: ${error.description}');
                }
              },
            ),
          )
          ..loadRequest(Uri.parse(fullUrl));

        setState(() {
          _portalUrl = fullUrl;
          _controller = controller;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not open logged-in VTOP:\n${e.toString()}';
      });
    }
  }

  Future<void> _launchExternal() async {
    if (_portalUrl != null) {
      try {
        await launchUrl(Uri.parse(_portalUrl!), mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'VTOP Portal',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              _isLoading ? 'Authenticating...' : 'Logged-in Session',
              style: GoogleFonts.inter(
                fontSize: 10,
                color: _isLoading ? AppTheme.primaryAccent : const Color(0xFF10B981),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () async {
            if (!kIsWeb && _controller != null && await _controller!.canGoBack()) {
              await _controller!.goBack();
            } else {
              if (context.mounted) Navigator.of(context).pop();
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _initLoggedSession,
            tooltip: 'Re-authenticate & Reload',
          ),
          if (_portalUrl != null)
            IconButton(
              icon: const Icon(Icons.open_in_new_rounded),
              onPressed: _launchExternal,
              tooltip: 'Open in new tab',
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppTheme.primary),
            const SizedBox(height: 20),
            Text(
              'Logging into VTOP...',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'Solving captcha & opening your live student portal',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.white60),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 54, color: AppTheme.error),
              const SizedBox(height: 14),
              Text(
                'Failed to Connect to VTOP',
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12, color: Colors.white54),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _initLoggedSession,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Web Platform view
    if (kIsWeb && _webEmbedView != null) {
      return SizedBox.expand(child: _webEmbedView!);
    }

    // Mobile WebView
    if (!kIsWeb && _controller != null) {
      return SizedBox.expand(child: WebViewWidget(controller: _controller!));
    }

    return const Center(
      child: Text('Loading VTOP...', style: TextStyle(color: Colors.white60)),
    );
  }
}
