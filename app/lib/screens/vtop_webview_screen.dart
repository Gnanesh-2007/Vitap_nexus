import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../providers/auth_provider.dart';
import '../services/api_client.dart';
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

  // Editorial campus theme
  static const _paper = Color(0xFFF4F2ED);
  static const _surface = Color(0xFFFFFEFB);
  static const _ink = Color(0xFF17202A);
  static const _navy = Color(0xFF172B4D);
  static const _blue = Color(0xFF356AE6);
  static const _orange = Color(0xFFE47543);
  static const _green = Color(0xFF278B68);
  static const _red = Color(0xFFC84C43);
  static const _muted = Color(0xFF6E7681);
  static const _line = Color(0xFFE2DED5);

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
        throw Exception(
          'VTOP login credentials not found. Please log in again.',
        );
      }

      final sessionData = await apiService.startProxySession(
        username: username,
        password: password,
      );

      final portalPath = sessionData['portal_path']?.toString() ??
          '/vtop_proxy/session/default/content';
      final fullUrl = '${ApiClient.defaultBaseUrl}$portalPath';

      if (!mounted) return;

      if (kIsWeb) {
        setState(() {
          _portalUrl = fullUrl;
          _webEmbedView = buildVtopEmbed(fullUrl);
          _isLoading = false;
        });
      } else {
        final controller = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(_paper)
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageFinished: (_) {
                if (mounted) {
                  setState(() => _isLoading = false);
                }
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

  Future<void> _launchExternal({String? url}) async {
    final target = url ?? _portalUrl ?? 'https://vtop.vitap.ac.in/vtop/login';
    try {
      await launchUrl(
        Uri.parse(target),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _paper,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: _paper,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          _headerButton(
            icon: Icons.arrow_back_rounded,
            onPressed: () async {
              if (!kIsWeb &&
                  _controller != null &&
                  await _controller!.canGoBack()) {
                await _controller!.goBack();
              } else {
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              }
            },
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'ACADEMIC PORTAL',
                  style: GoogleFonts.spaceGrotesk(
                    color: _orange,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'VTOP Portal',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          color: _ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _sessionBadge(),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          _headerButton(
            icon: Icons.refresh_rounded,
            onPressed: _initLoggedSession,
            tooltip: 'Reload',
          ),
          const SizedBox(width: 6),
          _headerButton(
            icon: Icons.open_in_new_rounded,
            onPressed: () => _launchExternal(),
            tooltip: 'Open in Browser',
          ),
        ],
      ),
    );
  }

  Widget _headerButton({
    required IconData icon,
    required VoidCallback onPressed,
    String? tooltip,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _line),
            ),
            child: Icon(icon, color: _navy, size: 19),
          ),
        ),
      ),
    );
  }

  Widget _sessionBadge() {
    final active = !_isLoading && _errorMessage == null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFFE8F4EF)
            : const Color(0xFFF9ECE7),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: active ? _green : _orange,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            _isLoading ? 'AUTHENTICATING' : 'LIVE SESSION',
            style: GoogleFonts.spaceGrotesk(
              color: active ? _green : _orange,
              fontSize: 6.5,
              fontWeight: FontWeight.w800,
              letterSpacing: .5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (kIsWeb && _webEmbedView != null) {
      return Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _line),
        ),
        child: SizedBox.expand(child: _webEmbedView!),
      );
    }

    if (!kIsWeb && _controller != null) {
      return Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _line),
        ),
        child: SizedBox.expand(
          child: WebViewWidget(controller: _controller!),
        ),
      );
    }

    return Center(
      child: Text(
        'Loading VTOP...',
        style: GoogleFonts.dmSans(
          color: _muted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          padding: const EdgeInsets.fromLTRB(24, 27, 24, 25),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _line),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0817202A),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF0FD),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.language_rounded,
                  color: _blue,
                  size: 29,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Opening VTOP',
                style: GoogleFonts.dmSans(
                  color: _ink,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Authenticating your session and opening the live student portal.',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  color: _muted,
                  fontSize: 11.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 19),
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: _blue,
                ),
              ),
              const SizedBox(height: 11),
              Text(
                'PLEASE WAIT',
                style: GoogleFonts.spaceGrotesk(
                  color: _orange,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 430),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFEBC9C4)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFFFCEDEA),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.cloud_off_rounded,
                  color: _red,
                  size: 28,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                'VTOP connection failed',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  color: _ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  color: _muted,
                  fontSize: 11.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _initLoggedSession,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: Text(
                      'Try Again',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _navy,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _launchExternal(url: 'https://vtop.vitap.ac.in/vtop/login'),
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: Text(
                      'Open VTOP',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _navy,
                      side: const BorderSide(color: _line),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
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
