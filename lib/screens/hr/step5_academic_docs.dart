import 'package:almahub/screens/hr/employee_onboarding_models.dart';
import 'package:almahub/screens/hr/onboarding_shared_widgets.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Step 5 — Academic & Professional Documents
///
/// Three distinct sections:
///   1. Academic / Professional Certificates  (multi-upload, merged list)
///   2. Training Certificates                 (multi-upload, new)
///   3. Professional Certifications           (multi-upload, professional body
///                                             / commission identity docs)
class Step5AcademicDocs extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final AcademicDocuments academicDocs;
  final bool isUploadingFile;
  final String employeeName;
  final void Function(AcademicDocuments updated) onChanged;
  /// Full upload handler — picks file via FilePicker, uploads to storage,
  /// returns URL via [onSuccess].
  final Future<void> Function(
    String fieldName,
    void Function(String url) onSuccess,
  ) onUpload;

  const Step5AcademicDocs({
    super.key,
    required this.formKey,
    required this.academicDocs,
    required this.isUploadingFile,
    required this.employeeName,
    required this.onChanged,
    required this.onUpload,
  });

  // ── Helpers ────────────────────────────────────────────────────────────────
  AcademicDocuments _copy({
    List<DocumentInfo>? academicCertificates,
    List<DocumentInfo>? trainingCertificates,
    List<DocumentInfo>? professionalCertificates,
  }) {
    return AcademicDocuments(
      academicCertificates:
          academicCertificates ?? academicDocs.academicCertificates,
      trainingCertificates:
          trainingCertificates ?? academicDocs.trainingCertificates,
      professionalCertificates:
          professionalCertificates ?? academicDocs.professionalCertificates,
      professionalRegistrations: academicDocs.professionalRegistrations,
    );
  }

  String _formatDate(DateTime dt) => DateFormat('dd MMM yyyy').format(dt);

  // ── Section 1 ──────────────────────────────────────────────────────────────
  Widget _buildAcademicSection() {
    return FormSection(
      title: 'Academic / Professional Certificates',
      icon: Icons.school_rounded,
      children: [
        const SubSectionLabel(
          'Upload all academic and professional qualification certificates',
          hint: 'e.g. Degree, Diploma, Masters, Professional Qualification',
        ),
        const SizedBox(height: 14),

        // Uploaded items list
        if (academicDocs.academicCertificates.isNotEmpty) ...[
          ...academicDocs.academicCertificates.asMap().entries.map((e) {
            return DocumentListTile(
              name: e.value.name,
              uploadedAt: 'Uploaded ${_formatDate(e.value.uploadedAt)}',
              icon: Icons.school_rounded,
              onDelete: () {
                final updated =
                    List<DocumentInfo>.from(academicDocs.academicCertificates)
                      ..removeAt(e.key);
                onChanged(_copy(academicCertificates: updated));
              },
            );
          }),
          const SizedBox(height: 8),
        ],

        AddDocumentButton(
          label: 'Add Academic / Professional Certificate',
          isUploading: isUploadingFile,
          onPressed: () => onUpload('academic_cert', (url) {
            final n = academicDocs.academicCertificates.length + 1;
            final doc = DocumentInfo(
              name: 'Certificate $n',
              url: url,
              type: 'pdf',
              uploadedAt: DateTime.now(),
            );
            onChanged(
              _copy(academicCertificates: [
                ...academicDocs.academicCertificates,
                doc,
              ]),
            );
          }),
        ),

        // Count badge
        if (academicDocs.academicCertificates.isNotEmpty) ...[
          const SizedBox(height: 10),
          _CountBadge(
            count: academicDocs.academicCertificates.length,
            label: 'certificate(s) added',
            color: OnboardingColors.primary,
          ),
        ],
      ],
    );
  }

  // ── Section 2 ──────────────────────────────────────────────────────────────
  Widget _buildTrainingSection() {
    return FormSection(
      title: 'Training Certificates',
      icon: Icons.menu_book_rounded,
      iconColor: const Color(0xFF0891B2), // teal accent
      children: [
        const SubSectionLabel(
          'Upload certificates from training programmes attended',
          hint:
              'e.g. Fire Safety, First Aid, Leadership, Compliance, Induction training',
        ),
        const SizedBox(height: 14),

        if (academicDocs.trainingCertificates.isNotEmpty) ...[
          ...academicDocs.trainingCertificates.asMap().entries.map((e) {
            return DocumentListTile(
              name: e.value.name,
              uploadedAt: 'Uploaded ${_formatDate(e.value.uploadedAt)}',
              icon: Icons.menu_book_rounded,
              iconColor: const Color(0xFF0891B2),
              onDelete: () {
                final updated =
                    List<DocumentInfo>.from(academicDocs.trainingCertificates)
                      ..removeAt(e.key);
                onChanged(_copy(trainingCertificates: updated));
              },
            );
          }),
          const SizedBox(height: 8),
        ],

        AddDocumentButton(
          label: 'Add Training Certificate',
          isUploading: isUploadingFile,
          color: const Color(0xFF0891B2),
          onPressed: () => onUpload('training_cert', (url) {
            final n = academicDocs.trainingCertificates.length + 1;
            final doc = DocumentInfo(
              name: 'Training Certificate $n',
              url: url,
              type: 'pdf',
              uploadedAt: DateTime.now(),
            );
            onChanged(
              _copy(trainingCertificates: [
                ...academicDocs.trainingCertificates,
                doc,
              ]),
            );
          }),
        ),

        if (academicDocs.trainingCertificates.isNotEmpty) ...[
          const SizedBox(height: 10),
          _CountBadge(
            count: academicDocs.trainingCertificates.length,
            label: 'training certificate(s) added',
            color: const Color(0xFF0891B2),
          ),
        ],
      ],
    );
  }

  // ── Section 3 ──────────────────────────────────────────────────────────────
  Widget _buildProfessionalCertSection() {
    return FormSection(
      title: 'Professional Certifications',
      icon: Icons.workspace_premium_rounded,
      iconColor: const Color(0xFFD97706), // amber accent
      children: [
        const SubSectionLabel(
          'Upload professional body & commission membership documents',
          hint:
              'e.g. EBK, ICPAK, IHRM, Law Society, NMK, EARC — any document issued by a '
              'professional body that identifies you in your field',
        ),
        const SizedBox(height: 14),

        if (academicDocs.professionalCertificates.isNotEmpty) ...[
          ...academicDocs.professionalCertificates.asMap().entries.map((e) {
            return DocumentListTile(
              name: e.value.name,
              uploadedAt: 'Uploaded ${_formatDate(e.value.uploadedAt)}',
              icon: Icons.workspace_premium_rounded,
              iconColor: const Color(0xFFD97706),
              onDelete: () {
                final updated = List<DocumentInfo>.from(
                    academicDocs.professionalCertificates)
                  ..removeAt(e.key);
                onChanged(_copy(professionalCertificates: updated));
              },
            );
          }),
          const SizedBox(height: 8),
        ],

        AddDocumentButton(
          label: 'Add Professional Certification Document',
          isUploading: isUploadingFile,
          color: const Color(0xFFD97706),
          onPressed: () => onUpload('professional_cert', (url) {
            final n = academicDocs.professionalCertificates.length + 1;
            final doc = DocumentInfo(
              name: 'Professional Certification $n',
              url: url,
              type: 'pdf',
              uploadedAt: DateTime.now(),
            );
            onChanged(
              _copy(professionalCertificates: [
                ...academicDocs.professionalCertificates,
                doc,
              ]),
            );
          }),
        ),

        if (academicDocs.professionalCertificates.isNotEmpty) ...[
          const SizedBox(height: 10),
          _CountBadge(
            count: academicDocs.professionalCertificates.length,
            label: 'certification(s) added',
            color: const Color(0xFFD97706),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalDocs = academicDocs.academicCertificates.length +
        academicDocs.trainingCertificates.length +
        academicDocs.professionalCertificates.length;

    return Container(
      color: OnboardingColors.background,
      child: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const StepHeaderCard(
              icon: Icons.folder_special_rounded,
              title: 'Academic & Professional Documents',
              subtitle:
                  'Certificates, training & professional body documents',
            ),
            const SizedBox(height: 16),

            // Total uploaded summary banner
            if (totalDocs > 0)
              InfoBanner(
                message:
                    '$totalDocs document(s) uploaded across all sections',
                icon: Icons.check_circle_outline_rounded,
                color: OnboardingColors.success,
              ),
            if (totalDocs > 0) const SizedBox(height: 16),

            // ── Section 1 ──────────────────────────────────────────────
            _buildAcademicSection(),
            const SizedBox(height: 16),

            // ── Section 2 ──────────────────────────────────────────────
            _buildTrainingSection(),
            const SizedBox(height: 16),

            // ── Section 3 ──────────────────────────────────────────────
            _buildProfessionalCertSection(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Count badge widget
// ─────────────────────────────────────────────────────────────────────────────
class _CountBadge extends StatelessWidget {
  final int count;
  final String label;
  final Color color;

  const _CountBadge({
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_rounded, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                '$count $label',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}