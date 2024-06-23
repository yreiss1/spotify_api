import 'dart:async';

import 'package:meta/meta.dart';
import 'package:spotify_api/src/api_models/auth/request.dart';
import 'package:spotify_api/src/api_models/auth/response.dart';
import 'package:spotify_api/src/auth/access_token_refresher.dart';
import 'package:spotify_api/src/auth/common.dart';
import 'package:spotify_api/src/auth/scopes.dart';
import 'package:spotify_api/src/auth/user_authorization.dart';
import 'package:spotify_api/src/auth/pkce.dart';
import 'package:spotify_api/src/requests.dart';

@immutable
final class AuthorizationCodeRefresher implements AccessTokenRefresher {
  final String _clientId;
  final String _clientSecret;
  final RefreshTokenStorage _refreshTokenStorage;

  AuthorizationCodeRefresher({
    required String clientId,
    required String clientSecret,
    required RefreshTokenStorage refreshTokenStorage,
  })  : _clientId = clientId,
        _clientSecret = clientSecret,
        _refreshTokenStorage = refreshTokenStorage;

  @override
  Future<TokenInfo> retrieveToken(RequestsClient client) async {
    final refreshToken = await _refreshTokenStorage.load();
    return await _refreshAccessToken(client, refreshToken);
  }

  Future<TokenInfo> _refreshAccessToken(
    RequestsClient client,
    String refreshToken,
  ) async {
    final url = baseAuthUrl.resolve('/api/token');
    final now = DateTime.now();
    final response = await client.post(
      url,
      headers: [
        Header.basicAuth(
          username: _clientId,
          password: _clientSecret,
        ),
      ],
      body: RequestBody.formData({
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
        'client_id': _clientId,
      }),
    );

    if (!response.isSuccessful) {
      throw RefreshException('Could not refresh access token');
    }

    final token = response.body.decodeJson(TokenResponse.fromJson);
    final accessToken = TokenInfo(
      value: token.accessToken,
      expiration: now.add(Duration(seconds: token.expiresIn)),
    );

    final newRefreshToken = token.refreshToken;
    if (newRefreshToken != null) {
      await _refreshTokenStorage.store(newRefreshToken);
    }

    return accessToken;
  }
}

@immutable
final class AuthorizationCodeUserAuthorization extends UserAuthorizationFlow {
  final String _clientSecret;

  AuthorizationCodeUserAuthorization({
    required super.clientId,
    required super.redirectUri,
    required super.stateManager,
    required String clientSecret,
    super.codeVerifierStorage,
  }) : _clientSecret = clientSecret;

  Future<String> _obtainRefreshToken({
    required RequestsClient client,
    required String authorizationCode,
    required String? codeVerifier,
  }) async {
    final url = baseAuthUrl.resolve('/api/token');
    final response = await client.post(
      url,
      headers: [
        Header.basicAuth(username: clientId, password: _clientSecret),
      ],
      body: RequestBody.formData({
        'grant_type': 'authorization_code',
        'code': authorizationCode,
        'redirect_uri': redirectUri.toString(),
        'client_id': clientId,
        if (codeVerifier != null) 'code_verifier': codeVerifier,
      }),
    );

    if (!response.isSuccessful) {
      throw UserAuthorizationException(
        'Could not obtain a refresh token, got response ${response.statusCode}',
      );
    }

    final token = response.body.decodeJson(TokenResponse.fromJson);
    final refreshToken = token.refreshToken;

    if (refreshToken == null) {
      throw UserAuthorizationException('Did not receive a refresh token!');
    }

    return refreshToken;
  }

  Future<String?> _generateCodeChallenge(String state) async {
    final storage = codeVerifierStorage;
    if (storage == null) {
      return null;
    }

    final codeVerifier = generateCodeVerifier();
    await storage.store(state: state, codeVerifier: codeVerifier);
    return generateCodeChallenge(codeVerifier);
  }

  @override
  Future<Uri> generateAuthorizationUrl({
    required List<Scope> scopes,
    String? userContext,
  }) async {
    final state = await stateManager.createState(userContext: userContext);
    final codeChallenge = await _generateCodeChallenge(state);
    final authorizeUrl = baseAuthUrl.resolve('/authorize');
    return authorizeUrl.replace(
      queryParameters: {
        'client_id': clientId,
        'response_type': 'code',
        'redirect_uri': redirectUri.toString(),
        'state': state,
        'scope': scopes.map((s) => s.code).join(' '),
        if (codeChallenge != null) 'code_challenge_method': 'S256',
        if (codeChallenge != null) 'code_challenge': codeChallenge,
      },
    );
  }

  Future<String?> _retrieveCodeVerifier(String state) async {
    final storage = codeVerifierStorage;
    if (storage == null) {
      return null;
    }

    final verifier = await storage.load(state: state);
    if (verifier == null) {
      throw UserAuthorizationException('Did not find code verifier for state');
    }

    return verifier;
  }

  @override
  Future<String> handleCallback({
    String? userContext,
    required UserAuthorizationCallbackBody callback,
  }) async {
    if (!await stateManager.validateState(
      state: callback.state,
      userContext: userContext,
    )) {
      throw StateMismatchException();
    }

    final error = callback.error;
    if (error != null) {
      throw UserAuthorizationException('Received error in callback: $error');
    }

    final code = callback.code;
    if (code == null) {
      throw UserAuthorizationException(
        'Receive null code even though there was no error',
      );
    }

    final codeVerifier = await _retrieveCodeVerifier(callback.state);

    final client = RequestsClient();
    try {
      return await _obtainRefreshToken(
        client: client,
        authorizationCode: code,
        codeVerifier: codeVerifier,
      );
    } finally {
      client.close();
    }
  }
}
