import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

import 'firebase_app_js_interop.dart' as fa;
import 'firebase_storage_js_interop.dart' as fs;

class FirebaseStoragePlugin {

  static int _handleCounter = 0;
  static final Map<int, StreamSubscription<dynamic>> _subscriptions = {};

  static fs.Storage _getStorageForApp(String appName) => fs.storage(fa.app(appName));

  static MethodChannel _channel;

  static const List<String> _storageEventTypeNames = <String>[
    'resume',
    'running',
    'pause',
    'success',
    'failure',
  ];

  static const Map<String, int> _storageErrors = <String, int>{
    'storage/unknown': -13000,
    'storage/object-not-found': -13010,
    'storage/bucket-not-found': -13011,
    'storage/project-not-found': -13012,
    'storage/quota-exceeded': -13013,
    'storage/unauthenticated': -13020,
    'storage/unauthorized': -13021,
    'storage/retry-limit-exceeded': -13030,
    'storage/invalid-checksum': -13031,
    'storage/canceled': -13040,
  };

  static void registerWith(Registrar registrar) {
    _channel = MethodChannel(
      'plugins.flutter.io/firebase_storage',
      const StandardMethodCodec(),
      registrar.messenger,
    );
    final FirebaseStoragePlugin instance = FirebaseStoragePlugin();
    _channel.setMethodCallHandler(instance.onMethodCall);
  }

  // Only implemented read methods for now, no update methods. 
  Future<dynamic> onMethodCall(MethodCall call) {
    try {
      switch (call.method) {
        case "StorageReference#putFile":
          return _uploadFile(call);
        case "StorageReference#putData":
          return _uploadData(call);
        case "StorageReference#getDownloadUrl":
          return _getDownloadUrl(call);
        default:
          throw PlatformException(
              code: 'Unimplemented',
              details:
                  "The firebase_storage plugin for web doesn't implement "
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

  Future<int> _uploadFile(MethodCall call) async {
    final String appName = call.arguments['app'];
    final String sourcePath = call.arguments['filename'];
    final String targetPath = call.arguments['path'];

    final fs.Storage storage = _getStorageForApp(appName);

    final int uploadHandle = _handleCounter++;
    final fs.Reference ref = storage.ref().child(targetPath);
    fs.UploadTask uploadTask;
    // Assume path is object URL  
    final Uint8List sourceData = await http.readBytes(sourcePath);
    uploadTask = ref.put(sourceData);
    _runUploadTask(uploadTask, uploadHandle);
    return Future<int>.value(uploadHandle);
  }

  Future<int> _uploadData(MethodCall call) {
    final String appName = call.arguments['app'];
    final String targetPath = call.arguments['path'];
    final Uint8List bytes = call.arguments['data'];

    final fs.Storage storage = _getStorageForApp(appName);

    final int uploadHandle = _handleCounter++;
    final fs.Reference ref = storage.ref().child(targetPath);
    final fs.UploadTask uploadTask = ref.put(bytes);
    _runUploadTask(uploadTask, uploadHandle);
    return Future<int>.value(uploadHandle);
  }

  void _runUploadTask(fs.UploadTask uploadTask, int uploadHandle) {
    uploadTask.on('state_changed', js.allowInterop((fs.UploadSnapshot snapshot) {
      _emitUploadEvent(uploadHandle, snapshot);
    }), js.allowInterop((dynamic error) {
      final String errorMessage = error;
      final int errorCode = _storageErrors[errorMessage];
      _emitUploadEvent(uploadHandle, uploadTask.snapshot, errorCode);
    }), js.allowInterop(() {
      _emitUploadEvent(uploadHandle, uploadTask.snapshot);
    }));
  }

  void _emitUploadEvent(int handle, fs.UploadSnapshot snapshot, [int errorCode]){
    final Map<dynamic, dynamic> output = <dynamic, dynamic>{};
    output['handle'] = handle;
    output['type'] = _storageEventTypeNames.indexOf(snapshot.state);
    output['snapshot'] = _mapSnapshot(snapshot);
    _channel.invokeMethod<dynamic>('StorageTaskEvent', output);
  }

  Map<dynamic, dynamic> _mapSnapshot(fs.UploadSnapshot snapshot, [int errorCode]) {
    return <dynamic, dynamic> {
      'error': errorCode,
      'bytesTransferred': snapshot.bytesTransferred,
      'totalByteCount': snapshot.totalBytes,
      'storageMetadata': snapshot.metadata != null ? _mapMetadata(snapshot.metadata) : null,
    };
  }

  Map<dynamic, dynamic> _mapMetadata(fs.StorageMetadata metadata) {
    return <dynamic, dynamic> {
      'bucket': metadata.bucket,
      'generation': metadata.generation,
      'metadataGeneration': metadata.metageneration,
      'path': metadata.fullPath,
      'name': metadata.name,
      'sizeBytes': metadata.size,
      'creationTimeMillis': DateTime.parse(metadata.timeCreated).millisecondsSinceEpoch,
      'updatedTimeMillis': DateTime.parse(metadata.updated).millisecondsSinceEpoch,
      'md5Hash': metadata.md5Hash,
      'cacheControl': metadata.cacheControl,
      'contentDisposition': metadata.contentDisposition,
      'contentLanguage': metadata.contentLanguage,
      'contentType': metadata.contentType,
      'contentEncoding': metadata.contentEncoding,
      'customMetadata': metadata.customMetadata,
    };
  }

  Future<String> _getDownloadUrl(MethodCall call) {
    final Completer<String> completer = Completer<String>();
    final String appName = call.arguments['app'];
    final String targetPath = call.arguments['path'];
    final fs.Storage storage = _getStorageForApp(appName);
    final fs.Reference ref = storage.ref().child(targetPath);
    ref.getDownloadURL().then(js.allowInterop((String downloadUrl) {
      completer.complete(downloadUrl);
    }), js.allowInterop((dynamic error) {
      completer.completeError(error.toString());
    }));
    return completer.future;
  }
}