import 'dart:async';

import 'package:firebase/firebase.dart' as web_fb;
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

class FirebaseCorePlugin {
  static void registerWith(Registrar registrar) {
    final MethodChannel channel = MethodChannel(
      'plugins.flutter.io/firebase_core',
      const StandardMethodCodec(),
      registrar.messenger,
    );
    final FirebaseCorePlugin instance = FirebaseCorePlugin();
    channel.setMethodCallHandler(instance.onMethodCall);
  }

  Future<dynamic> onMethodCall(MethodCall call) {
    try {
      switch (call.method) {
        case "FirebaseApp#configure":
          return _configureApp(call.arguments['name'], call.arguments['options']);
        case "FirebaseApp#appNamed":
          return Future<dynamic>.value(_getAppNamed(call.arguments));
        case "FirebaseApp#allApps":
          return Future<dynamic>.value(_allApps());
        default:
          throw PlatformException(
              code: 'Unimplemented',
              details:
                  "The firebase_core plugin for web doesn't implement "
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

  Future<void> _configureApp(String name, Map<dynamic, dynamic> options) {

    web_fb.initializeApp(
      name: name,
      apiKey: options['apiKey'],
      authDomain: options['projectID'] + ".firebaseapp.com",
      databaseURL: options['databaseURL'],
      projectId: options['projectID'],
      storageBucket: options['storageBucket'],
      messagingSenderId: options['gcmSenderID'],
    );

    return Future<void>.value();
  }

  Map<dynamic, dynamic> _getAppNamed(String name) {
    try {
      final web_fb.App app = web_fb.app(name);
      return <dynamic, dynamic> {
        'name': app.name,
        'options': <dynamic, dynamic> {
          'apiKey': app.options.apiKey,
          'databaseURL': app.options.databaseURL,
          'projectID': app.options.projectId,
          'storageBucket': app.options.storageBucket,
          'gcmSenderID': app.options.messagingSenderId,
        }
      };
    } catch (e) {
      return null;
    }   
  }

  List<Map<dynamic, dynamic>> _allApps() {
    return web_fb.apps.map((web_fb.App app) => _getAppNamed(app.name)).toList();
  }
}