import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:epos/config/admin_portal_credentials.dart';
import 'package:epos/config/brand_info.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_windows/webview_windows.dart';

/// Cross-platform wrapper that loads the hosted admin portal.
class AdminPanelWebViewScreen extends StatefulWidget {
  const AdminPanelWebViewScreen({super.key});

  @override
  State<AdminPanelWebViewScreen> createState() =>
      _AdminPanelWebViewScreenState();
}

class _AdminPanelWebViewScreenState extends State<AdminPanelWebViewScreen> {
  static final Uri _adminUri = Uri.parse('https://thevillagepizzeria.uk/admin');

  WebViewController? _mobileController;
  WebviewController? _windowsController;
  StreamSubscription<LoadingState>? _windowsLoadingSub;
  StreamSubscription<HistoryChanged>? _windowsHistorySub;
  StreamSubscription<String>? _windowsUrlSub;

  double _mobileProgress = 0.0;
  bool _isWindowsLoading = false;
  bool _windowsInitialized = false;
  bool _canGoBack = false;
  bool _canGoForward = false;
  String? _errorMessage;
  String? _latestWindowsUrl;
  bool _credentialsWarningShown = false;
  bool _autoLoginCompleted = false;
  bool _autoLoginViaApi = false;
  bool _apiLoginAttempted = false;
  bool _isAuthenticating = true;

  late final bool _useWindowsWebView;
  late final bool _useWebViewFlutter;

  bool get _hasAdminCredentials => AdminPortalCredentials.isConfigured;

  String get _autoLoginScript => '''
    (function() {
      const username = ${jsonEncode(AdminPortalCredentials.username)};
      const password = ${jsonEncode(AdminPortalCredentials.password)};
      if (!username || !password) {
        return 'missing-credentials';
      }

      function findUserField() {
        const direct = document.querySelector('input[name="log"], input#user_login, input[name="username"], input[name="user"], input[name="email"], input[id*="user" i], input[id*="email" i], input[class*="user" i], input[class*="email" i]');
        if (direct) return direct;
        const candidates = Array.from(
          document.querySelectorAll('input[type="text"], input[type="email"], input[type="tel"], input:not([type])')
        );
        return candidates.find((el) => {
          const fingerprint = `\${(el.name || '')} \${(el.id || '')} \${(el.placeholder || '')}`.toLowerCase();
          return /user|email|login/.test(fingerprint);
        }) || candidates[0] || null;
      }

      function findPasswordField() {
        const direct = document.querySelector('input[name="pwd"], input#user_pass, input[type="password"], input[id*="pass" i], input[name*="pass" i]');
        if (direct) return direct;
        return Array.from(document.querySelectorAll('input')).find((el) => {
          const type = (el.type || '').toLowerCase();
          return type.includes('pass');
        }) || null;
      }

      const userField = findUserField();
      const passField = findPasswordField();

      if (!userField || !passField) {
        const debugInputs = Array.from(document.querySelectorAll('input')).map((el) => {
          return {
            type: el.type || '',
            name: el.name || '',
            id: el.id || '',
            placeholder: el.placeholder || '',
            classes: el.className || '',
          };
        }).slice(0, 12);
        return 'fields-not-found::' + JSON.stringify(debugInputs);
      }

      const setReactInputValue = (element, value) => {
        const prototype = Object.getPrototypeOf(element);
        const descriptor = Object.getOwnPropertyDescriptor(prototype, 'value');
        if (descriptor && descriptor.set) {
          descriptor.set.call(element, value);
        } else {
          element.value = value;
        }
        element.dispatchEvent(new Event('input', { bubbles: true }));
        element.dispatchEvent(new Event('change', { bubbles: true }));
      };

      userField.focus();
      setReactInputValue(userField, username);
      passField.focus();
      setReactInputValue(passField, password);

      const form = userField.form || passField.form || document.querySelector('form');
      if (form) {
        const remember = form.querySelector('input[name="rememberme"]');
        if (remember) {
          remember.checked = true;
        }
        if (typeof form.requestSubmit === 'function') {
          form.requestSubmit();
        } else if (typeof form.submit === 'function') {
          form.submit();
        } else {
          const submitBtn = form.querySelector('button[type="submit"], input[type="submit"]');
          if (submitBtn) {
            submitBtn.click();
          }
        }
        return 'submitted';
      }

      const fallbackBtn = document.querySelector('button[type="submit"], input[type="submit"]');
      if (fallbackBtn) {
        fallbackBtn.click();
        return 'clicked-button';
      }

      return 'form-not-found';
    })();
  ''';

  @override
  void initState() {
    super.initState();
    _useWindowsWebView = !kIsWeb && Platform.isWindows;
    _useWebViewFlutter =
        !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

    if (_useWindowsWebView) {
      unawaited(_initWindowsController());
    } else if (_useWebViewFlutter) {
      _initMobileController();
    } else {
      _errorMessage =
          'Admin panel embedding is not supported on this platform. Please open https://supersubs.uk/admin in your browser.';
      _isAuthenticating = false;
    }

    _maybeWarnMissingCredentials();
  }

  Future<void> _initWindowsController() async {
    final controller = WebviewController();
    _windowsController = controller;
    try {
      await controller.initialize();
      await controller.setBackgroundColor(Colors.white);
      await controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);

      _windowsLoadingSub = controller.loadingState.listen((state) {
        if (!mounted) return;
        setState(() {
          _isWindowsLoading = state == LoadingState.loading;
        });
        if (state == LoadingState.navigationCompleted) {
          final url = _latestWindowsUrl;
          if (url != null) {
            _maybeInjectAutoLogin(url, _runWindowsAutoLoginScript);
          }
        }
      });
      _windowsHistorySub = controller.historyChanged.listen((history) {
        if (!mounted) return;
        setState(() {
          _canGoBack = history.canGoBack;
          _canGoForward = history.canGoForward;
        });
      });
      _windowsUrlSub = controller.url.listen((url) {
        _latestWindowsUrl = url;
      });

      await controller.loadUrl(_adminUri.toString());
      if (!mounted) return;
      setState(() {
        _windowsInitialized = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Unable to initialize embedded browser. Please ensure the Microsoft Edge WebView2 runtime is installed.\nDetails: $e';
        _isAuthenticating = false;
      });
    }
  }

  void _initMobileController() {
    final controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(Colors.white)
          ..setNavigationDelegate(
            NavigationDelegate(
              onProgress: (progress) {
                if (!mounted) return;
                setState(() {
                  _mobileProgress = progress / 100;
                });
              },
              onPageFinished: _handleMobilePageFinished,
              onPageStarted: (_) => _updateMobileNavigationState(),
              onWebResourceError: (error) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Failed to load page (${error.errorType?.name}).',
                    ),
                  ),
                );
              },
            ),
          )
          ..loadRequest(_adminUri);
    _mobileController = controller;
    unawaited(_updateMobileNavigationState());
  }

  void _handleMobilePageFinished(String url) {
    unawaited(_updateMobileNavigationState());
    _maybeInjectAutoLogin(url, _runMobileAutoLoginScript);
  }

  Future<String?> _runMobileAutoLoginScript(String script) async {
    final controller = _mobileController;
    if (controller == null) return null;
    try {
      final result = await controller.runJavaScriptReturningResult(script);
      return result.toString();
    } catch (e) {
      debugPrint('Admin auto-login (mobile) failed: $e');
      return null;
    }
  }

  Future<String?> _runWindowsAutoLoginScript(String script) async {
    final controller = _windowsController;
    if (controller == null) return null;
    try {
      final result = await controller.executeScript(script);
      return result;
    } catch (e) {
      debugPrint('Admin auto-login (Windows) failed: $e');
      return null;
    }
  }

  void _maybeWarnMissingCredentials() {
    if (_credentialsWarningShown || _hasAdminCredentials) return;
    _credentialsWarningShown = true;
    _stopAuthenticating();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Admin auto-login is disabled. Update AdminPortalCredentials to enable background login.',
          ),
        ),
      );
    });
  }

  void _stopAuthenticating() {
    if (!_isAuthenticating || !mounted) return;
    setState(() {
      _isAuthenticating = false;
    });
  }

  bool _shouldAttemptAutoLogin(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;

    final normalizedHost = uri.host.replaceFirst(RegExp(r'^www\.'), '');
    final adminHost = _adminUri.host.replaceFirst(RegExp(r'^www\.'), '');
    if (normalizedHost != adminHost) {
      return false;
    }

    final path = uri.path.toLowerCase();
    final query = uri.query.toLowerCase();

    if (path.contains('logout') || query.contains('logout')) {
      _autoLoginCompleted = false;
    }

    return true;
  }

  Future<void> _maybeInjectAutoLogin(
    String? url,
    Future<String?> Function(String script) runner,
  ) async {
    if (!_hasAdminCredentials || url == null) return;
    if (_autoLoginCompleted) {
      _isAuthenticating = false;
      return;
    }
    if (!_shouldAttemptAutoLogin(url)) return;

    if (!_apiLoginAttempted) {
      _apiLoginAttempted = true;
      final apiResult = await runner(_apiLoginScript);
      final apiSuccess = _handleAutoLoginResult(apiResult);
      if (apiSuccess && _autoLoginViaApi) {
        await Future.delayed(const Duration(milliseconds: 600));
        await _handleReload();
        _autoLoginViaApi = false;
        if (mounted) {
          setState(() {
            _isAuthenticating = false;
          });
        }
        return;
      }
    }

    const maxAttempts = 5;

    Future<void> attempt(int attemptNumber) async {
      if (!mounted) return;
      if (_autoLoginCompleted) return;
      if (attemptNumber > maxAttempts) {
        _stopAuthenticating();
        return;
      }

      try {
        final result = await runner(_autoLoginScript);
        final success = _handleAutoLoginResult(result);
        if (!success) {
          final delayMs = 400 + attemptNumber * 200;
          Future.delayed(
            Duration(milliseconds: delayMs),
            () => attempt(attemptNumber + 1),
          );
        }
      } catch (e) {
        debugPrint('Admin auto-login attempt $attemptNumber failed: $e');
      }
    }

    attempt(0);
  }

  bool _handleAutoLoginResult(String? rawResult) {
    if (rawResult == null) return false;
    final normalizedRaw = rawResult.toString().trim();
    if (normalizedRaw.isEmpty) return false;

    final normalized = normalizedRaw.toLowerCase();

    if (normalized.startsWith('api-success')) {
      _autoLoginCompleted = true;
      _autoLoginViaApi = true;
      debugPrint('Admin auto-login result: $normalizedRaw');
      _stopAuthenticating();
      return true;
    }

    const successValues = {'submitted', 'clicked-button'};

    if (successValues.contains(normalized)) {
      _autoLoginCompleted = true;
      debugPrint('Admin auto-login result: $normalizedRaw');
      _stopAuthenticating();
      return true;
    }

    debugPrint('Admin auto-login result: $normalizedRaw');
    return false;
  }

  Future<void> _updateMobileNavigationState() async {
    final controller = _mobileController;
    if (controller == null) return;
    final back = await controller.canGoBack();
    final forward = await controller.canGoForward();
    if (!mounted) return;
    setState(() {
      _canGoBack = back;
      _canGoForward = forward;
    });
  }

  bool get _isWebViewReady =>
      (_useWindowsWebView &&
          _windowsInitialized &&
          _windowsController != null) ||
      (_useWebViewFlutter && _mobileController != null);

  Future<bool> _handleWillPop() async {
    if (_useWindowsWebView && _canGoBack) {
      await _windowsController?.goBack();
      return false;
    }
    final controller = _mobileController;
    if (_useWebViewFlutter && controller != null) {
      if (await controller.canGoBack()) {
        await controller.goBack();
        return false;
      }
    }
    return true;
  }

  Future<void> _handleReload() async {
    if (_useWindowsWebView) {
      await _windowsController?.reload();
    } else {
      await _mobileController?.reload();
    }
  }

  Future<void> _handleBackNavigation() async {
    if (!_canGoBack) return;
    if (_useWindowsWebView) {
      await _windowsController?.goBack();
    } else {
      await _mobileController?.goBack();
      unawaited(_updateMobileNavigationState());
    }
  }

  Future<void> _handleForwardNavigation() async {
    if (!_canGoForward) return;
    if (_useWindowsWebView) {
      await _windowsController?.goForward();
    } else {
      await _mobileController?.goForward();
      unawaited(_updateMobileNavigationState());
    }
  }

  Widget _buildBody() {
    Widget content;

    if (_errorMessage != null) {
      content = Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    } else if (_useWindowsWebView) {
      if (!_windowsInitialized || _windowsController == null) {
        content = const Center(child: CircularProgressIndicator());
      } else {
        content = Webview(_windowsController!);
      }
    } else {
      final controller = _mobileController;
      if (controller != null) {
        content = WebViewWidget(controller: controller);
      } else {
        content = const SizedBox.shrink();
      }
    }

    if (!_isAuthenticating) {
      return content;
    }

    return Stack(
      children: [
        Positioned.fill(child: content),
        Positioned.fill(child: _buildAuthenticatingOverlay()),
      ],
    );
  }

  Widget _buildAuthenticatingOverlay() {
    return Container(
      color: Colors.white,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.admin_panel_settings,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 24),
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Signing you in...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please wait while we connect to the admin portal.',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final showMobile =
        !_useWindowsWebView && _mobileProgress > 0 && _mobileProgress < 1;
    final showWindows = _useWindowsWebView && _isWindowsLoading;

    if (!showMobile && !showWindows) {
      return const SizedBox.shrink();
    }

    return LinearProgressIndicator(
      value: showMobile ? _mobileProgress : null,
      backgroundColor: Colors.grey.shade300,
      color: Colors.greenAccent,
    );
  }

  @override
  void dispose() {
    _windowsLoadingSub?.cancel();
    _windowsHistorySub?.cancel();
    _windowsUrlSub?.cancel();
    _windowsController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleWillPop,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildProgressBar(),
              ),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.arrow_back_ios,
                color: Colors.grey.shade600,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.admin_panel_settings,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Admin Portal',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          _buildHeaderActions(),
        ],
      ),
    );
  }

  Widget _buildHeaderActions() {
    final actions = [
      _buildHeaderActionButton(
        icon: Icons.refresh,
        tooltip: 'Reload',
        onTap: _isWebViewReady ? _handleReload : null,
      ),
      _buildHeaderActionButton(
        icon: Icons.arrow_back_ios_new,
        tooltip: 'Back',
        onTap: _isWebViewReady && _canGoBack ? _handleBackNavigation : null,
      ),
      _buildHeaderActionButton(
        icon: Icons.arrow_forward_ios,
        tooltip: 'Forward',
        onTap:
            _isWebViewReady && _canGoForward ? _handleForwardNavigation : null,
      ),
    ];

    final children = <Widget>[];
    for (var i = 0; i < actions.length; i++) {
      children.add(actions[i]);
      if (i != actions.length - 1) {
        children.add(const SizedBox(width: 8));
      }
    }

    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }

  Widget _buildHeaderActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
  }) {
    final isEnabled = onTap != null;
    final button = GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isEnabled ? Colors.grey.shade100 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.black, size: 18),
      ),
    );

    return Tooltip(
      message: tooltip,
      child: Opacity(opacity: isEnabled ? 1 : 0.4, child: button),
    );
  }
}

String get _apiLoginScript => '''
    (async () => {
      const username = ${jsonEncode(AdminPortalCredentials.username)};
      const password = ${jsonEncode(AdminPortalCredentials.password)};
      if (!username || !password) {
        return 'api-missing-credentials';
      }
      try {
        const apiUrl = 'https://api.thevillagepizzeria.uk/auth/admin-login';
        const response = await fetch(apiUrl, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'brand': ${jsonEncode(BrandInfo.currentBrand)},
            'x-client-id': ${jsonEncode(BrandInfo.currentBrand)},
          },
          credentials: 'include',
          body: JSON.stringify({ username, password }),
        });

        let data = null;
        try {
          data = await response.json();
        } catch (_) {}

        const message =
          data && data.message ? data.message.toString() : '';

        if (response.ok && message.toLowerCase().includes('success')) {
          return 'api-success';
        }

        return 'api-failed::' + (message || response.statusText || response.status);
      } catch (err) {
        return 'api-error::' + (err && err.message ? err.message : err);
      }
    })();
  ''';
