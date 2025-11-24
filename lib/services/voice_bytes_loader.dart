import 'dart:typed_data';

// Conditional import: IO for mobile/desktop, web stub for web
import 'package:therapii/services/voice_bytes_loader_io.dart'
    if (dart.library.html) 'package:therapii/services/voice_bytes_loader_web.dart' as loader;

Future<Uint8List> loadRecordedFileBytes(String path) => loader.loadRecordedFileBytes(path);
