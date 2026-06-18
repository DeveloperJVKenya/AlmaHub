import 'package:almahub/screens/hr/Policy%20Management/company_policy_model.dart';
import 'package:almahub/screens/hr/Policy%20Management/policy_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:logger/logger.dart';
import 'dart:io' show File;
//import 'dart:typed_data';


/// HR screen for uploading and managing company policies.
/// Policies are stored in Firestore (CompanyPolicies) and Firebase Storage (company_policies/).
class HRPolicyManagementScreen extends StatefulWidget {
  const HRPolicyManagementScreen({super.key});

  @override
  State<HRPolicyManagementScreen> createState() => _HRPolicyManagementScreenState();
}

class _HRPolicyManagementScreenState extends State<HRPolicyManagementScreen> {
  final PolicyService _policyService = PolicyService();
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

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isUploading = false;
  //double _uploadProgress = 0.0;
  PlatformFile? _selectedFile;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // ── File Selection ────────────────────────────────────────────────────────
  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf', 'doc', 'docx', 'txt',
          'xls', 'xlsx', 'ppt', 'pptx',
          'jpg', 'jpeg', 'png',
        ],
        withData: kIsWeb, // Load bytes on web
        withReadStream: !kIsWeb, // Use stream on native for large files
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() => _selectedFile = result.files.first);
        _logger.i('File selected: ${result.files.first.name}');
      }
    } catch (e) {
      _logger.e('Error picking file', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── Upload Policy ─────────────────────────────────────────────────────────
  Future<void> _uploadPolicy() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a policy document file.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      dynamic fileData;
      if (kIsWeb) {
        fileData = _selectedFile!.bytes;
        if (fileData == null) {
          throw Exception('File bytes not available on web');
        }
      } else {
        if (_selectedFile!.path == null) {
          throw Exception('File path not available');
        }
        fileData = File(_selectedFile!.path!);
      }

      final policy = await _policyService.uploadPolicy(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        fileData: fileData,
        fileName: _selectedFile!.name,
        fileType: _selectedFile!.extension ?? 'unknown',
      );

      if (policy != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Policy uploaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _resetForm();
      }
    } catch (e, stackTrace) {
      _logger.e('Error uploading policy', error: e, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _resetForm() {
    _formKey.currentState!.reset();
    _titleController.clear();
    _descriptionController.clear();
    setState(() => _selectedFile = null);
  }

  // ── Delete Policy ─────────────────────────────────────────────────────────
  Future<void> _deletePolicy(CompanyPolicy policy) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade600, size: 26),
            const SizedBox(width: 10),
            const Expanded(child: Text('Delete Policy')),
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
                  const Icon(Icons.policy, color: Color(0xFF54046C), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      policy.title,
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
                color: Colors.red.withValues(alpha:0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha:0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.red, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This will remove the policy from all employee dashboards and delete associated status records.',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isUploading = true);
    try {
      final success = await _policyService.deletePolicy(policy);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Policy deleted successfully.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _logger.e('Error deleting policy', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting policy: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ── Responsive breakpoints ───────────────────────────────────────────────
  // Centralised so the body layout and the FAB visibility logic can never
  // disagree with each other.
  static const double _wideBreakpoint = 900;
  bool _isWideLayout(double width) => width >= _wideBreakpoint;

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF54046C),
        title: const Text(
          'Policy Management',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh',
            onPressed: () => setState(() {}),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = _isWideLayout(constraints.maxWidth);

            if (isWide) {
              // Desktop / large-tablet landscape: two-pane layout.
              // The left pane gets an explicit height equal to the
              // available space and scrolls internally, so the form can
              // never overflow vertically even on short-height monitors
              // (e.g. small laptops) where the right pane's policy list
              // would otherwise fit but the form would not.
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 420,
                    height: constraints.maxHeight,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: _buildUploadForm(),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      child: _buildPolicyList(),
                    ),
                  ),
                ],
              );
            }

            // Mobile / tablet portrait / landscape phones: single scrollable
            // column. Wrapping in SingleChildScrollView means rotating the
            // device or running on a shorter screen just changes how much
            // scrolling is needed instead of causing a RenderFlex overflow.
            // The ConstrainedBox keeps the form a comfortable reading width
            // on tablets instead of stretching it edge-to-edge.
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: _buildUploadForm(),
                ),
              ),
            );
          },
        ),
      ),
      // On mobile/tablet, the policy list lives in a bottom sheet instead of
      // a fixed pane, so it never competes with the form for vertical space.
      floatingActionButton: LayoutBuilder(
        builder: (context, constraints) {
          if (_isWideLayout(constraints.maxWidth)) {
            return const SizedBox.shrink();
          }
          return FloatingActionButton.extended(
            onPressed: () => _showPolicyListBottomSheet(context),
            backgroundColor: const Color(0xFF54046C),
            icon: const Icon(Icons.list, color: Colors.white),
            label: const Text(
              'View Policies',
              style: TextStyle(color: Colors.white),
            ),
          );
        },
      ),
    );
  }

  Widget _buildUploadForm() {
    return Card(
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha:0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF54046C).withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.upload_file, color: Color(0xFF54046C), size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Upload New Policy',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Add a new company policy document',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),

              // Title
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Policy Title *',
                  hintText: 'e.g., HR Policy 2026, Code of Conduct',
                  prefixIcon: const Icon(Icons.title),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Policy title is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Description (Optional)',
                  hintText: 'Brief description of this policy...',
                  prefixIcon: const Icon(Icons.description),
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),

              // File Picker
              InkWell(
                onTap: _isUploading ? null : _pickFile,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _selectedFile != null
                        ? Colors.green.withValues(alpha:0.05)
                        : Colors.grey.withValues(alpha:0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedFile != null ? Colors.green : Colors.grey.shade300,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _selectedFile != null ? Icons.check_circle : Icons.cloud_upload,
                        size: 40,
                        color: _selectedFile != null ? Colors.green : const Color(0xFF54046C),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _selectedFile != null
                            ? 'File Selected: ${_selectedFile!.name}'
                            : 'Tap to Select Policy Document',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _selectedFile != null ? Colors.green.shade700 : Colors.grey.shade700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (_selectedFile != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Size: ${_formatFileSize(_selectedFile!.size)}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        'Supported: PDF, Word, Excel, PowerPoint, Text, Images',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Upload Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isUploading ? null : _uploadPolicy,
                  icon: _isUploading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.upload),
                  label: Text(
                    _isUploading ? 'Uploading...' : 'Upload Policy',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF54046C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPolicyList() {
    return StreamBuilder<List<CompanyPolicy>>(
      stream: _policyService.getPoliciesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 8),
                Text('Error: ${snapshot.error}'),
              ],
            ),
          );
        }

        final policies = snapshot.data ?? [];

        if (policies.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.folder_open_outlined, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No policies uploaded yet',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Upload your first policy using the form',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  const Icon(Icons.folder_copy, color: Color(0xFF54046C)),
                  const SizedBox(width: 8),
                  Text(
                    'Uploaded Policies (${policies.length})',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: policies.length,
                itemBuilder: (context, index) {
                  final policy = policies[index];
                  return _PolicyListTile(
                    policy: policy,
                    onDelete: () => _deletePolicy(policy),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _showPolicyListBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Uploaded Policies',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: StreamBuilder<List<CompanyPolicy>>(
                  stream: _policyService.getPoliciesStream(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final policies = snapshot.data!;
                    if (policies.isEmpty) {
                      return const Center(child: Text('No policies yet'));
                    }
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: policies.length,
                      itemBuilder: (context, index) {
                        return _PolicyListTile(
                          policy: policies[index],
                          onDelete: () => _deletePolicy(policies[index]),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// ── Policy List Tile ─────────────────────────────────────────────────────────
class _PolicyListTile extends StatelessWidget {
  final CompanyPolicy policy;
  final VoidCallback onDelete;

  const _PolicyListTile({
    required this.policy,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _getFileColor(policy.fileType).withValues(alpha:0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            _getFileIcon(policy.fileType),
            color: _getFileColor(policy.fileType),
            size: 24,
          ),
        ),
        title: Text(
          policy.title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              policy.fileName,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              'Uploaded: ${_formatDate(policy.uploadedAt)}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          tooltip: 'Delete Policy',
          onPressed: onDelete,
        ),
      ),
    );
  }

  Color _getFileColor(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf': return Colors.red;
      case 'doc':
      case 'docx': return Colors.blue;
      case 'xls':
      case 'xlsx': return Colors.green;
      case 'ppt':
      case 'pptx': return Colors.orange;
      case 'txt': return Colors.grey;
      default: return const Color(0xFF54046C);
    }
  }

  IconData _getFileIcon(String fileType) {
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}