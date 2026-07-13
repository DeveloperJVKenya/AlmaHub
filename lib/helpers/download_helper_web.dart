import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

/// Web-specific implementation for file downloads
/// This uses the browser's Blob API to trigger downloads
Future<String?> downloadFile(Uint8List bytes, String fileName) async {
  try {
    // Convert Uint8List to JSUint8Array and wrap in JSArray
    final jsUint8Array = bytes.toJS;
    final jsArray = [jsUint8Array].toJS;
    
    // Create a Blob from the bytes
    final blob = web.Blob(jsArray);
    final objectUrl = web.URL.createObjectURL(blob);
    
    // Create a temporary anchor element to trigger download
    // ignore: unused_local_variable
    final anchor = web.HTMLAnchorElement()
      ..href = objectUrl
      ..download = fileName
      ..click();
    
    // Clean up the object URL to free memory
    web.URL.revokeObjectURL(objectUrl);
    
    // Return success message for web
    return 'Download started. Check your browser downloads.';
  } catch (e) {
    throw Exception('Web download failed: $e');
  }
}