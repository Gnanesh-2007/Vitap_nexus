import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../providers/auth_provider.dart';
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
  double _progress = 0.0;
  String? _errorMessage;
  bool _canGoBack = false;
  bool _canGoForward = false;

  static const String _vtopUrl = 'https://vtop.vitap.ac.in/vtop/';

  // Editorial campus theme
  static const _paper = Color(0xFFF4F2ED);
  static const _surface = Color(0xFFFFFEFB);
  static const _ink = Color(0xFF17202A);
  static const _navy = Color(0xFF172B4D);
  static const _orange = Color(0xFFE47543);
  static const _green = Color(0xFF278B68);
  static const _red = Color(0xFFC84C43);
  static const _muted = Color(0xFF6E7681);
  static const _line = Color(0xFFE2DED5);

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    setState(() {
      _isLoading = true;
      _progress = 0.1;
      _errorMessage = null;
    });

    if (kIsWeb) {
      setState(() {
        _webEmbedView = buildVtopEmbed(_vtopUrl);
        _isLoading = false;
      });
      return;
    }

    try {
      final auth = ref.read(authProvider);
      final username = auth.username ?? '';
      final password = auth.password ?? '';

      late final WebViewController controller;
      controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(_surface)
        ..enableZoom(true)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (_) {
              if (mounted) {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
                _updateNavState();
              }
            },
            onProgress: (p) {
              if (mounted) {
                setState(() => _progress = p / 100.0);
              }
            },
            onPageFinished: (url) async {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _progress = 1.0;
                });
                _updateNavState();
              }

              // Optional: auto-fill login credentials if on login page
              if (username.isNotEmpty && password.isNotEmpty && url.contains('vtop')) {
                try {
                  await controller.runJavaScript('''
                    (function() {
                      try {
                        var uInput = document.getElementById('username') || document.querySelector('input[name="username"]');
                        var pInput = document.getElementById('password') || document.querySelector('input[name="password"]');
                        if (uInput && !uInput.value) {
                          uInput.value = "$username";
                          uInput.dispatchEvent(new Event('input', { bubbles: true }));
                        }
                        if (pInput && !pInput.value) {
                          pInput.value = "$password";
                          pInput.dispatchEvent(new Event('input', { bubbles: true }));
                        }
                      } catch(e) {}
                    })();
                  ''');
                } catch (_) {}
              }
            },
            onWebResourceError: (error) {
              if (error.isForMainFrame == true && mounted) {
                setState(() {
                  _isLoading = false;
                  _errorMessage = error.description;
                });
              }
            },
          ),
        )
        ..loadRequest(Uri.parse(_vtopUrl));

      setState(() {
        _controller = controller;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _updateNavState() async {
    if (_controller != null && mounted) {
      final back = await _controller!.canGoBack();
      final forward = await _controller!.canGoForward();
      if (mounted) {
        setState(() {
          _canGoBack = back;
          _canGoForward = forward;
        });
      }
    }
  }

  Future<void> _launchExternal({String? url}) async {
    final target = url ?? _vtopUrl;
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
            if (_isLoading)
              LinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
                minHeight: 2.5,
                backgroundColor: _line,
                valueColor: const AlwaysStoppedAnimation<Color>(_navy),
              ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: _paper,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Row(
        children: [
          _headerButton(
            icon: Icons.arrow_back_rounded,
            onPressed: () async {
              if (!kIsWeb && _controller != null && _canGoBack) {
                await _controller!.goBack();
              } else {
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              }
            },
            tooltip: _canGoBack ? 'Go Back' : 'Close',
          ),
          if (_canGoForward) ...[
            const SizedBox(width: 6),
            _headerButton(
              icon: Icons.arrow_forward_rounded,
              onPressed: () async {
                if (_controller != null) {
                  await _controller!.goForward();
                }
              },
              tooltip: 'Go Forward',
            ),
          ],
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
            onPressed: () {
              if (_controller != null) {
                _controller!.reload();
              } else {
                _initWebView();
              }
            },
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
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(11),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: _line),
            ),
            child: Icon(icon, color: _navy, size: 18),
          ),
        ),
      ),
    );
  }

  Widget _sessionBadge() {
    final active = _errorMessage == null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFE8F4EF) : const Color(0xFFF9ECE7),
        borderRadius: BorderRadius.circular(6),
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
          const SizedBox(width: 4),
          Text(
            _isLoading ? 'LOADING' : 'OFFICIAL VTOP',
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
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
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

    return const Center(
      child: CircularProgressIndicator(
        strokeWidth: 2.2,
        valueColor: AlwaysStoppedAnimation<Color>(_navy),
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
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFFCEDEA),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.cloud_off_rounded,
                  color: _red,
                  size: 26,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Could not load VTOP Portal',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  color: _ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _errorMessage ?? 'Network error occurred while connecting to VTOP.',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  color: _muted,
                  fontSize: 11.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _initWebView,
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
                    onPressed: () => _launchExternal(),
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: Text(
                      'Open in Chrome',
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
