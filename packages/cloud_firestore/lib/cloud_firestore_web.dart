import 'dart:async';

import 'package:firebase/firebase.dart' as web_fb;
import 'package:firebase/firestore.dart' as web_fs;
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

class CloudFirestorePlugin {

  static int _handleCounter = 0;
  static final Map<int, StreamSubscription<dynamic>> _subscriptions = {};

  static web_fs.Firestore _getFirestoreForApp(String appName) => web_fb.firestore(web_fb.app(appName));

  static MethodChannel _channel;

  static void registerWith(Registrar registrar) {
    _channel = MethodChannel(
      'plugins.flutter.io/cloud_firestore',
      const StandardMethodCodec(),
      registrar.messenger,
    );
    final CloudFirestorePlugin instance = CloudFirestorePlugin();
    _channel.setMethodCallHandler(instance.onMethodCall);
  }

  // Only implemented read methods for now, no update methods. 
  Future<dynamic> onMethodCall(MethodCall call) {
    try {
      switch (call.method) {
        case 'DocumentReference#get':
          return _getDocument(call);
        case 'DocumentReference#addSnapshotListener':
          return _addDocumentListener(call);
        case 'removeListener':
          return _removeListener(call);
        case 'Query#addSnapshotListener':
          return _addQueryListener(call);
        case 'Query#getDocuments':
          return _getQueryDocuments(call);
        default:
          throw PlatformException(
              code: 'Unimplemented',
              details:
                  "The cloud_firestore plugin for web doesn't implement "
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

  Future<Map<dynamic, dynamic>> _getDocument(MethodCall call) async {
    final String appName = call.arguments['app'];
    final web_fs.Firestore fs = _getFirestoreForApp(appName);
    final String path = call.arguments['path'];
    final web_fs.DocumentSnapshot snapshot = await fs.doc(path).get();
    if (snapshot != null) {
      return _mapDocumentSnapshot(snapshot);
    } else {
      return null;
    }
  }

  Map<dynamic, dynamic> _mapDocumentSnapshot(web_fs.DocumentSnapshot snapshot) {
    return <dynamic, dynamic> {
      'path': snapshot.ref.path,
      'data': snapshot.data(),
      'metadata': _mapMetadata(snapshot.metadata),
    };
  }

  Future<int> _addDocumentListener(MethodCall call) {
    final String appName = call.arguments['app'];
    final web_fs.Firestore fs = _getFirestoreForApp(appName);
    final int thisHandle = _handleCounter++;
    final String path = call.arguments['path'];

    _subscriptions[thisHandle] = fs.doc(path).onSnapshot.listen((web_fs.DocumentSnapshot snapshot) {
      final Map<dynamic, dynamic> result = _mapDocumentSnapshot(snapshot);
      result['handle'] = thisHandle;
      _channel.invokeMethod<dynamic>("DocumentSnapshot", result);
    });

    return Future<int>.value(thisHandle);
  }

  Future<void> _removeListener(MethodCall call) {
    final int handle = call.arguments['handle'];
    _subscriptions[handle].cancel();
    _subscriptions.remove(handle);
    return Future<void>.value();
  }

  Future<int> _addQueryListener(MethodCall call) {
    final web_fs.Query<dynamic> query = _getQuery(call);
    final int thisHandle = _handleCounter++;
    _subscriptions[thisHandle] = query.onSnapshot.listen((web_fs.QuerySnapshot snapshot) {
      final Map<dynamic, dynamic> result = _mapQuerySnapshot(snapshot);
      result['handle'] = thisHandle;
      _channel.invokeMethod<dynamic>("QuerySnapshot", result);
    });

    return Future<int>.value(thisHandle);
  }

  web_fs.Query<dynamic> _getQuery(MethodCall call) {
    final String appName = call.arguments['app'];
    final web_fs.Firestore fs = _getFirestoreForApp(appName);
    final String path = call.arguments['path'];
    final Map<dynamic, dynamic> parameters = call.arguments['parameters'];
    final List<dynamic> conditions = parameters['where'];
    web_fs.Query<dynamic> query = fs.collection(path);
    for (List<dynamic> condition in conditions) {
      query = query.where(condition[0], condition[1], condition[2]);
    }
    final List<dynamic> orderBy = parameters['orderBy'];
    for (List<dynamic> orderField in orderBy) {
      final bool isDescending = orderField[1];
      query = query.orderBy(orderField[0], isDescending ? 'desc' : 'asc');
    }

    // TODO: support start/end conditions using document snapshots
    if (parameters['startAfter'] != null) {
      query = query.startAfter(fieldValues: parameters['startAfter']);
    } else if (parameters['startAt'] != null) {
      query = query.startAt(fieldValues: parameters['startAt']);
    }

    if (parameters['endBefore'] != null) {
      query = query.endBefore(fieldValues: parameters['endAt']);
    } else if (parameters['endAt'] != null) {
      query = query.endAt(fieldValues: parameters['endAt']);
    }
    return query;
  }

  Map<dynamic, dynamic> _mapQuerySnapshot(web_fs.QuerySnapshot snapshot) {
    final List<Map<dynamic, dynamic>> docs = snapshot.docs.map((web_fs.DocumentSnapshot doc) => doc.data()).toList();
    final List<String> paths = snapshot.docs.map((web_fs.DocumentSnapshot doc) => doc.ref.path).toList();
    final List<Map<dynamic, dynamic>> metadatas = snapshot.docs.map((web_fs.DocumentSnapshot doc) => _mapMetadata(doc.metadata)).toList();
    final List<Map<dynamic, dynamic>> changes = snapshot.docChanges().map((web_fs.DocumentChange change) => _mapDocumentChange(change)).toList();
    return <dynamic, dynamic> {
      'documents': docs,
      'paths': paths,
      'metadatas': metadatas,
      'documentChanges': changes,
      'metadata': _mapMetadata(snapshot.metadata),
    };
  }

  Map<dynamic, dynamic> _mapMetadata(web_fs.SnapshotMetadata metadata) {
    return <dynamic, dynamic> {
      'hasPendingWrites': metadata.hasPendingWrites,
      'isFromCache': metadata.fromCache,
    };
  }

  Map<dynamic, dynamic> _mapDocumentChange(web_fs.DocumentChange change) {
    return <dynamic, dynamic>{
      'oldIndex': change.oldIndex,
      'newIndex': change.newIndex,
      'type': 'DocumentChangeType.${change.type}',
      'path': change.doc.ref.path,
      'document': change.doc.data(),
      'metadata': _mapMetadata(change.doc.metadata),
    };
  }

  Future<Map<dynamic, dynamic>> _getQueryDocuments(MethodCall call) async {
    final web_fs.Query<dynamic> query = _getQuery(call);
    return _mapQuerySnapshot(await query.get());
  }
}