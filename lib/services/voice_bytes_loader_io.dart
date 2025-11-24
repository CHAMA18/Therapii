import 'dart:io';
import 'dart:typed_data';

Future<Uint8List> loadRecordedFileBytes(String path) async {
  final file = File(path);
  return file.readAsBytes();
}
