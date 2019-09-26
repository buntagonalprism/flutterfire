@JS('firebase')
library storage;

import 'dart:html' as html;
import 'dart:typed_data';

import "package:js/js.dart";

import 'firebase_app_js_interop.dart';
import 'promise_js_interop.dart';

external Storage storage(App app);

@JS()
@anonymous 
abstract class Storage {
  external RootStorageBucketRef ref();
}

@JS()
@anonymous 
abstract class RootStorageBucketRef {
  external Reference child(String path);
}

abstract class FileOrBlob implements html.File, Uint8List {

}

@JS() 
@anonymous 
abstract class Reference {
  external String get name;
  external String get fullPath;
  external UploadTask put(FileOrBlob file);
  external Promise getDownloadURL();
}

@JS() 
@anonymous 
abstract class UploadTask {
  external void on(String key, Function(UploadSnapshot snapshot) onProgress, Function(dynamic error) onError, Function() onComplete);
  external UploadSnapshot get snapshot;
}

@JS() 
@anonymous 
abstract class UploadSnapshot {
  external int get bytesTransferred;
  external int get totalBytes;
  external String get state;
  external Reference get ref;
  external StorageMetadata get metadata;
}


@JS() 
@anonymous 
abstract class StorageMetadata {
  external String get bucket;

  /// A version String indicating what version of the [StorageReference].
  external String get generation;

  /// A version String indicating the version of this [StorageMetadata].
  external String get metageneration;

  /// The path of the [StorageReference] object.
  external String get fullPath;

  /// A simple name of the [StorageReference] object.
  external String get name;

  /// The stored Size in bytes of the [StorageReference] object.
  external int get size;

  /// The time the [StorageReference] was created as a date string
  external String get timeCreated;

  /// The time the [StorageReference] was last updated as a date string
  external String get updated;

  /// The MD5Hash of the [StorageReference] object.
  external String get md5Hash;

  /// The Cache Control setting of the [StorageReference].
  external String get cacheControl;

  /// The content disposition of the [StorageReference].
  external String get contentDisposition;

  /// The content encoding for the [StorageReference].
  external String get contentEncoding;

  /// The content language for the StorageReference, specified as a 2-letter
  /// lowercase language code defined by ISO 639-1.
  external String get contentLanguage;

  /// The content type (MIME type) of the [StorageReference].
  external String get contentType;

  external Map<dynamic, dynamic> get customMetadata;
}