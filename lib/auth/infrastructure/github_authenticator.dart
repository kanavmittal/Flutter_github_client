import 'package:dartz/dartz.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oauth2/oauth2.dart';
import 'package:repo_viewer/auth/domain/auth_failure.dart';
import 'package:repo_viewer/auth/infrastructure/credentials_storage/credential_storage.dart';
import 'package:http/http.dart' as http;

class GithubOAuthHttpClient extends http.BaseClient{
  final httpClient= http.Client();
  @Override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Accept']='application/json';
    return httpClient.send(request);
  }
}
class GithubAuthenticator{ 

  final CredentialsStorage _credentialsStorage;
  GithubAuthenticator(this._credentialsStorage);

  static final authorizationEndpoint = Uri.parse('https://github.com/login/oauth/authorize');
  static final tokenEndpoint = Uri.parse('https://github.com/login/oauth/access_token');
  static final redirectUrl = Uri.parse('');
  static const clientId = "";
  static const clientSecret="";
  static const scopes = ['read:user',"repo"];
   
  Future<Credentials?> getSignedInCredentials() async{
    try{
      final storedCredentials = await _credentialsStorage.read();
      return storedCredentials;
    } on PlatformException {
      return null;
    }
  }
  Future<bool> isSignedIn() => getSignedInCredentials().then((credentials) => credentials!=null);
  AuthorizationCodeGrant createGrant() {
    return AuthorizationCodeGrant(
      clientId,
      authorizationEndpoint,
      tokenEndpoint,
      secret: clientSecret,
      httpClient: GithubOAuthHttpClient(),
    );
  }
  Uri getAuthorizationUrl(AuthorizationCodeGrant grant){
    return grant.getAuthorizationUrl(redirectUrl, scopes: scopes);
  } 
  Future<Either<AuthFailure, Unit>> handleAuthorizationResponse(AuthorizationCodeGrant grant ,Map<String, String> queryParams) async {
    try {
      final httpClient = await grant.handleAuthorizationResponse(queryParams);
      await _credentialsStorage.save(httpClient.credentials);
      return right(unit);
    } on FormatException {
      return left(const AuthFailure.server());
    } on AuthorizationException catch(e) {
      return left(AuthFailure.server('${e.error}: ${e.description}'));      
    } on PlatformException { 
      return left(const AuthFailure.storage());
    } 
  }

  Future<Either<AuthFailure, Unit>> signOut() async {
    try{
      await _credentialsStorage.clear();
      return right(unit);
    } on PlatformException{
      return left(const AuthFailure.storage());
    }
  }
} 