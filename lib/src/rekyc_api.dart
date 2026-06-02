import 'dart:convert';

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

Future<CompanyLoginResult> companyLogin({
  required String username,
  required String password,
  required String companyId,
  String baseUrl = defaultBaseUrl,
}) async {
  final response = await http.post(
    Uri.parse('$baseUrl/v1/company/company-login'),
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
  final success = data['success'] == true;

  if (response.statusCode < 200 ||
      response.statusCode >= 300 ||
      !success) {
    throw Exception(data['msg']?.toString() ?? 'Company login failed');
  }

  final payload = data['data'];
  if (payload is! Map<String, dynamic>) {
    throw Exception('Invalid login response');
  }

  final accessToken = payload['access_token']?.toString();
  if (accessToken == null || accessToken.isEmpty) {
    throw Exception('Access token not found in login response');
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

  final response = await http.get(
    Uri.parse(url),
    headers: {
      'Accept': 'application/json',
      'Authorization': 'Bearer $accessToken',
    },
  );

  final data = _parseJsonResponse(response);
  final success = data['success'] == true;

  if (response.statusCode < 200 ||
      response.statusCode >= 300 ||
      !success) {
    throw Exception(data['msg']?.toString() ?? 'Failed to generate deeplink');
  }

  final payload = data['data'];
  if (payload is! Map<String, dynamic>) {
    throw Exception('Invalid deeplink response');
  }

  final deeplink = payload['deeplink']?.toString();
  if (deeplink == null || deeplink.isEmpty) {
    throw Exception('Deeplink URL not found in response');
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

  return ReKycSessionResult(
    accessToken: loginResult.accessToken,
    deeplink: deeplinkResult.deeplink,
    refreshToken: loginResult.refreshToken,
    companyUsername: loginResult.companyUsername,
    loginRaw: loginResult.raw,
    deeplinkRaw: deeplinkResult.raw,
  );
}
