import 'dart:async';

import 'package:firebase/firebase.dart' as web_fb;
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

class FirebaseAuthPlugin {

  static int _handleCounter = 0;
  static final Map<int, StreamSubscription<dynamic>> _authSubscriptions = {};

  static web_fb.Auth _getAuthForApp(String appName) => web_fb.auth(web_fb.app(appName));

  static MethodChannel _channel;

  static void registerWith(Registrar registrar) {
    _channel = MethodChannel(
      'plugins.flutter.io/firebase_auth',
      const StandardMethodCodec(),
      registrar.messenger,
    );
    final FirebaseAuthPlugin instance = FirebaseAuthPlugin();
    _channel.setMethodCallHandler(instance.onMethodCall);
  }

  Future<dynamic> onMethodCall(MethodCall call) {
    try {
      switch (call.method) {
        case "startListeningAuthState":
          return _addAuthListener(call.arguments["app"]);
        case "stopListeningAuthState":
          return _removeAuthListener(call.arguments["id"]);
        case "createUserWithEmailAndPassword":
          return _createUserWithEmailAndPassword(call.arguments["app"], call.arguments["email"], call.arguments["password"]);
        case "sendPasswordResetEmail":
          return _sendPasswordResetEmail(call.arguments["app"], call.arguments["email"]);
        case "signInWithCredential":
          return _signInWithCredential(call.arguments["app"], call.arguments["provider"], call.arguments["data"]);
        case "currentUser":
          return _currentUser(call.arguments["app"]);
        case "signOut":
          return _signOut(call.arguments["app"]);
        case "getIdToken":
          return _getIdToken(call.arguments["app"], call.arguments["refresh"]);
        default:
          throw PlatformException(
              code: 'Unimplemented',
              details:
                  "The firebase_auth plugin for web doesn't implement "
                  "the method '${call.method}'");
          break;
      }
    } catch (e, stackTrace) {
      throw PlatformException(
          code: "PlatformError",
          message: e.toString(),
          details: stackTrace.toString());
    }
  }

  Future<int> _addAuthListener(String appName) {
    final web_fb.Auth auth = _getAuthForApp(appName);
    final int thisHandle = _handleCounter++;
    _authSubscriptions[thisHandle] = auth.onAuthStateChanged.listen((web_fb.User user) {
      _channel.invokeMethod<dynamic>("onAuthStateChanged", <dynamic, dynamic>{
        "id": thisHandle,
        "user": _mapUserToFirebaseUser(user),
      });
    });

    return Future<int>.value(thisHandle);
  }

  Map<dynamic, dynamic> _mapUserToUserInfo(web_fb.UserInfo<dynamic> user) {
    return <dynamic, dynamic>{
      "providerId": user.providerId,
      "uid": user.uid,
      "displayName": user.displayName,
      "photoUrl": user.photoURL,
      "email": user.email,
      "phoneNumber": user.phoneNumber,
    };
  }

  Map<dynamic, dynamic> _mapUserToFirebaseUser(web_fb.User user) {
    final Map<dynamic, dynamic> firebaseUser = _mapUserToUserInfo(user);
    firebaseUser["creationTimestamp"] = user.metadata.creationTime;
    firebaseUser["lastSignInTimestamp"] = user.metadata.creationTime;
    firebaseUser["providerData"] = user.providerData.map((web_fb.UserInfo<dynamic> userInfo) => _mapUserToUserInfo(userInfo)).toList();
    return firebaseUser;
  }

  Future<void> _removeAuthListener(int handle) {
    _authSubscriptions[handle].cancel();
    _authSubscriptions.remove(handle);
    return Future<void>.value();
  }

  Future<Map<dynamic, dynamic>> _signInWithCredential(String appName, String provider, Map<dynamic, dynamic> data) async {
    final web_fb.Auth auth = _getAuthForApp(appName);
    web_fb.AuthCredential credential;
    if (provider == web_fb.EmailAuthProvider.PROVIDER_ID) {
      credential = web_fb.EmailAuthProvider.credential(data['email'], data['password']);
    } else {
      throw "Unsupported authentication credential provider in web implementation of firebase_auth: $provider";
    }
    final web_fb.UserCredential userCredential = await auth.signInAndRetrieveDataWithCredential(credential);
    final Map<dynamic, dynamic> userData = _mapUserToFirebaseUser(userCredential.user);
    return <dynamic, dynamic> {
      "user": userData,
    };
  }

  Future<dynamic> _sendPasswordResetEmail(String appName, String email) {
    final web_fb.Auth auth = _getAuthForApp(appName);
    return auth.sendPasswordResetEmail(email);
  }

  Future<dynamic> _currentUser(String appName) async {
    final web_fb.Auth auth = _getAuthForApp(appName);
    final Completer<dynamic> completer = Completer<dynamic>();
    StreamSubscription<web_fb.User> sub;
    sub = auth.onAuthStateChanged.listen((web_fb.User user) {
      sub.cancel();
      if (user != null) {
        final dynamic result = _mapUserToFirebaseUser(user);
        completer.complete(result);
      } else {
        completer.complete(null);
      }
    });
    return completer.future;
  }

  Future<dynamic> _createUserWithEmailAndPassword(String appName, String email, String password) async {
    final web_fb.Auth auth = _getAuthForApp(appName);
    final web_fb.UserCredential userCredential = await auth.createUserWithEmailAndPassword(email, password);
    if (userCredential != null) {
      final Map<dynamic, dynamic> userData = _mapUserToFirebaseUser(userCredential.user);
      return <dynamic, dynamic> {
        "user": userData,
      };
    } else {
      return null;
    }
  }

  Future<dynamic> _signOut(String appName) {
    final web_fb.Auth auth = _getAuthForApp(appName);
    return auth.signOut();
  }

  Future<Map<dynamic, dynamic>> _getIdToken(String appName, bool refresh) async {
    final web_fb.Auth auth = _getAuthForApp(appName);
    if (auth.currentUser != null) {
      final String token = await auth.currentUser.getIdToken(refresh ?? false);
      return <dynamic, dynamic> {
        "token": token,
      };
    } else {
      return null;
    }
  }
}