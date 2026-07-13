import 'dart:typed_data';

// Conditional imports based on platform
// When compiling for web (dart.library.html exists), use web implementation
// Otherwise, use mobile/desktop implementation
import 'download_helper_mobile.dart'
    if (dart.library.html) 'download_helper_web.dart';

/// Platform-agnostic download function that automatically uses the correct implementation
/// 
/// Returns:
/// - For Web: A success message string
/// - For Mobile/Desktop: The full path where the file was saved, or null if cancelled
/// 
/// Throws:
/// - Exception if download fails on either platform
Future<String?> platformDownloadFile(Uint8List bytes, String fileName) async {
  return await downloadFile(bytes, fileName);
}