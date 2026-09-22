import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../utils/error_formatter.dart';
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
  String? _currentUrl;
  bool _canGoBack = false;
  bool _canGoForward = false;

  static const String _officialVtopUrl = 'https://vtop.vitap.ac.in/vtop/';

  // Editorial campus theme
  AppPalette get _palette => AppPalette.of(context);
  Color get _paper => _palette.paper;
  Color get _surface => _palette.surface;
  Color get _ink => _palette.ink;
  Color get _navy => _palette.navy;
  Color get _orange => _palette.orange;
  Color get _green => _palette.green;
  Color get _red => _palette.red;
  Color get _muted => _palette.inkMuted;
  Color get _line => _palette.line;

  @override
  void initState() {
    super.initState();
    _startSession();
  }

  Future<void> _startSession() async {
    setState(() {
      _isLoading = true;
      _progress = 0.15;
      _errorMessage = null;
    });

    final auth = ref.read(authProvider);
    final username = auth.username ?? '';
    final password = auth.password ?? '';

    String targetUrl = _officialVtopUrl;

    if (username.isNotEmpty && password.isNotEmpty) {
      try {
        final sessionData = await apiService.startProxySession(
          username: username,
          password: password,
        );
        final portalPath = sessionData['portal_path']?.toString();
        if (portalPath != null && portalPath.isNotEmpty) {
          targetUrl = '${ApiClient.defaultBaseUrl}$portalPath';
        }
      } catch (e) {
        debugPrint('Proxy start session fallback to official portal: $e');
        targetUrl = _officialVtopUrl;
      }
    }

    _currentUrl = targetUrl;

    if (!mounted) return;

    if (kIsWeb) {
      setState(() {
        _webEmbedView = buildVtopEmbed(targetUrl);
        _isLoading = false;
      });
      return;
    }

    try {
      late final WebViewController controller;
      controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(_surface)
        ..enableZoom(true)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (url) {
              if (mounted) {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                  _currentUrl = url;
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
                  _currentUrl = url;
                });
                _updateNavState();
              }

              // Pre-fill login credentials if on official login page
              if (username.isNotEmpty && password.isNotEmpty) {
                try {
                  await controller.runJavaScript('''
                    (function() {
                      try {
                        var u = document.getElementById('username') || document.querySelector('input[name="username"]') || document.querySelector('input[name="uname"]');
                        var p = document.getElementById('password') || document.querySelector('input[name="password"]') || document.querySelector('input[name="passwd"]');
                        if (u && !u.value) {
                          u.value = "$username";
                          u.dispatchEvent(new Event('input', { bubbles: true }));
                        }
                        if (p && !p.value) {
                          p.value = "$password";
                          p.dispatchEvent(new Event('input', { bubbles: true }));
                        }
                      } catch(e) {}
                    })();
                  ''');
                } catch (_) {}
              }

              // Inject mobile sidebar popup styles and touch handling
              try {
                await controller.runJavaScript('''
                  (function() {
                    var styleId = 'vtop-mobile-sidebar-fix';
                    if (!document.getElementById(styleId)) {
                      var style = document.createElement('style');
                      style.id = styleId;
                      style.innerHTML = `
                        .main-sidebar, .sidebar, .sidebar-menu {
                          overflow: visible !important;
                          position: absolute !important;
                        }
                        .sidebar-mini.sidebar-collapse .main-sidebar {
                          width: 50px !important;
                          overflow: visible !important;
                          z-index: 99999 !important;
                        }
                        .sidebar-mini.sidebar-collapse .sidebar {
                          overflow: visible !important;
                        }
                        .sidebar-mini.sidebar-collapse .sidebar-menu {
                          overflow: visible !important;
                        }
                        .sidebar-mini.sidebar-collapse .sidebar-menu > li {
                          position: relative !important;
                          overflow: visible !important;
                        }
                        .sidebar-mini.sidebar-collapse .sidebar-menu > li > a {
                          cursor: pointer !important;
                          -webkit-tap-highlight-color: rgba(255,255,255,0.2) !important;
                        }
                        .sidebar-mini.sidebar-collapse .sidebar-menu > li.menu-open > .treeview-menu,
                        .sidebar-mini.sidebar-collapse .sidebar-menu > li.active > .treeview-menu {
                          display: block !important;
                          position: absolute !important;
                          left: 50px !important;
                          top: 0 !important;
                          min-width: 250px !important;
                          max-width: 320px !important;
                          background: #2c3b41 !important;
                          border: 1px solid #1a2226 !important;
                          border-radius: 0 8px 8px 0 !important;
                          box-shadow: 4px 6px 20px rgba(0,0,0,0.5) !important;
                          padding: 6px 0 !important;
                          margin: 0 !important;
                          z-index: 999999 !important;
                          pointer-events: auto !important;
                          max-height: 80vh !important;
                          overflow-y: auto !important;
                          -webkit-overflow-scrolling: touch !important;
                        }
                        .sidebar-mini.sidebar-collapse .sidebar-menu > li.menu-open > .treeview-menu > li > a {
                          display: block !important;
                          padding: 12px 18px !important;
                          color: #e0e0e0 !important;
                          font-size: 13.5px !important;
                          line-height: 1.4 !important;
                          border-bottom: 1px solid rgba(255,255,255,0.06) !important;
                          text-decoration: none !important;
                          pointer-events: auto !important;
                        }
                        .sidebar-mini.sidebar-collapse .sidebar-menu > li.menu-open > .treeview-menu > li > a:hover,
                        .sidebar-mini.sidebar-collapse .sidebar-menu > li.menu-open > .treeview-menu > li > a:active {
                          background: #1e282c !important;
                          color: #ffffff !important;
                        }
                        .sidebar-open .main-sidebar {
                          transform: translate(0, 0) !important;
                          width: 240px !important;
                          z-index: 99999 !important;
                          box-shadow: 4px 0 20px rgba(0,0,0,0.4) !important;
                        }
                        .sidebar-toggle {
                          padding: 14px !important;
                          display: block !important;
                          cursor: pointer !important;
                        }
                      `;
                      document.head.appendChild(style);
                    }

                    function bindVtopSidebar() {
                      var items = document.querySelectorAll('.sidebar-menu > li');
                      items.forEach(function(item) {
                        var a = item.querySelector(':scope > a');
                        if (a && !a._boundVtopMobile) {
                          a._boundVtopMobile = true;
                          a.addEventListener('click', function(e) {
                            var submenu = item.querySelector(':scope > .treeview-menu');
                            if (submenu) {
                              var isCurrentlyOpen = item.classList.contains('menu-open') || submenu.style.display === 'block';
                              
                              items.forEach(function(other) {
                                if (other !== item) {
                                  other.classList.remove('menu-open');
                                  var s = other.querySelector(':scope > .treeview-menu');
                                  if (s) s.style.display = 'none';
                                }
                              });

                              if (!isCurrentlyOpen) {
                                item.classList.add('menu-open');
                                submenu.style.display = 'block';
                                submenu.style.visibility = 'visible';
                              } else {
                                item.classList.remove('menu-open');
                                submenu.style.display = 'none';
                              }
                              e.preventDefault();
                              e.stopPropagation();
                            }
                          });
                        }
                      });

                      var subLinks = document.querySelectorAll('.sidebar-menu .treeview-menu a');
                      subLinks.forEach(function(link) {
                        if (!link._boundSubClick) {
                          link._boundSubClick = true;
                          link.addEventListener('click', function(e) {
                            setTimeout(function() {
                              var openParents = document.querySelectorAll('.sidebar-menu > li.menu-open');
                              openParents.forEach(function(p) {
                                p.classList.remove('menu-open');
                                var sub = p.querySelector('.treeview-menu');
                                if (sub) sub.style.display = 'none';
                              });
                            }, 400);
                          });
                        }
                      });

                      var toggles = document.querySelectorAll('.sidebar-toggle, [data-toggle="offcanvas"], [data-toggle="push-menu"]');
                      toggles.forEach(function(toggle) {
                        if (!toggle._boundToggleClick) {
                          toggle._boundToggleClick = true;
                          toggle.addEventListener('click', function(e) {
                            var body = document.body;
                            if (body.classList.contains('sidebar-collapse')) {
                              body.classList.remove('sidebar-collapse');
                              body.classList.add('sidebar-open');
                            } else {
                              body.classList.add('sidebar-collapse');
                              body.classList.remove('sidebar-open');
                            }
                          });
                        }
                      });
                    }

                    document.addEventListener('click', function(e) {
                      if (!e.target.closest('.main-sidebar')) {
                        var openItems = document.querySelectorAll('.sidebar-menu > li.menu-open');
                        openItems.forEach(function(item) {
                          item.classList.remove('menu-open');
                          var s = item.querySelector('.treeview-menu');
                          if (s) s.style.display = 'none';
                        });
                      }
                    });

                    bindVtopSidebar();
                    setInterval(bindVtopSidebar, 1000);
                  })();
                ''');
              } catch (_) {}
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
        ..loadRequest(Uri.parse(targetUrl));

      setState(() {
        _controller = controller;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = ErrorFormatter.format(
            e,
            fallback: 'Unable to connect to VTOP Portal. Please check your connection and try again.',
          );
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
    final target = url ?? _currentUrl ?? _officialVtopUrl;
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
                value: _progress > 0 && _progress < 1.0 ? _progress : null,
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
                _startSession();
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
            _isLoading ? 'LOADING' : 'LIVE PORTAL',
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
                    onPressed: _startSession,
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
                    onPressed: () => _launchExternal(url: _officialVtopUrl),
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
