import 'dart:io' show File;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:logger/logger.dart';
// Adjust this path to wherever you place the helper in your lib/ tree.
import 'package:almahub/helpers/download_helper.dart';

class PolicyDocumentActions {
  PolicyDocumentActions._();

  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 1,
      errorMethodCount: 4,
      lineLength: 100,
      colors: true,
      printEmojis: true,
    ),
  );

  /// File types a browser / OS can render natively, with no third-party
  /// viewer needed.
  static const Set<String> _directExtensions = {
    'pdf', 'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'txt',
  };

  /// Builds the URL that should be navigated to in order to *view* [url]
  /// (a Firebase Storage download URL) given its [fileType].
  static String buildViewerUrl(String url, String fileType) {
    final type = fileType.toLowerCase();
    if (_directExtensions.contains(type)) {
      return url; // browsers / OS viewers handle these directly
    }
    final encodedUrl = Uri.encodeComponent(url);
    return 'https://view.officeapps.live.com/op/view.aspx?src=$encodedUrl';
  }

  static Future<void> openDocument({
    required BuildContext context,
    required String url,
    required String fileType,
    required String fileName,
  }) async {
    _logger.i('Opening document: $fileName (type: $fileType)');

    _showSnack(context, 'Opening $fileName…', loading: true);

    if (kIsWeb) {
      await _openExternally(context, url, fileType, fileName);
      return;
    }

    // Native: try a local, offline-capable open first (fast, and works
    // without connectivity once cached).
    final opened = await _openNative(url, fileType, fileName);
    if (!context.mounted) return;
    if (!opened) {
      _showSnack(context, 'Opening $fileName in browser viewer…');
      await _openExternally(context, url, fileType, fileName);
    }
  }

  static Future<void> downloadDocument({
    required BuildContext context,
    required String url,
    required String fileName,
  }) async {
    _showSnack(context, 'Downloading $fileName…', loading: true);

    try {
      // Fetch the actual file bytes ourselves rather than handing the raw
      // URL to launchUrl — launchUrl just opens/navigates, it never forces
      // a real "Save As" / download, regardless of the file's content type.
      final response = await Dio().get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = Uint8List.fromList(response.data ?? const []);

      // Platform-specific save: Blob+anchor download on web, app-specific
      // storage write (with permission handling) on mobile/desktop.
      final result = await platformDownloadFile(bytes, fileName);

      if (!context.mounted) return;

      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              kIsWeb
                  ? result // e.g. "Download started. Check your browser downloads."
                  : 'Downloaded successfully!\nLocation: $result',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
            action: !kIsWeb
                ? SnackBarAction(
                    label: 'Open',
                    textColor: Colors.white,
                    onPressed: () => OpenFile.open(result),
                  )
                : null,
          ),
        );
      }
    } catch (e, st) {
      _logger.e('Error downloading document', error: e, stackTrace: st);
      if (!context.mounted) return;

      final isPermissionError = e.toString().contains('permission');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isPermissionError
                ? 'Storage permission denied. Please enable storage access in Settings.'
                : 'Download failed: $e',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
          action: isPermissionError
              ? SnackBarAction(
                  label: 'Settings',
                  textColor: Colors.white,
                  onPressed: () => openAppSettings(),
                )
              : null,
        ),
      );
    }
  }

  // ── Internal helpers ─────────────────────────────────────────────────

  static Future<void> _openExternally(
    BuildContext context,
    String url,
    String fileType,
    String fileName,
  ) async {
    try {
      final viewerUrl = buildViewerUrl(url, fileType);
      final uri = Uri.parse(viewerUrl);
      final launched = await canLaunchUrl(uri) &&
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open viewer for $fileName'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e, st) {
      _logger.e('Error opening external viewer', error: e, stackTrace: st);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening $fileName: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  static Future<bool> _openNative(
    String url,
    String fileType,
    String fileName,
  ) async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final isOnline =
          connectivityResult.any((r) => r != ConnectivityResult.none);

      final cacheManager = DefaultCacheManager();
      FileInfo? cachedFile;

      if (isOnline) {
        cachedFile = await cacheManager.downloadFile(url);
      } else {
        cachedFile = await cacheManager.getFileFromCache(url);
      }

      if (cachedFile == null) {
        _logger.w('No cached file and no connectivity for $fileName');
        return false;
      }

      final correctedFile = await _withCorrectExtension(
        cachedFile.file,
        fileType,
        fileName,
      );

      final result = await OpenFile.open(correctedFile.path);
      if (result.type != ResultType.done) {
        _logger.w('OpenFile could not open $fileName: ${result.message}');
        return false;
      }
      return true;
    } catch (e, st) {
      _logger.e('Native open failed for $fileName', error: e, stackTrace: st);
      return false;
    }
  }

  static Future<File> _withCorrectExtension(
    File cachedFile,
    String fileType,
    String fileName,
  ) async {
    final ext = fileType.toLowerCase();
    if (ext.isEmpty || cachedFile.path.toLowerCase().endsWith('.$ext')) {
      return cachedFile;
    }

    final dir = cachedFile.parent.path;
    final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final targetName =
        safeName.toLowerCase().endsWith('.$ext') ? safeName : '$safeName.$ext';
    final targetFile = File('$dir/$targetName');

    // Avoid a redundant copy if a correctly-named version is already
    // there and up to date (cheap re-open of a previously opened file).
    final needsCopy = !await targetFile.exists() ||
        await targetFile.length() != await cachedFile.length();
    if (needsCopy) {
      await cachedFile.copy(targetFile.path);
    }
    return targetFile;
  }

  static void _showSnack(
    BuildContext context,
    String message, {
    bool loading = false,
  }) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (loading) ...[
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(child: Text(message)),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}