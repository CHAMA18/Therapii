import 'dart:typed_data';

Future<Uint8List> loadRecordedFileBytes(String path) async {
  // Recording upload from in-app recorder is not supported on web yet.
  throw UnsupportedError('Recording upload is not supported on web.');
}
