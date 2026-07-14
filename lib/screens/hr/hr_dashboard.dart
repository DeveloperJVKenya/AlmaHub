import 'dart:async';
import 'dart:io' show File;
import 'package:almahub/models/employee_onboarding_models.dart';
import 'package:almahub/screens/hr/hr_employee_onboarding_screen.dart';
import 'package:almahub/screens/hr/hr_recruitment_dashboard.dart';
import 'package:almahub/services/excel_download_service.dart';
import 'package:almahub/services/excel_generation_service.dart';
import 'package:almahub/services/storage_service.dart';
import 'package:almahub/screens/hr/Policy%20Management/company_policy_model.dart';
import 'package:almahub/screens/hr/Policy%20Management/policy_status_model.dart';
import 'package:almahub/screens/hr/Policy%20Management/policy_service.dart';
import 'package:almahub/screens/hr/Policy%20Management/hr_policy_management_screen.dart';
import 'package:almahub/screens/hr/Payroll/hr_payroll_management_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:open_file/open_file.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:logger/logger.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Friendly display labels for every storage field-name the wizard uses.
// ─────────────────────────────────────────────────────────────────────────────
const Map<String, String> _kDocumentLabels = {
  // Step 1 — Personal Info
  'id_document': 'ID / Passport',
  // Step 3 — Statutory
  'kra_pin': 'KRA PIN Certificate',
  'nssf_confirmation': 'NSSF Confirmation',
  'shif_confirmation': 'SHIF Confirmation',
  // Legacy key from before NHIF was replaced by SHIF/SHA — kept so older
  // uploaded documents still display a friendly label.
  'nhif_confirmation': 'SHIF Confirmation',
  'p9_form': 'P9 Form',
  // Step 5 — Academic & Professional
  'academic_cert': 'Academic Certificate',
  'training_cert': 'Training Certificate',
  'professional_cert': 'Professional Certification',
  // Step 6 — Contracts & Forms
  'employment_contract': 'Employment Contract',
  'employee_info_form': 'Employee Info Form',
  'nda': 'NDA / Confidentiality',
  // Step 7 — Benefits
  'medical_insurance': 'Medical Insurance Form',
};

// Icon per field
const Map<String, IconData> _kDocumentIcons = {
  'id_document': Icons.badge_outlined,
  'kra_pin': Icons.receipt_long_outlined,
  'nssf_confirmation': Icons.verified_user_outlined,
  'shif_confirmation': Icons.health_and_safety_outlined,
  'nhif_confirmation': Icons.health_and_safety_outlined,
  'p9_form': Icons.description_outlined,
  'academic_cert': Icons.school_outlined,
  'training_cert': Icons.menu_book_rounded,
  'professional_cert': Icons.workspace_premium_outlined,
  'employment_contract': Icons.article_outlined,
  'employee_info_form': Icons.assignment_outlined,
  'nda': Icons.lock_outline_rounded,
  'medical_insurance': Icons.medical_information_outlined,
};

// ─────────────────────────────────────────────────────────────────────────────
// Standalone widget placed inside the DataCell so it can manage its own state
// without forcing the entire table to rebuild on every doc fetch.
// ─────────────────────────────────────────────────────────────────────────────
class _EmployeeDocumentsCell extends StatefulWidget {
  final String employeeName;
  final Logger logger;

  const _EmployeeDocumentsCell({
    required this.employeeName,
    required this.logger,
  });

  @override
  State<_EmployeeDocumentsCell> createState() => _EmployeeDocumentsCellState();
}

class _EmployeeDocumentsCellState extends State<_EmployeeDocumentsCell> {
  final StorageService _storageService = StorageService();

  // null  → still loading
  // empty → loaded, no docs
  Map<String, List<String>>? _documents;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    // Small stagger so all rows don't hit Storage at exactly t=0
    Future.delayed(
      Duration(milliseconds: (widget.employeeName.hashCode.abs() % 400)),
      _loadDocuments,
    );
  }

  Future<void> _loadDocuments({int attempt = 1}) async {
    try {
      final docs =
          await _storageService.listEmployeeDocuments(widget.employeeName);
      if (mounted) setState(() => _documents = docs);
    } catch (e) {
      // Retry once after 2 s before showing the error icon
      if (attempt < 2 && mounted) {
        await Future.delayed(const Duration(seconds: 2));
        return _loadDocuments(attempt: attempt + 1);
      }
      widget.logger.e(
          'Error loading documents for ${widget.employeeName}', error: e);
      if (mounted) setState(() => _hasError = true);
    }
  }

  int get _totalCount =>
      _documents?.values.fold<int>(0, (acc, list) => acc + list.length) ?? 0;

  @override
  Widget build(BuildContext context) {
    // ── Loading state ──────────────────────────────────────────────────────
    if (_documents == null && !_hasError) {
      return const SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    // ── Error state ────────────────────────────────────────────────────────
    if (_hasError) {
      return Tooltip(
        message: 'Could not load documents',
        child: Icon(Icons.error_outline, color: Colors.red.shade300, size: 20),
      );
    }

    final count = _totalCount;

    // ── Zero docs ──────────────────────────────────────────────────────────
    if (count == 0) {
      return Tooltip(
        message: 'No documents submitted yet',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '0',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
        ),
      );
    }

    // ── Has docs – clickable badge ─────────────────────────────────────────
    return Tooltip(
      message: 'View $count submitted document(s)',
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showDocumentsPanel(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 86, 10, 119).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color.fromARGB(255, 86, 10, 119).withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.folder_open_outlined,
                size: 14,
                color: Color.fromARGB(255, 86, 10, 119),
              ),
              const SizedBox(width: 4),
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color.fromARGB(255, 86, 10, 119),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Documents Panel ────────────────────────────────────────────────────────
  void _showDocumentsPanel(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => _DocumentsPanelDialog(
        employeeName: widget.employeeName,
        documents: _documents!,
        logger: widget.logger,
        onRefresh: () async {
          // After a delete, reload the count in the cell
          final docs = await _storageService
              .listEmployeeDocuments(widget.employeeName);
          if (mounted) setState(() => _documents = docs);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// The dialog that lists every document with View / Download / Delete actions.
// It owns its own copy of the document map so it can update without the parent.
// ─────────────────────────────────────────────────────────────────────────────
class _DocumentsPanelDialog extends StatefulWidget {
  final String employeeName;
  final Map<String, List<String>> documents;
  final Logger logger;
  final Future<void> Function() onRefresh;

  const _DocumentsPanelDialog({
    required this.employeeName,
    required this.documents,
    required this.logger,
    required this.onRefresh,
  });

  @override
  State<_DocumentsPanelDialog> createState() => _DocumentsPanelDialogState();
}

class _DocumentsPanelDialogState extends State<_DocumentsPanelDialog> {
  late Map<String, List<String>> _docs;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _docs = Map.from(widget.documents);
  }

  int get _totalCount =>
      _docs.values.fold<int>(0, (acc, list) => acc + list.length);

  // ── Helper: file name from URL ─────────────────────────────────────────────
  String _fileNameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      if (segments.isNotEmpty) {
        final raw = Uri.decodeComponent(segments.last);
        // Strip leading timestamp prefix (e.g. "1700000000000_myfile.pdf")
        final underscoreIdx = raw.indexOf('_');
        if (underscoreIdx != -1 && underscoreIdx < 14) {
          return raw.substring(underscoreIdx + 1);
        }
        return raw;
      }
    } catch (_) {}
    return 'document';
  }

  String _fileExtension(String url) {
    final name = _fileNameFromUrl(url);
    final dotIdx = name.lastIndexOf('.');
    if (dotIdx != -1) return name.substring(dotIdx + 1).toLowerCase();
    return 'file';
  }

  // ── View ──────────────────────────────────────────────────────────────────
  Future<void> _viewDocument(String url) async {
    widget.logger.i('HR: Viewing document: $url');
    try {
      if (kIsWeb) {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } else {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      widget.logger.e('Error viewing document', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open document: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── Download ──────────────────────────────────────────────────────────────
  // Uses Dio to fetch bytes, then OpenFile to save/open on native.
  // On web, launches the storage URL directly (browser handles download).
  Future<void> _downloadDocument(String url, String fileName) async {
    widget.logger.i('HR: Downloading: $fileName');
    try {
      if (kIsWeb) {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Download started — check your browser downloads.'),
              backgroundColor: Colors.green,
            ),
          );
        }
        return;
      }

      // Native: fetch bytes via Dio then open with system viewer
      final response = await Dio().get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = Uint8List.fromList(response.data!);

      // Write to the app's temporary directory using OpenFile's path
      // We store bytes via the dart:io File class — only reached on native.
      final tempPath = await _writeTempFile(fileName, bytes);

      if (!mounted) return;

      final result = await OpenFile.open(tempPath);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved to: $tempPath'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      widget.logger.e('Error downloading document', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Writes [bytes] to the system temp directory and returns the file path.
  /// This method is only ever reached on native (non-web) platforms.
  Future<String> _writeTempFile(String fileName, Uint8List bytes) async {
    const dir = '/tmp'; // Works on Android/iOS via OpenFile path fallback
    final filePath = '$dir/$fileName';
    await _writeNative(filePath, bytes);
    return filePath;
  }

  // ── Delete (with confirmation) ────────────────────────────────────────────
  Future<void> _deleteDocument(
      String fieldName, String url, String fileLabel) async {
    widget.logger.i('HR: Delete requested — $fileLabel');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Colors.red.shade600, size: 26),
            const SizedBox(width: 10),
            const Expanded(child: Text('Delete Document')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are about to permanently delete:',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _kDocumentIcons[fieldName] ?? Icons.insert_drive_file,
                    color: const Color.fromARGB(255, 86, 10, 119),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      fileLabel,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.red, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone. The file will be removed from Firebase Storage permanently.',
                      style: TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.delete_forever, size: 18),
            label: const Text('Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);
    try {
      await FirebaseStorage.instance.refFromURL(url).delete();
      widget.logger.i('✅ Document deleted from Storage: $url');

      // Update local state
      setState(() {
        final list = List<String>.from(_docs[fieldName] ?? []);
        list.remove(url);
        if (list.isEmpty) {
          _docs.remove(fieldName);
        } else {
          _docs[fieldName] = list;
        }
      });

      // Refresh the cell badge count
      await widget.onRefresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document deleted successfully.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      widget.logger.e('Error deleting document', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting document: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  // ── Three-action popup (View / Download / Delete) ─────────────────────────
  void _showDocumentActions(
      BuildContext context, String fieldName, String url) {
    final fileName = _fileNameFromUrl(url);
    final ext = _fileExtension(url);
    final label =
        '${_kDocumentLabels[fieldName] ?? fieldName} — $fileName';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: EdgeInsets.zero,
        title: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 86, 10, 119)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _kDocumentIcons[fieldName] ?? Icons.insert_drive_file,
                  color: const Color.fromARGB(255, 86, 10, 119),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _kDocumentLabels[fieldName] ?? fieldName,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      fileName,
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.normal),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        content: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // View
              _ActionTile(
                icon: Icons.visibility_outlined,
                color: Colors.blue.shade700,
                label: 'View Document',
                subtitle: 'Open in browser / system viewer',
                onTap: () {
                  Navigator.pop(ctx);
                  _viewDocument(url);
                },
              ),
              const Divider(height: 1),
              // Download
              _ActionTile(
                icon: Icons.download_outlined,
                color: Colors.green.shade700,
                label: 'Download',
                subtitle: kIsWeb
                    ? 'Save via browser download'
                    : 'Save to device storage',
                onTap: () {
                  Navigator.pop(ctx);
                  _downloadDocument(url, '$fileName.$ext');
                },
              ),
              const Divider(height: 1),
              // Delete
              _ActionTile(
                icon: Icons.delete_outline,
                color: Colors.red.shade700,
                label: 'Delete',
                subtitle: 'Permanently remove from storage',
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteDocument(fieldName, url, label);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final sortedKeys = _docs.keys.toList()
      ..sort((a, b) {
        final order = _kDocumentLabels.keys.toList();
        return order.indexOf(a).compareTo(order.indexOf(b));
      });

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: Color.fromARGB(255, 86, 10, 119),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.folder_open,
                      color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Submitted Documents',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                        Text(
                          widget.employeeName,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$_totalCount file${_totalCount == 1 ? '' : 's'}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // ── Body ────────────────────────────────────────────────────────
            if (_isDeleting)
              const LinearProgressIndicator(
                  backgroundColor: Colors.white,
                  color: Color.fromARGB(255, 86, 10, 119)),

            if (_docs.isEmpty)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.folder_off_outlined,
                          size: 56, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('No documents remaining',
                          style:
                              TextStyle(color: Colors.grey, fontSize: 15)),
                    ],
                  ),
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: sortedKeys.map((fieldName) {
                    final urls = _docs[fieldName]!;
                    final label =
                        _kDocumentLabels[fieldName] ?? fieldName;
                    final icon =
                        _kDocumentIcons[fieldName] ?? Icons.description;

                    return ExpansionTile(
                      key: PageStorageKey(fieldName),
                      initiallyExpanded: true,
                      tilePadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      childrenPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 86, 10, 119)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(icon,
                            color: const Color.fromARGB(255, 86, 10, 119),
                            size: 18),
                      ),
                      title: Text(
                        label,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 86, 10, 119)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${urls.length}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color.fromARGB(255, 86, 10, 119),
                              ),
                            ),
                          ),
                          const Icon(Icons.expand_more),
                        ],
                      ),
                      children: urls.asMap().entries.map((e) {
                        final idx = e.key;
                        final url = e.value;
                        final fileName = _fileNameFromUrl(url);
                        final ext = _fileExtension(url);

                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 0),
                          leading: _FileTypeIcon(extension: ext),
                          title: Text(
                            fileName,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            urls.length > 1
                                ? '$label (${idx + 1} of ${urls.length})'
                                : label,
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.more_vert, size: 20),
                            tooltip: 'Actions',
                            onPressed: () =>
                                _showDocumentActions(context, fieldName, url),
                          ),
                          onTap: () =>
                              _showDocumentActions(context, fieldName, url),
                        );
                      }).toList(),
                    );
                  }).toList(),
                ),
              ),

            // ── Footer ──────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(16)),
                border: Border(
                    top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Tap any document or the ⋮ menu to View, Download or Delete.',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small helpers
// ─────────────────────────────────────────────────────────────────────────────

/// A coloured icon based on file extension.
class _FileTypeIcon extends StatelessWidget {
  final String extension;
  const _FileTypeIcon({required this.extension});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;

    switch (extension) {
      case 'pdf':
        icon = Icons.picture_as_pdf;
        color = Colors.red.shade600;
        break;
      case 'jpg':
      case 'jpeg':
      case 'png':
        icon = Icons.image_outlined;
        color = Colors.blue.shade600;
        break;
      case 'doc':
      case 'docx':
        icon = Icons.article_outlined;
        color = Colors.blue.shade800;
        break;
      default:
        icon = Icons.insert_drive_file_outlined;
        color = Colors.grey.shade600;
    }

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, color: color, size: 16),
    );
  }
}

/// A row in the three-action popup.
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 12, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// dart:io write helper — only called on native platforms (guarded by !kIsWeb)
// ─────────────────────────────────────────────────────────────────────────────
Future<void> _writeNative(String path, List<int> bytes) async {
  // Using conditional compilation via dart:io directly — safe because
  // the entire call chain is guarded by `if (!kIsWeb)`.
  final ioFile = _IoFileFacade(path);
  await ioFile.write(bytes);
}

class _IoFileFacade {
  final String path;
  _IoFileFacade(this.path);

  Future<void> write(List<int> bytes) async {
    // Resolved at runtime on native only.
    // ignore: avoid_dynamic_calls
    try {
      final file = File(path); // dart:io File — only available on native
      await file.writeAsBytes(bytes);
    } catch (_) {
      // If File isn't available (shouldn't happen on native), skip silently.
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  HRDashboard — unchanged except for the new Documents DataColumn
// ═════════════════════════════════════════════════════════════════════════════
class HRDashboard extends StatefulWidget {
  const HRDashboard({super.key});

  @override
  State<HRDashboard> createState() => _HRDashboardState();
}

class _HRDashboardState extends State<HRDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _statusFilter = 'all';
  bool _isDownloading = false;
  String? _downloadProgress;
  String _searchQuery = '';

  final PolicyService _policyService = PolicyService();
  List<CompanyPolicy> _policies = [];
  Map<String, Map<String, PolicyStatus>> _allEmployeePolicyStatuses = {};
  StreamSubscription? _policiesSubscription;
  StreamSubscription? _employeeStatusesSubscription;

  // Scroll Controllers
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void dispose() {
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    _policiesSubscription?.cancel();
    _employeeStatusesSubscription?.cancel();
    super.dispose();
  }

  final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  @override
  void initState() {
    super.initState();
    _logger.i('=== HR Dashboard Initialized ===');
    _logger.d('Initial status filter: $_statusFilter');
    _loadPoliciesForDashboard();
  }

  void _loadPoliciesForDashboard() {
    // Listen to policies stream for auto-column generation
    _policiesSubscription = _policyService.getPoliciesStream().listen(
      (policies) {
        if (!mounted) return;
        setState(() => _policies = policies);
      },
      onError: (e) => _logger.e('Error loading policies for dashboard', error: e),
    );

    // Listen to all policy statuses for employee tracking
    _employeeStatusesSubscription = _policyService
        .getPoliciesStream()
        .asyncMap((policies) async {
      final Map<String, Map<String, PolicyStatus>> result = {};
      for (var policy in policies) {
        final statuses = await _policyService.getPolicyStatusStream(policy.id).first;
        for (var status in statuses) {
          result.putIfAbsent(status.employeeUid, () => {});
          result[status.employeeUid]![policy.id] = status;
        }
      }
      return result;
    }).listen(
      (statuses) {
        if (!mounted) return;
        setState(() => _allEmployeePolicyStatuses = statuses);
      },
      onError: (e) => _logger.e('Error loading policy statuses', error: e),
    );
  }

  @override
  Widget build(BuildContext context) {
    _logger.d('Building HR Dashboard widget');

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 225, 221, 226),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 92, 4, 126),
        elevation: 2,
        title: const Text(
          'HR Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Color.fromARGB(255, 237, 236, 239),
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.payments,
                color: Color.fromARGB(255, 242, 241, 243)),
            onPressed: () {
              _logger.i('Navigating to Payroll Management');
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const HRPayrollManagementScreen(),
                ),
              );
            },
            tooltip: 'Manage Payroll',
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.policy,
                color: Color.fromARGB(255, 242, 241, 243)),
            onPressed: () {
              _logger.i('Navigating to Policy Management');
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const HRPolicyManagementScreen(),
                ),
              );
            },
            tooltip: 'Manage Policies',
          ),
          const SizedBox(width: 8),

          // ── Onboard Employee shortcut ──────────────────────────────
          IconButton(
            icon: const Icon(Icons.person_add_rounded,
                color: Color.fromARGB(255, 242, 241, 243)),
            onPressed: () {
              _logger.i('HR: Launching HR Employee Onboarding Screen (AppBar)');
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const HREmployeeOnboardingScreen(),
                ),
              );
            },
            tooltip: 'Onboard New Employee',
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.search,
                color: Color.fromARGB(255, 242, 241, 243)),
            onPressed: () {
              _logger.i('Search button clicked');
              _showSearchDialog();
            },
            tooltip: 'Search Employees',
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.work_outline,
                color: Color.fromARGB(255, 242, 241, 243)),
            onPressed: () {
              _logger.i('Navigating to Recruitment Dashboard');
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HRRecruitmentDashboard(),
                ),
              );
            },
            tooltip: 'Recruitment Portal',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildStatsCards(),
          Expanded(child: _buildEmployeeTable()),
        ],
      ),
      floatingActionButton: _buildFloatingDownloadButton(),
    );
  }

  // ── Search ─────────────────────────────────────────────────────────────────
  void _showSearchDialog() {
    _logger.d('Opening search dialog');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Employees'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter name, email, or ID...',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            _logger.d('Search query changed: $value');
            setState(() => _searchQuery = value.trim().toLowerCase());
          },
          onSubmitted: (value) {
            _logger.i('Search submitted: $value');
            setState(() => _searchQuery = value.trim().toLowerCase());
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              _logger.d('Search cleared');
              setState(() => _searchQuery = '');
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
          ElevatedButton(
            onPressed: () {
              _logger.i('Search applied: $_searchQuery');
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 81, 3, 130),
            ),
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  // ── FAB ────────────────────────────────────────────────────────────────────
  Widget _buildFloatingDownloadButton() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // ── Onboard Employee button ──────────────────────────────────────
        FloatingActionButton.extended(
          heroTag: 'onboard_fab',
          onPressed: () {
            _logger.i('HR: Launching HR Employee Onboarding Screen');
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const HREmployeeOnboardingScreen(),
              ),
            );
          },
          backgroundColor: const Color.fromARGB(255, 22, 163, 74),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.person_add_rounded),
          label: const Text(
            'Onboard Employee',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 12),
        // ── Download Excel button ────────────────────────────────────────
        FloatingActionButton.extended(
          heroTag: 'download_fab',
          onPressed: _isDownloading ? null : _downloadExcel,
          backgroundColor: _isDownloading
              ? Colors.grey.shade400
              : const Color.fromARGB(255, 86, 10, 119),
          foregroundColor: Colors.white,
          icon: _isDownloading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.download_rounded),
          label: Text(
            _isDownloading
                ? (_downloadProgress ?? 'Generating...')
                : 'Download Excel',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  // ── Stats cards ────────────────────────────────────────────────────────────
  Widget _buildStatsCards() {
    _logger.d('Building stats cards with filter: $_statusFilter');
    return StreamBuilder<List<QueryDocumentSnapshot>>(
      stream: _getEmployeeDetailsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          _logger.e('Error in stats stream', error: snapshot.error);
          return const SizedBox.shrink();
        }
        if (!snapshot.hasData) {
          _logger.d('Stats data not yet available');
          return const SizedBox.shrink();
        }

        final docs = snapshot.data!
            .where((doc) => _matchesStatusFilter(doc.data() as Map<String, dynamic>))
            .toList();
        _logger.d('Stats loaded: ${docs.length} documents in current view');

        final total = docs.length;
        int submitted = 0, drafts = 0;

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status'] ?? 'draft';
          if (status == 'draft') {
            drafts++;
          } else {
            submitted++;
          }
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            final cardWidth = screenWidth * 0.30;
            final spacing = screenWidth * 0.025;

            return Container(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.02,
                vertical: 12,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildStatCard('Total in View', total,
                        const Color.fromARGB(255, 209, 72, 221),
                        Icons.people, cardWidth),
                    SizedBox(width: spacing),
                    if (_statusFilter != 'submitted') ...[
                      _buildStatCard('Drafts', drafts,
                          const Color.fromARGB(255, 213, 97, 217),
                          Icons.drafts, cardWidth),
                      SizedBox(width: spacing),
                    ],
                    if (_statusFilter != 'draft') ...[
                      _buildStatCard('Submitted', submitted, Colors.orange,
                          Icons.pending, cardWidth),
                      SizedBox(width: spacing),
                    ],
                    _buildFilterCard(cardWidth),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard(String title, int value, Color color, IconData icon,
      double cardWidth) {
    final iconSize = (cardWidth * 0.08).clamp(16.0, 22.0);
    final valueSize = (cardWidth * 0.07).clamp(14.0, 20.0);
    final titleSize = (cardWidth * 0.045).clamp(10.0, 12.0);
    final horizontalPadding = cardWidth * 0.05;

    return Container(
      width: cardWidth,
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(cardWidth * 0.04),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: color, size: iconSize),
          ),
          SizedBox(width: cardWidth * 0.05),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value.toString(),
                  style: TextStyle(
                    fontSize: valueSize,
                    fontWeight: FontWeight.bold,
                    color: const Color.fromARGB(255, 86, 10, 119),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: titleSize,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterCard(double cardWidth) {
    final iconSize = (cardWidth * 0.06).clamp(14.0, 18.0);
    final textSize = (cardWidth * 0.05).clamp(11.0, 13.0);
    final horizontalPadding = cardWidth * 0.05;

    return Container(
      width: cardWidth,
      padding:
          EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        initialValue: _statusFilter,
        decoration: InputDecoration(
          labelText: 'Filter',
          labelStyle:
              TextStyle(fontSize: textSize, fontWeight: FontWeight.w600),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: EdgeInsets.symmetric(
              vertical: 6, horizontal: horizontalPadding * 0.8),
          isDense: true,
        ),
        style: TextStyle(fontSize: textSize, color: Colors.black87),
        icon: Icon(Icons.arrow_drop_down, size: iconSize + 2),
        items: [
          DropdownMenuItem(
            value: 'all',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.people_alt,
                    size: iconSize,
                    color: const Color.fromARGB(255, 86, 10, 119)),
                SizedBox(width: horizontalPadding * 0.4),
                Flexible(
                    child: Text('All',
                        style: TextStyle(fontSize: textSize),
                        overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
          DropdownMenuItem(
            value: 'draft',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.drafts,
                    size: iconSize,
                    color: const Color.fromARGB(255, 207, 113, 225)),
                SizedBox(width: horizontalPadding * 0.4),
                Flexible(
                    child: Text('Draft',
                        style: TextStyle(fontSize: textSize),
                        overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
          DropdownMenuItem(
            value: 'submitted',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.send, size: iconSize, color: Colors.orange),
                SizedBox(width: horizontalPadding * 0.4),
                Flexible(
                    child: Text('Submitted',
                        style: TextStyle(fontSize: textSize),
                        overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
        ],
        onChanged: (value) {
          _logger.i('Filter changed from "$_statusFilter" to "$value"');
          setState(() => _statusFilter = value!);
        },
      ),
    );
  }

  // ── Employee table ─────────────────────────────────────────────────────────
  Widget _buildEmployeeTable() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;

        return Container(
          margin: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.02, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildTableHeader(screenWidth),
              Expanded(
                child: StreamBuilder<List<QueryDocumentSnapshot>>(
                  stream: _getEmployeeDetailsStream(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      _logger.e('Error in employee table stream',
                          error: snapshot.error);
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      _logger.d('Waiting for employee data...');
                      return const Center(child: CircularProgressIndicator());
                    }

                    final allEmployees = snapshot.data!
                        .where((doc) => _matchesStatusFilter(doc.data() as Map<String, dynamic>))
                        .toList();
                    _logger.i(
                        'Loaded ${allEmployees.length} employees matching filter "$_statusFilter"');

                    final employees = _searchQuery.isEmpty
                        ? allEmployees
                        : allEmployees.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final fullName = (data['personalInfo']
                                            ?['fullName'] ??
                                        '')
                                    .toString()
                                    .toLowerCase();
                            final email = (data['personalInfo']?['email'] ?? '')
                                .toString()
                                .toLowerCase();
                            final nationalId = (data['personalInfo']
                                            ?['nationalIdOrPassport'] ??
                                        '')
                                    .toString()
                                    .toLowerCase();
                            final docId = doc.id.toLowerCase();
                            return fullName.contains(_searchQuery) ||
                                email.contains(_searchQuery) ||
                                nationalId.contains(_searchQuery) ||
                                docId.contains(_searchQuery);
                          }).toList();

                    if (employees.isEmpty) {
                      _logger.w('No employees found');
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _searchQuery.isNotEmpty
                                  ? Icons.search_off
                                  : (_statusFilter == 'draft'
                                      ? Icons.drafts
                                      : Icons.inbox),
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No results found for "$_searchQuery"'
                                  : (_statusFilter == 'draft'
                                      ? 'No draft applications found'
                                      : 'No submitted applications found'),
                              style: const TextStyle(
                                  fontSize: 16, color: Colors.grey),
                            ),
                            if (_searchQuery.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              TextButton.icon(
                                onPressed: () =>
                                    setState(() => _searchQuery = ''),
                                icon: const Icon(Icons.clear),
                                label: const Text('Clear Search'),
                              ),
                            ],
                          ],
                        ),
                      );
                    }

                    // ── Improved Scrollable Table with visible scrollbars ─────────────────
                    return Scrollbar(
                      controller: _verticalScrollController,
                      thumbVisibility: true,
                      thickness: 8.0,
                      radius: const Radius.circular(8),
                      child: SingleChildScrollView(
                        controller: _verticalScrollController,
                        scrollDirection: Axis.vertical,
                        child: Scrollbar(
                          controller: _horizontalScrollController,
                          thumbVisibility: true,
                          thickness: 8.0,
                          radius: const Radius.circular(8),
                          child: SingleChildScrollView(
                            controller: _horizontalScrollController,
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowHeight: 50,
                              dataRowMinHeight: 48,
                              dataRowMaxHeight: 48,
                              headingRowColor: WidgetStateProperty.all(
                                  Colors.grey.shade100),
                              columnSpacing: 24,
                              headingTextStyle: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color.fromARGB(255, 86, 10, 119),
                              ),
                              dataTextStyle: const TextStyle(
                                  fontSize: 13, color: Colors.black87),
                              columns: [
                                const DataColumn(label: Text('No.')),
                                const DataColumn(label: Text('Full Name')),
                                const DataColumn(label: Text('Email')),
                                const DataColumn(label: Text('Phone')),
                                const DataColumn(label: Text('National ID')),
                                const DataColumn(label: Text('Job Title')),
                                const DataColumn(label: Text('Department')),
                                const DataColumn(label: Text('Employment Type')),
                                const DataColumn(label: Text('Start Date')),
                                const DataColumn(label: Text('KRA PIN')),
                                const DataColumn(label: Text('NSSF Number')),
                                const DataColumn(label: Text('SHIF Number')),
                                const DataColumn(label: Text('Basic Salary')),
                                const DataColumn(label: Text('Bank Name')),
                                const DataColumn(label: Text('Account Number')),
                                if (_statusFilter == 'submitted')
                                  const DataColumn(label: Text('Status')),
                                const DataColumn(label: Text('Created')),
                                if (_statusFilter == 'submitted')
                                  const DataColumn(label: Text('Submitted')),
                                // Documents column
                                const DataColumn(
                                  label: Tooltip(
                                    message:
                                        'Click the badge to view submitted documents',
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.folder_open_outlined,
                                          size: 14,
                                          color: Color.fromARGB(255, 86, 10, 119),
                                        ),
                                        SizedBox(width: 4),
                                        Text('Documents'),
                                      ],
                                    ),
                                  ),
                                ),
                                // ═══════════════════════════════════════════
                                //  NEW: Dynamic Policy Columns
                                // ═══════════════════════════════════════════
                                ..._policies.map((policy) => DataColumn(
                                  label: Tooltip(
                                    message: policy.title,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _getPolicyFileIcon(policy.fileType),
                                          size: 12,
                                          color: const Color.fromARGB(255, 86, 10, 119),
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            policy.title,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 11),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )),
                                const DataColumn(label: Text('Actions')),
                              ],
                              rows: employees.asMap().entries.map((entry) {
                                final index = entry.key;
                                final doc = entry.value;
                                final data =
                                    doc.data() as Map<String, dynamic>;
                                final fullName =
                                    data['personalInfo']?['fullName'] ?? '';

                                _logger.d(
                                    'Row ${index + 1}: $fullName (ID: ${doc.id})');

                                return DataRow(
                                  cells: [
                                    DataCell(Text('${index + 1}')),
                                    DataCell(SizedBox(
                                      width: 150,
                                      child: Text(fullName,
                                          overflow: TextOverflow.ellipsis),
                                    )),
                                    DataCell(SizedBox(
                                      width: 180,
                                      child: Text(
                                          data['personalInfo']?['email'] ?? '-',
                                          overflow: TextOverflow.ellipsis),
                                    )),
                                    DataCell(Text(
                                        data['personalInfo']?['phoneNumber'] ??
                                            '-')),
                                    DataCell(Text(
                                        data['personalInfo']
                                                ?['nationalIdOrPassport'] ??
                                            '-')),
                                    DataCell(SizedBox(
                                      width: 150,
                                      child: Text(
                                          data['employmentDetails']
                                                  ?['jobTitle'] ??
                                              '-',
                                          overflow: TextOverflow.ellipsis),
                                    )),
                                    DataCell(Text(
                                        data['employmentDetails']
                                                ?['department'] ??
                                            '-')),
                                    DataCell(Text(
                                        data['employmentDetails']
                                                ?['employmentType'] ??
                                            '-')),
                                    DataCell(Text(
                                      data['employmentDetails']?['startDate'] !=
                                              null
                                          ? DateFormat('dd/MM/yyyy').format(
                                              (data['employmentDetails']
                                                      ['startDate'] as Timestamp)
                                                  .toDate())
                                          : '-',
                                    )),
                                    DataCell(Text(
                                        data['statutoryDocs']?['kraPinNumber'] ??
                                            '-')),
                                    DataCell(Text(
                                        data['statutoryDocs']?['nssfNumber'] ??
                                            '-')),
                                    DataCell(Text(
                                        data['statutoryDocs']?['shifNumber'] ??
                                            data['statutoryDocs']?['nhifNumber'] ??
                                            '-')),
                                    DataCell(Text(
                                      data['payrollDetails']?['basicSalary'] !=
                                              null
                                          ? 'KES ${NumberFormat('#,###').format(data['payrollDetails']['basicSalary'])}'
                                          : '-',
                                    )),
                                    DataCell(Text(
                                        data['payrollDetails']?['bankDetails']
                                                ?['bankName'] ??
                                            '-')),
                                    DataCell(Text(
                                        data['payrollDetails']?['bankDetails']
                                                ?['accountNumber'] ??
                                            '-')),
                                    if (_statusFilter == 'submitted')
                                      DataCell(_buildStatusBadge(
                                          data['status'] ?? 'submitted')),
                                    DataCell(Text(
                                      data['createdAt'] != null
                                          ? DateFormat('dd/MM/yyyy').format(
                                              (data['createdAt'] as Timestamp)
                                                  .toDate())
                                          : '-',
                                    )),
                                    if (_statusFilter == 'submitted')
                                      DataCell(Text(
                                        data['submittedAt'] != null
                                            ? DateFormat('dd/MM/yyyy').format(
                                                (data['submittedAt'] as Timestamp)
                                                    .toDate())
                                            : '-',
                                      )),

                                    // Documents cell
                                    DataCell(
                                      fullName.isNotEmpty
                                          ? _EmployeeDocumentsCell(
                                              employeeName: fullName,
                                              logger: _logger,
                                            )
                                          : const Text('-'),
                                    ),

                                    // Policy status cells
                                    ..._policies.map((policy) {
                                      final employeeUid = data['uid'] as String? ?? '';
                                      final status = _allEmployeePolicyStatuses[employeeUid]?[policy.id];

                                      return DataCell(
                                        _buildPolicyStatusCell(status),
                                      );
                                    }),

                                    // Actions cell
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                              Icons.edit_note_rounded,
                                              size: 20,
                                              color: Color.fromARGB(255, 86, 10, 119),
                                            ),
                                            onPressed: () {
                                              _logger.i(
                                                  'Edit onboarding for: ${doc.id}');
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      HREmployeeOnboardingScreen(
                                                    employeeId: doc.id,
                                                    initialData: data,
                                                  ),
                                                ),
                                              );
                                            },
                                            tooltip: 'Edit Onboarding',
                                          ),
                                          if (data['status'] == 'draft')
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.delete_outline,
                                                  size: 20,
                                                  color: Colors.red),
                                              onPressed: () {
                                                _logger.i(
                                                    'Delete button clicked for employee: ${doc.id}');
                                                _deleteEmployee(doc.id, data);
                                              },
                                              tooltip: 'Remove User',
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPolicyStatusCell(PolicyStatus? status) {
    if (status == null) {
      // No status record yet - show pending/unread
      return Tooltip(
        message: 'Policy not yet acknowledged',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha:0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle_outlined, size: 12, color: Colors.grey),
              SizedBox(width: 4),
              Text(
                'Pending',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (status.isAccepted) {
      return Tooltip(
        message: 'Accepted on ${DateFormat('dd MMM yyyy').format(status.acceptedAt!)}',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green..withValues(alpha:0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.withValues(alpha:0.3)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, size: 12, color: Colors.green),
              SizedBox(width: 4),
              Text(
                'Accepted',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (status.isOpened) {
      return Tooltip(
        message: 'Opened but not yet accepted. Last opened: ${DateFormat('dd MMM yyyy').format(status.lastOpenedAt!)}',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha:0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withValues(alpha:0.3)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.visibility, size: 12, color: Colors.orange),
              SizedBox(width: 4),
              Text(
                'Opened',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Unread
    return Tooltip(
      message: 'Employee has not opened this policy',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha:0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withValues(alpha:0.3)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cancel, size: 12, color: Colors.red),
            SizedBox(width: 4),
            Text(
              'Unread',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getPolicyFileIcon(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf': return Icons.picture_as_pdf;
      case 'doc':
      case 'docx': return Icons.description;
      case 'xls':
      case 'xlsx': return Icons.table_chart;
      case 'ppt':
      case 'pptx': return Icons.slideshow;
      case 'txt': return Icons.text_snippet;
      default: return Icons.insert_drive_file;
    }
  }

  // ── Table header (unchanged) ────────────────────────────────────────────────
  Widget _buildTableHeader(double screenWidth) {
    final logoSize = (screenWidth * 0.025).clamp(35.0, 50.0);
    final titleSize = (screenWidth * 0.014).clamp(16.0, 22.0);
    final subtitleSize = (screenWidth * 0.010).clamp(12.0, 15.0);
    final badgeTextSize = (screenWidth * 0.009).clamp(11.0, 14.0);

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.025, vertical: 16),
      decoration: const BoxDecoration(
        color: Color.fromARGB(255, 86, 10, 119),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: logoSize,
            height: logoSize,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                'JV',
                style: TextStyle(
                  fontSize: logoSize * 0.45,
                  fontWeight: FontWeight.bold,
                  color: const Color.fromARGB(255, 86, 10, 119),
                ),
              ),
            ),
          ),
          SizedBox(width: screenWidth * 0.015),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'JV Almacis',
                  style: TextStyle(
                      fontSize: titleSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                const SizedBox(height: 3),
                Text(
                  'Employee Onboarding Records',
                  style:
                      TextStyle(fontSize: subtitleSize, color: Colors.white70),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _statusFilter == 'all'
                  ? 'ALL EMPLOYEES'
                  : (_statusFilter == 'draft' ? 'DRAFT VIEW' : 'SUBMITTED VIEW'),
              style: TextStyle(
                fontSize: badgeTextSize,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Firestore helpers ──────────────────────────────────────────────────────
  //
  // All onboarding records — draft or fully submitted — live in the single
  // `EmployeeDetails` collection; the Draft/Submitted tab toggle is a
  // client-side filter on the `status` field, not a choice of collection.
  // Filtering client-side (rather than `.where('status', ...)`) avoids
  // needing a new composite Firestore index for the combined
  // status-filter + createdAt-order query, matching the pattern already
  // used elsewhere in this codebase (e.g. PayrollService).
  /// Deliberately does NOT use `.orderBy('createdAt', ...)` — Firestore
  /// excludes any document missing the order-by field from the result set
  /// entirely (silently, no error), which was previously hiding employee
  /// records created through a path that didn't set `createdAt` (e.g. an
  /// older onboarding write, a manual console entry, or a migrated record).
  /// Sorting is done client-side instead so every `EmployeeDetails` doc is
  /// always shown, regardless of whether it has a `createdAt` timestamp.
  Stream<List<QueryDocumentSnapshot>> _getEmployeeDetailsStream() {
    return _firestore.collection('EmployeeDetails').snapshots().map((snapshot) {
      final docs = snapshot.docs.toList();
      docs.sort((a, b) {
        final aTime = a.data()['createdAt'] as Timestamp?;
        final bTime = b.data()['createdAt'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1; // docs without createdAt sort last
        if (bTime == null) return -1;
        return bTime.compareTo(aTime); // descending
      });
      return docs;
    });
  }

  bool _matchesStatusFilter(Map<String, dynamic> data) {
    if (_statusFilter == 'all') return true;
    final status = data['status'] ?? 'draft';
    return _statusFilter == 'draft' ? status == 'draft' : status != 'draft';
  }

  // ── Status badge ───────────────────────────────────────────────────────────
  Widget _buildStatusBadge(String status) {
    Color color;
    String text;

    switch (status) {
      case 'submitted':
        color = Colors.orange;
        text = 'Submitted';
        break;
      case 'approved':
        color = Colors.green;
        text = 'Approved';
        break;
      case 'rejected':
        color = Colors.red;
        text = 'Rejected';
        break;
      default:
        color = Colors.grey;
        text = 'Draft';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
            color: color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }

  // ── Delete employee draft ──────────────────────────────────────────────────
  Future<void> _deleteEmployee(String id, Map<String, dynamic> data) async {
    _logger.i('=== DELETE EMPLOYEE INITIATED ===');
    _logger.d('Employee ID: $id');

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 12),
            const Expanded(child: Text('Remove User')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to remove this User?',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Text(
                'Employee: ${data['personalInfo']?['fullName'] ?? 'Unknown'}',
                style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone.',
                      style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                          fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _logger.d('Delete cancelled by user');
              Navigator.pop(context, false);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _logger.d('Delete confirmed by user');
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        _logger.i('Deleting employee record...');
        await _firestore.collection('EmployeeDetails').doc(id).delete();
        _logger.i('✅ Employee record deleted successfully');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Draft deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e, stackTrace) {
        _logger.e('❌ ERROR DELETING EMPLOYEE',
            error: e, stackTrace: stackTrace);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting draft: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // ── Excel download (unchanged) ─────────────────────────────────────────────
  Future<void> _downloadExcel() async {
    _logger.i('=== EXCEL DOWNLOAD INITIATED ===');

    setState(() {
      _isDownloading = true;
      _downloadProgress = 'Fetching data...';
    });

    String? downloadedFilePath;

    try {
      _logger.i('Fetching data from EmployeeDetails (filter: $_statusFilter)...');

      if (mounted) setState(() => _downloadProgress = 'Loading employees...');

      final fullSnapshot = await _firestore.collection('EmployeeDetails').get();
      final docs = fullSnapshot.docs
          .where((doc) => _matchesStatusFilter(doc.data()))
          .toList();
      _logger.i('Fetched ${docs.length} documents matching filter "$_statusFilter"');

      if (docs.isEmpty) {
        throw Exception('No employee data found for filter "$_statusFilter"');
      }

      if (mounted) {
        setState(() =>
            _downloadProgress =
                'Processing ${docs.length} records...');
      }

      final employees = <EmployeeOnboarding>[];
      for (var doc in docs) {
        try {
          final employee = EmployeeOnboarding.fromMap(doc.data());
          employees.add(employee);
          _logger.d('Converted employee: ${employee.personalInfo.fullName}');
        } catch (e) {
          _logger.e('Error converting document ${doc.id}', error: e);
        }
      }

      _logger.i('Successfully converted ${employees.length} employees');

      if (mounted) {
        setState(() => _downloadProgress = 'Generating Excel...');
      }

      final result =
          await ExcelGenerationService.generateEmployeeOnboardingExcel(
              employees);
      final fileName = result['fileName'] as String;
      final fileBytes = result['fileBytes'] as Uint8List;
      final fileSize = result['fileSize'] as int;

      _logger.i('Excel file generated: $fileName ($fileSize bytes)');

      if (mounted) {
        setState(() => _downloadProgress = 'Downloading...');
      }

      downloadedFilePath =
          await ExcelDownloadService.downloadExcel(fileBytes, fileName);

      _logger.i('✅ Excel download completed successfully');

      if (!mounted) return;

      final fileReadableSize =
          ExcelDownloadService.getReadableFileSize(fileSize);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            kIsWeb
                ? 'Excel file downloaded successfully!\n$fileName ($fileReadableSize)'
                : 'Excel file downloaded successfully!\nLocation: $downloadedFilePath\nSize: $fileReadableSize',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
          action: kIsWeb
              ? null
              : SnackBarAction(
                  label: 'Open',
                  textColor: Colors.white,
                  onPressed: () async {
                    if (downloadedFilePath != null) {
                      try {
                        await ExcelDownloadService.openFile(
                            downloadedFilePath);
                      } catch (e) {
                        _logger.e('Error opening file', error: e);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Could not open file: $e'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        }
                      }
                    }
                  },
                ),
        ),
      );
    } catch (e, stackTrace) {
      _logger.e('❌ ERROR DOWNLOADING EXCEL',
          error: e, stackTrace: stackTrace);

      if (!mounted) return;

      String errorMessage = 'Error generating Excel: $e';
      SnackBarAction? action;

      if (e.toString().contains('permission')) {
        errorMessage =
            'Storage permission denied. Please enable it in Settings.';
        action = SnackBarAction(
          label: 'Settings',
          textColor: Colors.white,
          onPressed: () => openAppSettings(),
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: action,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = null;
        });
      }
      _logger.d('=== EXCEL DOWNLOAD COMPLETED ===');
    }
  }
}