import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/motion/nexus_illustrations.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class VtopWebViewScreen extends ConsumerStatefulWidget {
  const VtopWebViewScreen({super.key});

  @override
  ConsumerState<VtopWebViewScreen> createState() => _VtopWebViewScreenState();
}

class _VtopWebViewScreenState extends ConsumerState<VtopWebViewScreen> {
  static const String _vtopBaseUrl = 'https://vtop.vitap.ac.in';
  static const String _vtopDomain = 'vtop.vitap.ac.in';
  static const String _vtopOpenPage = '/vtop/open/page';
  static const String _vtopContentPage = '/vtop/content';
  static const String _vtopLoginPage = '/vtop/login';
  static const String _vtopPreLoginPage = '/vtop/prelogin';

  WebViewController? _controller;
  bool _isLoading = true;
  bool _isContentLoaded = false;
  bool _isSessionVerified = false;
  double _loadingProgress = 0;
  String _currentUrl = '';
  String? _csrfToken;
  String? _authorizedId;
  String? _errorMessage;
  bool _hasRetriedExpiredPage = false;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _setState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  List<MapEntry<String, String>> _parseCookieString(String cookieString) {
    final cookies = <MapEntry<String, String>>[];
    final parts = cookieString.split(';');
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      final eqIdx = trimmed.indexOf('=');
      if (eqIdx == -1) continue;
      final name = trimmed.substring(0, eqIdx).trim();
      final value = trimmed.substring(eqIdx + 1).trim();
      if (name.isNotEmpty) {
        cookies.add(MapEntry(name, value));
      }
    }
    return cookies;
  }

  Future<void> _injectCookies(String cookieString) async {
    final cookieManager = WebViewCookieManager();
    await cookieManager.clearCookies();
    final cookies = _parseCookieString(cookieString);
    for (final cookie in cookies) {
      await cookieManager.setCookie(
        WebViewCookie(
          name: cookie.key,
          value: cookie.value,
          domain: _vtopDomain,
          path: '/',
        ),
      );
    }
  }

  String _htmlAttrEscape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  Future<void> _extractCsrfToken() async {
    if (_controller == null) return;
    try {
      final result = await _controller!.runJavaScriptReturningResult('''
        (function() {
          var csrfInput = document.querySelector('input[name="_csrf"]');
          return csrfInput ? csrfInput.value : '';
        })()
      ''');
      final token = result.toString().replaceAll('"', '');
      if (token.isEmpty) return;
      if (_currentUrl.contains(_vtopLoginPage) ||
          _currentUrl.contains(_vtopPreLoginPage)) {
        return;
      }
      _csrfToken = token;
    } catch (_) {}
  }

  Future<void> _navigateWithPost(
    String path, {
    Map<String, String>? additionalParams,
    bool verifyMenu = true,
  }) async {
    if (_controller == null || _csrfToken == null || _csrfToken!.isEmpty) {
      return;
    }

    final params = <String, String>{
      '_csrf': _csrfToken!,
      if (_authorizedId != null && _authorizedId!.isNotEmpty)
        'authorizedID': _authorizedId!,
      if (verifyMenu) 'verifyMenu': 'true',
      'nocache': '@(new Date().getTime())',
      ...?additionalParams,
    };

    final formFields = params.entries
        .map(
          (e) =>
              '<input type="hidden" name="${_htmlAttrEscape(e.key)}" value="${_htmlAttrEscape(e.value)}">',
        )
        .join('');

    final jsCode = '''
      (function() {
        var form = document.createElement('form');
        form.method = 'POST';
        form.action = '$_vtopBaseUrl$path';
        form.innerHTML = '$formFields';
        document.body.appendChild(form);
        form.submit();
      })()
    ''';

    try {
      await _controller!.runJavaScript(jsCode);
    } catch (e) {
      debugPrint('VtopWebViewScreen: Failed to navigate with POST: $e');
    }
  }

  Future<void> _injectMobileSidebarEnhancements(
    WebViewController controller,
  ) async {
    const js = '''
(function() {
  if (window.__vtopNexusMobileSidebarInstalled) return;
  window.__vtopNexusMobileSidebarInstalled = true;

  var style = document.createElement('style');
  style.id = '__vtop_nexus_sidebar_css';
  style.textContent =
    '#sidePanel, .sidePanel, .btn-group-vertical, .btn-group.dropend { overflow: visible !important; } ' +
    '.btn-group.dropend > .dropdown-menu.__vtop-open, .dropdown-menu.__vtop-open { ' +
    '  display: block !important; ' +
    '  position: fixed !important; ' +
    '  z-index: 2147483647 !important; ' +
    '  background: #ffffff !important; ' +
    '  border: 1px solid rgba(0,0,0,0.12) !important; ' +
    '  border-radius: 10px !important; ' +
    '  box-shadow: 0 10px 30px rgba(0,0,0,0.22) !important; ' +
    '  padding: 6px 0 !important; ' +
    '  min-width: 255px !important; ' +
    '  max-width: 84vw !important; ' +
    '  max-height: 80vh !important; ' +
    '  overflow-y: auto !important; ' +
    '  overflow-x: hidden !important; ' +
    '} ' +
    '.dropdown-menu.__vtop-open .dropdown-item { ' +
    '  display: block !important; ' +
    '  padding: 8px 16px !important; ' +
    '  color: #1e293b !important; ' +
    '  font-size: 13.5px !important; ' +
    '  white-space: nowrap !important; ' +
    '  text-decoration: none !important; ' +
    '} ' +
    '.dropdown-menu.__vtop-open .dropdown-item:active, .dropdown-menu.__vtop-open .dropdown-item:hover { ' +
    '  background-color: #eff6ff !important; ' +
    '  color: #1d4ed8 !important; ' +
    '}';
  (document.head || document.documentElement).appendChild(style);
})();
''';
    try {
      await controller.runJavaScript(js);
    } catch (_) {}
  }

  Future<void> _initializeWebView({bool forceRenew = false}) async {
    _setState(() {
      _isLoading = true;
      _isContentLoaded = false;
      _errorMessage = null;
      _loadingProgress = 0.1;
    });

    try {
      final authState = ref.read(authProvider);
      final creds = await StorageService.getCredentials();
      final username = authState.username ?? creds['username'] ?? '';
      final password = authState.password ?? creds['password'] ?? '';

      if (username.isEmpty || password.isEmpty) {
        _setState(() {
          _errorMessage =
              'No saved VTOP credentials found. Please log in again.';
          _isLoading = false;
        });
        return;
      }

      // Get cookies, CSRF token, authorized ID, and matching User-Agent directly
      // from the on-device Rust VtopClient session.
      final sessionData = await apiService.getWebViewSessionData(
        username: username,
        password: password,
        forceRefresh: forceRenew,
      );

      final cookieString = sessionData['cookies'] ?? '';
      _csrfToken = sessionData['csrf_token'];
      _authorizedId = sessionData['authorized_id'] ?? username;
      final userAgent = sessionData['user_agent'] ?? '';

      if (cookieString.isEmpty) {
        _setState(() {
          _isLoading = false;
          _isSessionVerified = false;
          _errorMessage =
              'Unable to establish VTOP session cookies. Tap Retry.';
        });
        return;
      }

      await _injectCookies(cookieString);

      _setState(() {
        _isSessionVerified = true;
        _loadingProgress = 0.35;
      });

      final WebViewController controller = WebViewController();
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      if (userAgent.isNotEmpty) {
        await controller.setUserAgent(userAgent);
      }
      await controller.setBackgroundColor(Colors.white);
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            _setState(() {
              _loadingProgress = progress / 100.0;
            });
          },
          onPageStarted: (String url) {
            _setState(() {
              _isLoading = true;
              _currentUrl = url;
            });
          },
          onPageFinished: (String url) async {
            _setState(() {
              _isLoading = false;
              _currentUrl = url;
            });

            await _extractCsrfToken();

            if (url.contains(_vtopOpenPage) &&
                _csrfToken != null &&
                _csrfToken!.isNotEmpty) {
              await Future<void>.delayed(const Duration(milliseconds: 250));
              await _navigateWithPost(_vtopContentPage);
            } else if (url.contains(_vtopContentPage)) {
              await _injectMobileSidebarEnhancements(controller);
              _setState(() {
                _isContentLoaded = true;
              });
            } else if (url.contains(_vtopLoginPage) ||
                url.contains(_vtopPreLoginPage)) {
              if (!_hasRetriedExpiredPage) {
                _hasRetriedExpiredPage = true;
                await _initializeWebView(forceRenew: true);
                return;
              }
              _setState(() {
                _errorMessage =
                    'VTOP session expired. Tap Retry to reconnect.';
              });
            } else if (url.startsWith(_vtopBaseUrl)) {
              await _injectMobileSidebarEnhancements(controller);
              _setState(() {
                _isContentLoaded = true;
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            if (error.isForMainFrame ?? false) {
              _setState(() {
                _isLoading = false;
                _errorMessage =
                    'Failed to load VTOP portal: ${error.description}';
              });
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.startsWith(_vtopBaseUrl)) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
        ),
      );

      _controller = controller;

      await controller.loadRequest(
        Uri.parse('$_vtopBaseUrl$_vtopOpenPage'),
      );

      _setState(() {});
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      if (msg.toLowerCase().contains('otp') &&
          _controller == null &&
          Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
        return;
      }
      _setState(() {
        _errorMessage = msg.isNotEmpty
            ? msg
            : 'Unable to load Direct VTOP right now. Please tap Retry.';
        _isLoading = false;
        _isSessionVerified = false;
      });
    }
  }

  void _handleRefresh() {
    if (_controller != null && _isContentLoaded && _errorMessage == null) {
      _setState(() {
        _isLoading = true;
        _loadingProgress = 0.2;
      });
      _controller!.reload();
    } else {
      _hasRetriedExpiredPage = false;
      _initializeWebView(forceRenew: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Scaffold(
      backgroundColor: palette.paper,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: palette.surface,
                border: Border(bottom: BorderSide(color: palette.line)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: palette.ink,
                      size: 24,
                    ),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: palette.soft,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: palette.line),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isSessionVerified
                              ? Icons.lock_rounded
                              : Icons.lock_open_rounded,
                          color: _isSessionVerified
                              ? palette.green
                              : palette.orange,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'vtop.vitap.ac.in',
                          style: GoogleFonts.spaceGrotesk(
                            color: palette.ink,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.refresh_rounded,
                      color: palette.ink,
                      size: 24,
                    ),
                    tooltip: 'Reload VTOP',
                    onPressed: _handleRefresh,
                  ),
                ],
              ),
            ),
            if (_isContentLoaded && _isLoading && _loadingProgress < 1.0)
              LinearProgressIndicator(
                value: _loadingProgress > 0 ? _loadingProgress : null,
                minHeight: 2,
                backgroundColor: palette.line,
                valueColor: AlwaysStoppedAnimation<Color>(palette.blue),
              ),
            Expanded(child: _buildBody(palette)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AppPalette palette) {
    if (_errorMessage != null) {
      return Container(
        color: palette.paper,
        padding: const EdgeInsets.symmetric(horizontal: 28),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const NexusIllustration(kind: NexusIllo.error, size: 120),
            const SizedBox(height: 12),
            Text(
              'Unable to Load Direct VTOP',
              style: GoogleFonts.spaceGrotesk(
                color: palette.ink,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                color: palette.inkSoft,
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: () {
                  _hasRetriedExpiredPage = false;
                  _initializeWebView(forceRenew: true);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: palette.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                ),
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                label: Text(
                  'Retry & Open VTOP',
                  style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_controller == null) {
      return _buildLoadingOverlay(palette);
    }

    return Stack(
      children: [
        Opacity(
          opacity: _isContentLoaded ? 1.0 : 0.0,
          child: WebViewWidget(controller: _controller!),
        ),
        if (!_isContentLoaded) _buildLoadingOverlay(palette),
      ],
    );
  }

  Widget _buildLoadingOverlay(AppPalette palette) {
    return Container(
      color: palette.paper,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const NexusIllustration(kind: NexusIllo.loading, size: 130),
          const SizedBox(height: 16),
          Text(
            'Opening Direct VTOP Portal...',
            style: GoogleFonts.spaceGrotesk(
              color: palette.ink,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Injecting authenticated session directly on-device',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              color: palette.inkSoft,
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 20),
          if (_loadingProgress > 0)
            SizedBox(
              width: 200,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _loadingProgress,
                  minHeight: 5,
                  backgroundColor: palette.line,
                  valueColor: AlwaysStoppedAnimation<Color>(palette.blue),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
