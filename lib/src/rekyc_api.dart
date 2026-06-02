import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

const String defaultBaseUrl = 'https://rekyc.meon.co.in';

class CompanyLoginResult {
  const CompanyLoginResult({
    required this.accessToken,
    this.refreshToken,
    this.companyUsername,
    this.raw,
  });

  final String accessToken;
  final String? refreshToken;
  final String? companyUsername;
  final Map<String, dynamic>? raw;
}

class DeepLinkResult {
  const DeepLinkResult({
    required this.deeplink,
    this.raw,
  });

  final String deeplink;
  final Map<String, dynamic>? raw;
}

class ReKycSessionResult {
  const ReKycSessionResult({
    required this.accessToken,
    required this.deeplink,
    this.refreshToken,
    this.companyUsername,
    this.loginRaw,
    this.deeplinkRaw,
  });

  final String accessToken;
  final String deeplink;
  final String? refreshToken;
  final String? companyUsername;
  final Map<String, dynamic>? loginRaw;
  final Map<String, dynamic>? deeplinkRaw;
}

void _logApi(String label, Object? payload) {
  if (kDebugMode) {
    debugPrint('[MeonReKYC API] $label $payload');
  }
}

Map<String, dynamic> _parseJsonResponse(http.Response response) {
  final text = response.body;
  if (text.isEmpty) {
    throw Exception('Request failed with status ${response.statusCode}');
  }
  try {
    return jsonDecode(text) as Map<String, dynamic>;
  } catch (_) {
    throw Exception(text);
  }
}

String _apiMessage(Map<String, dynamic> data, String fallback) {
  final candidates = [
    data['msg'],
    data['message'],
    data['error'],
    data['data'] is Map ? (data['data'] as Map)['msg'] : null,
    data['data'] is Map ? (data['data'] as Map)['message'] : null,
  ];
  for (final value in candidates) {
    if (value != null && value.toString().trim().isNotEmpty) {
      return value.toString();
    }
  }
  return fallback;
}

String? _extractDeeplink(Map<String, dynamic> data) {
  final payload = data['data'];
  if (payload is Map<String, dynamic>) {
    final nested = payload['deeplink'] ?? payload['deep_link'];
    if (nested != null && nested.toString().trim().isNotEmpty) {
      return nested.toString();
    }
  }

  final topLevel = data['deeplink'] ?? data['deep_link'];
  if (topLevel != null && topLevel.toString().trim().isNotEmpty) {
    return topLevel.toString();
  }

  return null;
}

bool _isApiSuccess(Map<String, dynamic> data, http.Response response) {
  if (response.statusCode < 200 || response.statusCode >= 300) {
    return false;
  }
  if (data['success'] == true) {
    return true;
  }
  if (data['success']?.toString() == 'true') {
    return true;
  }
  if (data['status']?.toString().toLowerCase() == 'success') {
    return true;
  }
  return false;
}

Future<CompanyLoginResult> companyLogin({
  required String username,
  required String password,
  required String companyId,
  String baseUrl = defaultBaseUrl,
}) async {
  final loginUrl = '$baseUrl/v1/company/company-login';
  _logApi('REQUEST company-login', loginUrl);

  final response = await http.post(
    Uri.parse(loginUrl),
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'username': username,
      'password': password,
      'company_id': companyId,
    }),
  );

  final data = _parseJsonResponse(response);
  _logApi('RESPONSE company-login', data);

  if (!_isApiSuccess(data, response)) {
    throw Exception(_apiMessage(data, 'Company login failed'));
  }

  final payload = data['data'];
  if (payload is! Map<String, dynamic>) {
    throw Exception(_apiMessage(data, 'Invalid login response'));
  }

  final accessToken = payload['access_token']?.toString();
  if (accessToken == null || accessToken.isEmpty) {
    throw Exception(_apiMessage(data, 'Access token not found in login response'));
  }

  return CompanyLoginResult(
    accessToken: accessToken,
    refreshToken: payload['refresh_token']?.toString(),
    companyUsername: payload['company_username']?.toString(),
    raw: data,
  );
}

Future<DeepLinkResult> getDeepLink({
  required String workflowId,
  required String clientCode,
  required String accessToken,
  String baseUrl = defaultBaseUrl,
}) async {
  final encodedWorkflowId = Uri.encodeComponent(workflowId);
  final encodedClientCode = Uri.encodeComponent(clientCode);
  final url =
      '$baseUrl/v1/company/get_deep_link/$encodedWorkflowId/$encodedClientCode';

  _logApi('REQUEST get_deep_link', url);

  final response = await http.get(
    Uri.parse(url),
    headers: {
      'Accept': 'application/json',
      'Authorization': 'Bearer $accessToken',
    },
  );

  final data = _parseJsonResponse(response);
  final deeplink = _extractDeeplink(data);

  _logApi('RESPONSE get_deep_link', {
    'msg': data['msg'],
    'deeplink': deeplink,
    'full': data,
  });

  if (!_isApiSuccess(data, response)) {
    throw Exception(_apiMessage(data, 'Failed to generate deeplink'));
  }

  if (deeplink == null || deeplink.isEmpty) {
    throw Exception(_apiMessage(data, 'Deeplink URL not found in response'));
  }

  return DeepLinkResult(deeplink: deeplink, raw: data);
}

Future<ReKycSessionResult> initializeReKycSession({
  required String username,
  required String password,
  required String companyId,
  required String workflowId,
  required String clientCode,
  String baseUrl = defaultBaseUrl,
}) async {
  _logApi('initializeReKycSession start', {
    'baseUrl': baseUrl,
    'workflowId': workflowId,
    'clientCode': clientCode,
    'companyId': companyId,
    'username': username,
  });

  final loginResult = await companyLogin(
    username: username,
    password: password,
    companyId: companyId,
    baseUrl: baseUrl,
  );

  final deeplinkResult = await getDeepLink(
    workflowId: workflowId,
    clientCode: clientCode,
    accessToken: loginResult.accessToken,
    baseUrl: baseUrl,
  );

  _logApi('initializeReKycSession done', deeplinkResult.deeplink);

  return ReKycSessionResult(
    accessToken: loginResult.accessToken,
    deeplink: deeplinkResult.deeplink,
    refreshToken: loginResult.refreshToken,
    companyUsername: loginResult.companyUsername,
    loginRaw: loginResult.raw,
    deeplinkRaw: deeplinkResult.raw,
  );
}
