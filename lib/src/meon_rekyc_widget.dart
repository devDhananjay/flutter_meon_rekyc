import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import 'permission_script.dart';
import 'permissions_helper.dart';
import 'rekyc_api.dart';

typedef ReKycSuccessCallback = void Function(Map<String, dynamic> data);
typedef ReKycErrorCallback = void Function(String error);
typedef ReKycCloseCallback = void Function();

/// Re-KYC flow widget — mirrors [react-native-meon-rekyc] behaviour.
class MeonReKYC extends StatefulWidget {
  const MeonReKYC({
    super.key,
    required this.username,
    required this.password,
    required this.companyId,
    required this.workflowId,
    required this.clientCode,
    this.baseUrl = defaultBaseUrl,
    this.onSuccess,
    this.onError,
    this.onClose,
    this.showHeader = true,
    this.headerTitle = 'Re-KYC',
    this.showRefreshButton = true,
    this.autoRequestPermissions = true,
    this.headerBackgroundColor,
    this.headerTitleStyle,
  });

  final String username;
  final String password;
  final String companyId;
  final String workflowId;
  final String clientCode;
  final String baseUrl;
  final ReKycSuccessCallback? onSuccess;
  final ReKycErrorCallback? onError;
  final ReKycCloseCallback? onClose;
  final bool showHeader;
  final String headerTitle;
  final bool showRefreshButton;
  final bool autoRequestPermissions;
  final Color? headerBackgroundColor;
  final TextStyle? headerTitleStyle;

  @override
  State<MeonReKYC> createState() => _MeonReKYCState();
}

class _MeonReKYCState extends State<MeonReKYC> {
  static const _primaryColor = Color(0xFF0047AB);

  bool _isInitializing = true;
  bool _webViewLoading = false;
  String? _deeplink;
  String? _error;
  bool _canGoBack = false;
  bool _permissionsGranted = false;
  bool _isIpvStep = false;

  WebViewController? _controller;
  bool _sessionStarted = false;
  bool _ipvPermissionRequested = false;

  @override
  void initState() {
    super.initState();
    _startSession();
  }

  String? _validateFields() {
    final fields = <String, String>{
      'username': widget.username,
      'password': widget.password,
      'company_id': widget.companyId,
      'workflow_id': widget.workflowId,
      'client_code': widget.clientCode,
    };

    final missing = fields.entries
        .where((e) => e.value.trim().isEmpty)
        .map((e) => e.key)
        .toList();

    if (missing.isEmpty) return null;
    return 'Missing required field(s): ${missing.join(', ')}';
  }

  Future<bool> _requestPermissions({bool showAlert = true}) async {
    if (!widget.autoRequestPermissions) {
      if (mounted) setState(() => _permissionsGranted = true);
      return true;
    }

    final granted = await PermissionsHelper.requestReKycPermissions(
      showAlert: false,
    );

    if (mounted) setState(() => _permissionsGranted = granted);

    if (!granted && showAlert && mounted) {
      await PermissionsHelper.showPermissionDialog(context);
    }

    return granted;
  }

  Future<void> _injectPermissionScripts([bool? grantedOverride]) async {
    final controller = _controller;
    if (controller == null) return;

    final granted = grantedOverride ?? _permissionsGranted;
    await controller.runJavaScript(buildPermissionInjectionScript(granted));
  }

  void _initWebView(String deeplink) {
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final controller = WebViewController.fromPlatformCreationParams(params);
    _controller = controller;

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/91.0.4472.124 Mobile Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _webViewLoading = true);
          },
          onPageFinished: (_) async {
            if (mounted) setState(() => _webViewLoading = false);
            await _injectPermissionScripts();
          },
          onWebResourceError: (error) {
            final message =
                error.description.isNotEmpty
                    ? error.description
                    : 'Failed to load Re-KYC page';
            if (mounted) {
              setState(() {
                _error = message;
                _webViewLoading = false;
              });
            }
            widget.onError?.call(message);
          },
          onUrlChange: (change) async {
            final url = change.url;
            if (url == null) return;

            final canGoBack = await _controller?.canGoBack() ?? false;
            if (mounted) setState(() => _canGoBack = canGoBack);

            final onIpv = checkIfIpvStep(url);
            if (mounted) setState(() => _isIpvStep = onIpv);

            if (onIpv) {
              if (!_ipvPermissionRequested &&
                  widget.autoRequestPermissions &&
                  !_permissionsGranted) {
                _ipvPermissionRequested = true;
                final granted = await _requestPermissions(showAlert: true);
                await _injectPermissionScripts(granted);
                if (granted) {
                  await _controller?.reload();
                }
              } else {
                await _injectPermissionScripts(_permissionsGranted);
              }
            } else {
              _ipvPermissionRequested = false;
            }
          },
          onNavigationRequest: (_) => NavigationDecision.navigate,
        ),
      );

    if (controller.platform is WebKitWebViewController) {
      final webKitController = controller.platform as WebKitWebViewController;
      webKitController.setOnPlatformPermissionRequest((request) async {
        await request.grant();
      });
    }

    if (controller.platform is AndroidWebViewController) {
      final androidController =
          controller.platform as AndroidWebViewController;
      androidController.setMediaPlaybackRequiresUserGesture(false);
      androidController.setOnPlatformPermissionRequest((request) async {
        await request.grant();
      });
    }

    controller.loadRequest(Uri.parse(deeplink));
  }

  Future<void> _startSession() async {
    if (_sessionStarted) return;
    _sessionStarted = true;

    final validationError = _validateFields();
    if (validationError != null) {
      if (mounted) {
        setState(() {
          _error = validationError;
          _isInitializing = false;
        });
      }
      widget.onError?.call(validationError);
      return;
    }

    if (mounted) {
      setState(() {
        _isInitializing = true;
        _error = null;
      });
    }

    try {
      if (widget.autoRequestPermissions) {
        await _requestPermissions(showAlert: false);
      } else if (mounted) {
        setState(() => _permissionsGranted = true);
      }

      final session = await initializeReKycSession(
        username: widget.username.trim(),
        password: widget.password,
        companyId: widget.companyId.trim(),
        workflowId: widget.workflowId.trim(),
        clientCode: widget.clientCode.trim(),
        baseUrl: widget.baseUrl,
      );

      _initWebView(session.deeplink);

      widget.onSuccess?.call({
        'status': 'session_ready',
        'deeplink': session.deeplink,
        'companyUsername': session.companyUsername,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      });

      if (mounted) {
        setState(() {
          _deeplink = session.deeplink;
          _isInitializing = false;
        });
      }
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      if (mounted) {
        setState(() {
          _error = message;
          _isInitializing = false;
        });
      }
      widget.onError?.call(message);
      _sessionStarted = false;
    }
  }

  void _handleRetry() {
    _sessionStarted = false;
    _controller = null;
    _deeplink = null;
    _startSession();
  }

  void _handleRefresh() {
    final controller = _controller;
    if (controller == null) return;
    setState(() => _webViewLoading = true);
    controller.reload();
  }

  Future<void> _handleClose() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Close Re-KYC'),
        content: const Text('Are you sure you want to close?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Close'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      widget.onClose?.call();
    }
  }

  Future<void> _handleHeaderBack() async {
    final controller = _controller;
    if (_canGoBack && controller != null) {
      if (await controller.canGoBack()) {
        await controller.goBack();
        return;
      }
    }
    await _handleClose();
  }

  Widget _headerButton({
    required String label,
    required VoidCallback onPressed,
    String? semanticsLabel,
  }) {
    return Semantics(
      label: semanticsLabel,
      button: true,
      child: Material(
        color: Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onPressed,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget? _buildHeader() {
    if (!widget.showHeader) return null;

    final title =
        _isIpvStep ? 'Video Verification' : widget.headerTitle;

    return Material(
      color: widget.headerBackgroundColor ?? Colors.white,
      elevation: 2,
      child: SafeArea(
        bottom: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: widget.headerBackgroundColor ?? Colors.white,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          child: Row(
            children: [
              _headerButton(
                label: _canGoBack ? '←' : '✕',
                onPressed: _handleHeaderBack,
              ),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: widget.headerTitleStyle ??
                      const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF333333),
                      ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.showRefreshButton)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _headerButton(
                        label: '⟳',
                        semanticsLabel: 'Refresh page',
                        onPressed: _handleRefresh,
                      ),
                    ),
                  _headerButton(
                    label: '✕',
                    onPressed: _handleClose,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _loader({String message = 'Initializing Re-KYC...'}) {
    return ColoredBox(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: _primaryColor),
            const SizedBox(height: 15),
            Text(
              message,
              style: const TextStyle(fontSize: 16, color: Color(0xFF666666)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorView() {
    return ColoredBox(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Error',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _error ?? 'Unknown error',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Color(0xFF666666)),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _handleRetry,
                style: FilledButton.styleFrom(
                  backgroundColor: _primaryColor,
                ),
                child: const Text('Retry'),
              ),
              if (widget.autoRequestPermissions && !_permissionsGranted) ...[
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: PermissionsHelper.openAppSettings,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF555555),
                  ),
                  child: const Text('Open Settings'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return _loader();
    }

    if (_error != null) {
      return _errorView();
    }

    if (_deeplink == null || _controller == null) {
      return _errorView();
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final controller = _controller;
        if (controller != null && await controller.canGoBack()) {
          await controller.goBack();
          if (mounted) setState(() => _canGoBack = true);
        }
      },
      child: ColoredBox(
        color: Colors.white,
        child: Column(
          children: [
            if (_buildHeader() != null) _buildHeader()!,
            Expanded(
              child: Stack(
                children: [
                  WebViewWidget(controller: _controller!),
                  if (_webViewLoading)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _primaryColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
