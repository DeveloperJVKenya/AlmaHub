import 'package:almahub/screens/hr/Policy%20Management/company_policy_model.dart';
import 'package:almahub/screens/hr/Policy%20Management/policy_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import 'package:logger/logger.dart';

/// Screen for viewing a policy document.
/// Tracks when the policy is opened (first open + every reopen).
/// Employee must return to the Contracts section to mark as accepted.
class PolicyViewerScreen extends StatefulWidget {
  final CompanyPolicy policy;
  final String employeeUid;

  const PolicyViewerScreen({
    super.key,
    required this.policy,
    required this.employeeUid,
  });

  @override
  State<PolicyViewerScreen> createState() => _PolicyViewerScreenState();
}

class _PolicyViewerScreenState extends State<PolicyViewerScreen> {
  final PolicyService _policyService = PolicyService();
  final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 1,
      errorMethodCount: 4,
      lineLength: 100,
      colors: true,
      printEmojis: true,
    ),
  );

  bool _isLoading = true;
  bool _hasError = false;
  String? _viewerUrl;

  @override
  void initState() {
    super.initState();
    _initializeViewer();
  }

  /// Records the policy open event and prepares the viewer URL.
  Future<void> _initializeViewer() async {
    try {
      // Record open event in Firestore (tracks first open + lastOpenedAt)
      await _policyService.recordPolicyOpened(
        widget.employeeUid,
        widget.policy.id,
      );
      _logger.i('Policy opened tracked: ${widget.policy.title}');

      // Prepare viewer URL based on file type
      final url = _prepareViewerUrl(widget.policy.fileUrl, widget.policy.fileType);

      if (mounted) {
        setState(() {
          _viewerUrl = url;
          _isLoading = false;
        });
      }

      // On web, auto-launch in new tab since in-app PDF viewing is limited
      if (kIsWeb) {
        _launchExternal(url);
      }
    } catch (e) {
      _logger.e('Error initializing policy viewer', error: e);
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  /// Prepares the appropriate viewer URL based on file type.
  String _prepareViewerUrl(String fileUrl, String fileType) {
    final ext = fileType.toLowerCase();

    // For PDFs, use Google Docs Viewer as a reliable cross-platform solution
    if (ext == 'pdf') {
      // Google Docs Viewer works for public URLs; for Firebase Storage URLs
      // we use the direct URL with external browser launch
      return fileUrl;
    }

    // For Word/Excel/PowerPoint, use Microsoft Office Online Viewer
    if (['doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx'].contains(ext)) {
      // Office Online requires publicly accessible URLs
      // For Firebase Storage, the URL is already public with token
      return 'https://view.officeapps.live.com/op/embed.aspx?src=${Uri.encodeComponent(fileUrl)}';
    }

    // For text files and others, direct URL
    return fileUrl;
  }

  Future<void> _launchExternal(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      _logger.e('Error launching URL', error: e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF54046C),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.policy.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Company Policy Document',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          if (!kIsWeb)
            IconButton(
              icon: const Icon(Icons.open_in_browser, color: Colors.white),
              tooltip: 'Open in Browser',
              onPressed: _viewerUrl != null ? () => _launchExternal(_viewerUrl!) : null,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF54046C)),
            SizedBox(height: 16),
            Text('Preparing document...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (_hasError || _viewerUrl == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Could not load document',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Please try opening it in your browser.',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _launchExternal(widget.policy.fileUrl),
              icon: const Icon(Icons.open_in_browser),
              label: const Text('Open in Browser'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF54046C),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    // On web, show instructions since we launched in new tab
    if (kIsWeb) {
      return _buildWebInstructions();
    }

    // On mobile, show the document viewer
    return _buildDocumentViewer();
  }

  Widget _buildWebInstructions() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.05),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF54046C).withValues(alpha:0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.open_in_browser,
                size: 48,
                color: Color(0xFF54046C),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              widget.policy.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              widget.policy.fileName,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            const Text(
              'The document has been opened in a new browser tab.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              'Please read the policy carefully. When you return, go to "Contracts & Internal Compliance" to mark it as read and accepted.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _launchExternal(_viewerUrl!),
              icon: const Icon(Icons.refresh),
              label: const Text('Reopen Document'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF54046C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Return to Dashboard'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentViewer() {
    final ext = widget.policy.fileType.toLowerCase();

    // For images, display directly
    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext)) {
      return InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Center(
          child: Image.network(
            _viewerUrl!,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                      : null,
                  color: const Color(0xFF54046C),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return _buildErrorFallback();
            },
          ),
        ),
      );
    }

    // For PDFs and Office docs, use web view or external launcher
    return _buildExternalViewerFallback();
  }

  Widget _buildExternalViewerFallback() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha:0.05),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _FileTypeIcon(fileType: widget.policy.fileType),
            const SizedBox(height: 20),
            Text(
              widget.policy.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              widget.policy.fileName,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            const Text(
              'This document type requires an external viewer.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              'Please open it in your preferred document viewer app.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _launchExternal(_viewerUrl!),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open Document'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF54046C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Return to Dashboard'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorFallback() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.broken_image, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _launchExternal(widget.policy.fileUrl),
            child: const Text('Open Externally'),
          ),
        ],
      ),
    );
  }
}

/// Icon widget based on file type.
class _FileTypeIcon extends StatelessWidget {
  final String fileType;
  const _FileTypeIcon({required this.fileType});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;

    switch (fileType.toLowerCase()) {
      case 'pdf':
        icon = Icons.picture_as_pdf;
        color = Colors.red;
        break;
      case 'doc':
      case 'docx':
        icon = Icons.description;
        color = Colors.blue;
        break;
      case 'xls':
      case 'xlsx':
        icon = Icons.table_chart;
        color = Colors.green;
        break;
      case 'ppt':
      case 'pptx':
        icon = Icons.slideshow;
        color = Colors.orange;
        break;
      case 'txt':
        icon = Icons.text_snippet;
        color = Colors.grey;
        break;
      default:
        icon = Icons.insert_drive_file;
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 48, color: color),
    );
  }
}
