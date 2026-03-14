import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../models/api_config.dart';
import '../models/oauth_account.dart';

class OAuthResolvedCredential {
  const OAuthResolvedCredential({
    required this.account,
    required this.accessToken,
  });

  final OAuthAccount account;
  final String accessToken;
}

class OAuthAuthorizationSession {
  OAuthAuthorizationSession._({
    required this.id,
    required this.provider,
    required this.clientId,
    required this.authUrl,
    required this.redirectUri,
    required this.codeVerifier,
    required this.state,
    this.clientSecret,
    required _LoopbackCallbackServer? server,
  }) : _server = server;

  final String id;
  final OAuthAccountProvider provider;
  final String clientId;
  final String? clientSecret;
  final Uri authUrl;
  final String redirectUri;
  final String codeVerifier;
  final String state;
  final _LoopbackCallbackServer? _server;

  bool get supportsAutomaticCallback => _server != null;

  Future<String?> waitForCallback({Duration timeout = const Duration(minutes: 3)}) {
    final server = _server;
    if (server == null) {
      return Future.value(null);
    }
    return server.waitForCallback(timeout: timeout);
  }

  Future<void> dispose() async {
    final server = _server;
    if (server != null) {
      await server.dispose();
    }
  }
}

class OAuthAccountService {
  OAuthAccountService._();

  static final OAuthAccountService instance = OAuthAccountService._();

  static const _storageKey = 'oauth_accounts_v1';
  static const _codexClientId = 'app_EMoamEEZ73f0CkXaXp7hrann';
  static const _codexAuthUrl = 'https://auth.openai.com/oauth/authorize';
  static const _codexTokenUrl = 'https://auth.openai.com/oauth/token';
  static const _codexRedirectUri = 'http://localhost:1455/auth/callback';
  static const _codexOriginator = 'codex_cli_rs';
  static const _codexScope =
      'openid profile email offline_access api.connectors.read api.connectors.invoke';
  static const _googleAuthUrl = 'https://accounts.google.com/o/oauth2/v2/auth';
  static const _googleTokenUrl = 'https://oauth2.googleapis.com/token';
  static const _googleUserInfoUrl =
      'https://www.googleapis.com/oauth2/v3/userinfo';
  static const _googleRedirectPath = '/oauth2callback';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  List<OAuthAccount>? _accountsCache;
  final Map<String, Future<OAuthAccount>> _refreshInFlight = {};

  Future<List<OAuthAccount>> loadAccounts() async {
    if (_accountsCache != null) {
      return List<OAuthAccount>.from(_accountsCache!);
    }
    try {
      final raw = await _readRawAccounts();
      if (raw == null || raw.trim().isEmpty) {
        _accountsCache = <OAuthAccount>[];
        return const <OAuthAccount>[];
      }
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        _accountsCache = <OAuthAccount>[];
        return const <OAuthAccount>[];
      }
      _accountsCache = decoded
          .whereType<Map>()
          .map((entry) => OAuthAccount.fromMap(Map<String, dynamic>.from(entry)))
          .toList(growable: true);
      return List<OAuthAccount>.from(_accountsCache!);
    } catch (e) {
      debugPrint('OAuthAccountService.loadAccounts failed: $e');
      _accountsCache = <OAuthAccount>[];
      return const <OAuthAccount>[];
    }
  }

  Future<void> saveAccounts(List<OAuthAccount> accounts) async {
    _accountsCache = List<OAuthAccount>.from(accounts);
    final encoded = jsonEncode(
      _accountsCache!.map((account) => account.toMap()).toList(growable: false),
    );
    await _writeRawAccounts(encoded);
  }

  Future<OAuthAccount?> getAccountById(String accountId) async {
    final accounts = await loadAccounts();
    for (final account in accounts) {
      if (account.id == accountId) {
        return account;
      }
    }
    return null;
  }

  Future<OAuthAccount> upsertAccount(OAuthAccount account) async {
    final accounts = await loadAccounts();
    final index = accounts.indexWhere((entry) => entry.id == account.id);
    if (index == -1) {
      accounts.add(account);
    } else {
      accounts[index] = account;
    }
    await saveAccounts(accounts);
    return account;
  }

  Future<void> removeAccount(String accountId) async {
    final accounts = await loadAccounts();
    accounts.removeWhere((account) => account.id == accountId);
    await saveAccounts(accounts);
  }

  Future<OAuthAuthorizationSession> beginAuthorization({
    required OAuthAccountProvider provider,
    String? clientId,
    String? clientSecret,
  }) async {
    switch (provider) {
      case OAuthAccountProvider.codex:
        final server = await _LoopbackCallbackServer.start(
          host: '127.0.0.1',
          port: 1455,
          callbackPath: '/auth/callback',
        );
        final state = _generateOpaqueString(length: 32);
        final codeVerifier = _generateCodeVerifier();
        final codeChallenge = _codeChallengeForVerifier(codeVerifier);
        final authUrl = Uri.parse(_codexAuthUrl).replace(
          queryParameters: {
             'response_type': 'code',
             'client_id': _codexClientId,
             'redirect_uri': _codexRedirectUri,
             'scope': _codexScope,
             'code_challenge': codeChallenge,
             'code_challenge_method': 'S256',
             'state': state,
             'id_token_add_organizations': 'true',
             'codex_cli_simplified_flow': 'true',
             'originator': _codexOriginator,
           },
         );
         return OAuthAuthorizationSession._(
          id: const Uuid().v4(),
          provider: provider,
          clientId: _codexClientId,
          authUrl: authUrl,
          redirectUri: _codexRedirectUri,
          codeVerifier: codeVerifier,
          state: state,
          server: server,
        );
      case OAuthAccountProvider.geminiGca:
        final server = await _LoopbackCallbackServer.start(
          host: '127.0.0.1',
          port: 0,
          callbackPath: _googleRedirectPath,
        );
        final state = _generateOpaqueString(length: 32);
        final codeVerifier = _generateCodeVerifier();
        final codeChallenge = _codeChallengeForVerifier(codeVerifier);
        final resolvedClientId = clientId?.trim() ?? '';
        final resolvedClientSecret = clientSecret?.trim() ?? '';
        if (resolvedClientId.isEmpty) {
          throw Exception('Google OAuth client ID is required for Gemini CLI login.');
        }
        if (resolvedClientSecret.isEmpty) {
          throw Exception('Google OAuth client secret is required for Gemini CLI login.');
        }
        final redirectPort = server?.port ?? 9004;
        final redirectUri = 'http://127.0.0.1:$redirectPort$_googleRedirectPath';
        final authUrl = Uri.parse(_googleAuthUrl).replace(
          queryParameters: {
            'client_id': resolvedClientId,
            'redirect_uri': redirectUri,
            'response_type': 'code',
            'scope': [
              'https://www.googleapis.com/auth/cloud-platform',
              'https://www.googleapis.com/auth/userinfo.email',
              'https://www.googleapis.com/auth/userinfo.profile',
            ].join(' '),
            'code_challenge': codeChallenge,
            'code_challenge_method': 'S256',
            'state': state,
            'access_type': 'offline',
            'prompt': 'consent',
          },
        );
         return OAuthAuthorizationSession._(
          id: const Uuid().v4(),
          provider: provider,
          clientId: resolvedClientId,
          clientSecret: resolvedClientSecret,
          authUrl: authUrl,
          redirectUri: redirectUri,
          codeVerifier: codeVerifier,
          state: state,
          server: server,
        );
    }
  }

  Future<bool> openAuthorizationUrl(OAuthAuthorizationSession session) async {
    return launchUrl(session.authUrl, mode: LaunchMode.externalApplication);
  }

  Future<OAuthAccount> completeAuthorization({
    required OAuthAuthorizationSession session,
    required String callbackOrCode,
    String? label,
    String? cloudProjectId,
    String? replaceAccountId,
  }) async {
    final normalized = callbackOrCode.trim();
    final parsed = Uri.tryParse(normalized);
    final code = _extractAuthorizationCode(normalized);
    if (code == null || code.isEmpty) {
      throw Exception('No authorization code found. Paste the callback URL or code.');
    }

    if (parsed != null && parsed.queryParameters.containsKey('state')) {
      final returnedState = parsed.queryParameters['state'];
      if (returnedState != null && returnedState != session.state) {
        throw Exception('OAuth state mismatch. Start the login flow again.');
      }
    }

    final tokenResponse = await _exchangeCodeForTokens(
      session: session,
      code: code,
      codeVerifier: session.codeVerifier,
      redirectUri: session.redirectUri,
    );

    OAuthAccount account = await _buildAccountFromTokenResponse(
      provider: session.provider,
      tokenResponse: tokenResponse,
      label: label,
      cloudProjectId: cloudProjectId,
      oauthClientId: session.provider == OAuthAccountProvider.geminiGca
          ? session.clientId
          : null,
      oauthClientSecret: session.provider == OAuthAccountProvider.geminiGca
          ? session.clientSecret
          : null,
      replaceAccountId: replaceAccountId,
    );
    await upsertAccount(account);
    await session.dispose();
    return account;
  }

  Future<OAuthResolvedCredential?> resolveCredentialForConfig(ApiConfig config) async {
    final accountId = config.oauthAccountId;
    if (accountId == null || accountId.trim().isEmpty) {
      return null;
    }
    final account = await getAccountById(accountId);
    if (account == null) {
      throw Exception('Linked OAuth account not found for preset ${config.name}.');
    }
    final refreshed = await refreshAccountIfNeeded(account);
    return OAuthResolvedCredential(
      account: refreshed,
      accessToken: refreshed.accessToken,
    );
  }

  Future<OAuthAccount> refreshAccountIfNeeded(OAuthAccount account) async {
    if (!account.isExpiringSoon || !account.hasRefreshToken) {
      return account;
    }

    final existingRefresh = _refreshInFlight[account.id];
    if (existingRefresh != null) {
      return existingRefresh;
    }

    final refreshFuture = _refreshAccountNow(account);
    _refreshInFlight[account.id] = refreshFuture;
    try {
      return await refreshFuture;
    } finally {
      _refreshInFlight.remove(account.id);
    }
  }

  Future<OAuthAccount> _refreshAccountNow(OAuthAccount account) async {
    
    final refreshedResponse = await _refreshTokens(account);
    final refreshed = account.copyWith(
      accessToken: refreshedResponse['access_token']?.toString() ?? account.accessToken,
      refreshToken: refreshedResponse['refresh_token']?.toString() ?? account.refreshToken,
      expiresAt: _expiresAtFromTokenResponse(refreshedResponse),
      idToken: refreshedResponse['id_token']?.toString() ?? account.idToken,
    );

    OAuthAccount normalized = refreshed;
    if (account.provider == OAuthAccountProvider.codex) {
      normalized = _applyCodexClaims(refreshed);
    } else {
      normalized = await _applyGoogleProfile(refreshed);
    }

    await upsertAccount(normalized);
    return normalized;
  }

  Future<OAuthAccount> updateAccountMetadata({
    required String accountId,
    String? label,
    String? cloudProjectId,
  }) async {
    final account = await getAccountById(accountId);
    if (account == null) {
      throw Exception('OAuth account not found.');
    }
    final updated = account.copyWith(
      label: label,
      cloudProjectId: cloudProjectId,
      clearCloudProjectId: cloudProjectId != null && cloudProjectId.trim().isEmpty,
    );
    await upsertAccount(updated);
    return updated;
  }

  Future<Map<String, dynamic>> _exchangeCodeForTokens({
    required OAuthAuthorizationSession session,
    required String code,
    required String codeVerifier,
    required String redirectUri,
  }) async {
    final Uri url;
    final Map<String, String> form;
    switch (session.provider) {
      case OAuthAccountProvider.codex:
        url = Uri.parse(_codexTokenUrl);
        form = {
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': redirectUri,
          'client_id': session.clientId,
          'code_verifier': codeVerifier,
        };
        break;
      case OAuthAccountProvider.geminiGca:
        url = Uri.parse(_googleTokenUrl);
        form = {
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': redirectUri,
          'client_id': session.clientId,
          if (session.clientSecret != null && session.clientSecret!.isNotEmpty)
            'client_secret': session.clientSecret!,
          'code_verifier': codeVerifier,
        };
        break;
    }

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: form,
    );
    final body = _decodeJsonMap(response.body);
    if (response.statusCode != 200) {
      throw Exception(
        'OAuth token exchange failed (${response.statusCode}): ${_extractError(body, response.body)}',
      );
    }
    return body;
  }

  Future<Map<String, dynamic>> _refreshTokens(OAuthAccount account) async {
    final refreshToken = account.refreshToken;
    if (refreshToken == null || refreshToken.trim().isEmpty) {
      throw Exception('This account cannot refresh automatically.');
    }

    final Uri url;
    final Map<String, String> form;
    switch (account.provider) {
      case OAuthAccountProvider.codex:
        url = Uri.parse(_codexTokenUrl);
        form = {
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
          'client_id': _codexClientId,
        };
        break;
      case OAuthAccountProvider.geminiGca:
        final clientId = account.oauthClientId?.trim() ?? '';
        final clientSecret = account.oauthClientSecret?.trim() ?? '';
        if (clientId.isEmpty) {
          throw Exception('Google OAuth client ID is missing for this Gemini account.');
        }
        url = Uri.parse(_googleTokenUrl);
        form = {
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
          'client_id': clientId,
          if (clientSecret.isNotEmpty) 'client_secret': clientSecret,
        };
        break;
    }

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: form,
    );
    final body = _decodeJsonMap(response.body);
    if (response.statusCode != 200) {
      throw Exception(
        'OAuth token refresh failed (${response.statusCode}): ${_extractError(body, response.body)}',
      );
    }
    return body;
  }

  Future<OAuthAccount> _buildAccountFromTokenResponse({
    required OAuthAccountProvider provider,
    required Map<String, dynamic> tokenResponse,
    String? label,
    String? cloudProjectId,
    String? oauthClientId,
    String? oauthClientSecret,
    String? replaceAccountId,
  }) async {
    final accessToken = tokenResponse['access_token']?.toString();
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('OAuth access token missing from provider response.');
    }

    OAuthAccount account = OAuthAccount(
      id: replaceAccountId,
      provider: provider,
      label: label?.trim() ?? '',
      accessToken: accessToken,
      refreshToken: tokenResponse['refresh_token']?.toString(),
      expiresAt: _expiresAtFromTokenResponse(tokenResponse),
      idToken: tokenResponse['id_token']?.toString(),
      cloudProjectId: cloudProjectId?.trim().isEmpty == true
          ? null
          : cloudProjectId?.trim(),
      oauthClientId: oauthClientId?.trim().isEmpty == true ? null : oauthClientId?.trim(),
      oauthClientSecret: oauthClientSecret?.trim().isEmpty == true
          ? null
          : oauthClientSecret?.trim(),
    );

    switch (provider) {
      case OAuthAccountProvider.codex:
        account = _applyCodexClaims(account);
        break;
      case OAuthAccountProvider.geminiGca:
        account = await _applyGoogleProfile(account);
        break;
    }

    if (account.label.trim().isEmpty) {
      account = account.copyWith(label: account.displayLabel);
    }

    return account;
  }

  OAuthAccount _applyCodexClaims(OAuthAccount account) {
    final token = account.idToken ?? account.accessToken;
    final claims = _decodeJwtPayload(token);
    final authClaims = _mapFromNested(claims['https://api.openai.com/auth']);
    final profileClaims = _mapFromNested(claims['https://api.openai.com/profile']);

    return account.copyWith(
      email: claims['email']?.toString(),
      displayName: profileClaims['name']?.toString() ?? claims['name']?.toString(),
      chatgptAccountId: authClaims['chatgpt_account_id']?.toString(),
      organizationId: authClaims['organization_id']?.toString(),
      projectId: authClaims['project_id']?.toString(),
      planType: authClaims['chatgpt_plan_type']?.toString(),
    );
  }

  Future<OAuthAccount> _applyGoogleProfile(OAuthAccount account) async {
    try {
      final response = await http.get(
        Uri.parse(_googleUserInfoUrl),
        headers: {'Authorization': 'Bearer ${account.accessToken}'},
      );
      if (response.statusCode != 200) {
        return account;
      }
      final body = _decodeJsonMap(response.body);
      return account.copyWith(
        email: body['email']?.toString(),
        displayName: body['name']?.toString(),
      );
    } catch (_) {
      return account;
    }
  }

  DateTime? _expiresAtFromTokenResponse(Map<String, dynamic> body) {
    final expiresIn = body['expires_in'];
    if (expiresIn is num) {
      return DateTime.now().add(Duration(seconds: expiresIn.round()));
    }
    if (expiresIn is String) {
      final seconds = int.tryParse(expiresIn);
      if (seconds != null) {
        return DateTime.now().add(Duration(seconds: seconds));
      }
    }
    return null;
  }

  Future<String?> _readRawAccounts() async {
    return _secureStorage.read(key: _storageKey);
  }

  Future<void> _writeRawAccounts(String value) async {
    await _secureStorage.write(key: _storageKey, value: value);
  }

  String? _extractAuthorizationCode(String input) {
    final uri = Uri.tryParse(input);
    if (uri != null && uri.queryParameters.containsKey('code')) {
      return uri.queryParameters['code'];
    }
    if (!input.contains('://') && !input.contains('?')) {
      return input;
    }
    return null;
  }

  Map<String, dynamic> _decodeJsonMap(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    return <String, dynamic>{};
  }

  String _extractError(Map<String, dynamic> body, String fallback) {
    return body['error_description']?.toString() ??
        body['error']?.toString() ??
        body['message']?.toString() ??
        fallback;
  }

  Map<String, dynamic> _decodeJwtPayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) {
        return const <String, dynamic>{};
      }
      final normalized = base64Url.normalize(parts[1]);
      final payload = utf8.decode(base64Url.decode(normalized));
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return const <String, dynamic>{};
  }

  Map<String, dynamic> _mapFromNested(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return const <String, dynamic>{};
  }

  String _generateCodeVerifier() {
    return _generateOpaqueString(length: 64);
  }

  String _codeChallengeForVerifier(String codeVerifier) {
    final digest = sha256.convert(utf8.encode(codeVerifier));
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  String _generateOpaqueString({required int length}) {
    const alphabet =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final random = Random.secure();
    final buffer = StringBuffer();
    for (int i = 0; i < length; i++) {
      buffer.write(alphabet[random.nextInt(alphabet.length)]);
    }
    return buffer.toString();
  }
}

class _LoopbackCallbackServer {
  _LoopbackCallbackServer._(this._server, this._callbackPath);

  final HttpServer _server;
  final String _callbackPath;
  final Completer<String?> _callbackCompleter = Completer<String?>();

  int get port => _server.port;

  static Future<_LoopbackCallbackServer?> start({
    required String host,
    required int port,
    required String callbackPath,
  }) async {
    try {
      final server = await HttpServer.bind(host, port);
      final loopbackServer = _LoopbackCallbackServer._(server, callbackPath);
      unawaited(loopbackServer._listen());
      return loopbackServer;
    } catch (e) {
      debugPrint('OAuth loopback server failed to start: $e');
      return null;
    }
  }

  Future<void> _listen() async {
    await for (final request in _server) {
      final uri = request.uri;
      if (uri.path == _callbackPath && uri.queryParameters.containsKey('code')) {
        if (!_callbackCompleter.isCompleted) {
          _callbackCompleter.complete(uri.toString());
        }
        request.response.headers.contentType = ContentType.html;
        request.response.write(
          '<html><body><h3>Authentication complete.</h3><p>You can return to Pocket Waifu.</p></body></html>',
        );
        await request.response.close();
        await dispose();
        break;
      }
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    }
  }

  Future<String?> waitForCallback({required Duration timeout}) async {
    return _callbackCompleter.future.timeout(
      timeout,
      onTimeout: () => null,
    );
  }

  Future<void> dispose() async {
    if (!_callbackCompleter.isCompleted) {
      _callbackCompleter.complete(null);
    }
    await _server.close(force: true);
  }
}
