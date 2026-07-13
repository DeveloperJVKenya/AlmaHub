import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// Mobile/Desktop implementation for file downloads
/// Uses app-specific storage with permission handling for Android
Future<String?> downloadFile(Uint8List bytes, String fileName) async {
  try {
    // Request storage permissions
    final hasPermission = await _requestStoragePermission();
    
    if (!hasPermission) {
      throw Exception('Storage permission denied. Please enable storage access in Settings.');
    }

    // Get the appropriate download directory
    final downloadDir = await _getDownloadDirectory();
    
    // Create full file path
    final savePath = '${downloadDir.path}/$fileName';
    
    // Write bytes to file
    final file = File(savePath);
    await file.writeAsBytes(bytes);
    
    // Return the full path where file was saved
    return savePath;
  } catch (e) {
    throw Exception('Mobile download failed: $e');
  }
}

/// Request storage permissions based on Android version
Future<bool> _requestStoragePermission() async {
  if (Platform.isAndroid) {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    final sdkInt = androidInfo.version.sdkInt;
    
    if (sdkInt >= 33) {
      // Android 13+: Photos/Media permission (but we'll use app-specific storage)
      // No permission needed for app-specific directories
      return true;
    } else if (sdkInt >= 30) {
      // Android 11-12: Check for storage permission
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
      }
      return status.isGranted;
    } else {
      // Android 10 and below
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
      }
      return status.isGranted;
    }
  }
  // iOS doesn't need permission for app documents
  return true;
}

/// Get the correct download directory based on platform
Future<Directory> _getDownloadDirectory() async {
  if (Platform.isAndroid) {
    // Use app-specific external storage (doesn't require special permissions)
    final directory = await getExternalStorageDirectory();
    
    if (directory != null) {
      // Create AlmaWorks/Downloads folder in app-specific directory
      final almaWorksDir = Directory('${directory.path}/AlmaWorks/Downloads');
      if (!await almaWorksDir.exists()) {
        await almaWorksDir.create(recursive: true);
      }
      return almaWorksDir;
    }
    
    // Fallback to internal storage
    final appDir = await getApplicationDocumentsDirectory();
    final almaWorksDir = Directory('${appDir.path}/AlmaWorks/Downloads');
    if (!await almaWorksDir.exists()) {
      await almaWorksDir.create(recursive: true);
    }
    return almaWorksDir;
  } else {
    // iOS
    final directory = await getApplicationDocumentsDirectory();
    final almaWorksDir = Directory('${directory.path}/AlmaWorks/Downloads');
    if (!await almaWorksDir.exists()) {
      await almaWorksDir.create(recursive: true);
    }
    return almaWorksDir;
  }
}