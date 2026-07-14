import 'package:almahub/models/employee_onboarding_models.dart';
import 'package:almahub/screens/hr/onboarding_shared_widgets.dart';
import 'package:flutter/material.dart';

/// Step 3 — Mandatory Statutory Documents
class Step3StatutoryDocs extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final StatutoryDocuments statutoryDocs;
  final bool isUploadingFile;
  final void Function(StatutoryDocuments updated) onChanged;
  final Future<void> Function(
    String fieldName,
    void Function(String url) onSuccess,
  ) onUpload;

  const Step3StatutoryDocs({
    super.key,
    required this.formKey,
    required this.statutoryDocs,
    required this.isUploadingFile,
    required this.onChanged,
    required this.onUpload,
  });

  StatutoryDocuments _copy({
    String? kraPinNumber,
    String? kraPinCertificateUrl,
    String? nssfNumber,
    String? nssfConfirmationUrl,
    String? shifNumber,
    String? shifConfirmationUrl,
    String? p9FormUrl,
  }) {
    return StatutoryDocuments(
      kraPinNumber: kraPinNumber ?? statutoryDocs.kraPinNumber,
      kraPinCertificateUrl:
          kraPinCertificateUrl ?? statutoryDocs.kraPinCertificateUrl,
      nssfNumber: nssfNumber ?? statutoryDocs.nssfNumber,
      nssfConfirmationUrl:
          nssfConfirmationUrl ?? statutoryDocs.nssfConfirmationUrl,
      shifNumber: shifNumber ?? statutoryDocs.shifNumber,
      shifConfirmationUrl:
          shifConfirmationUrl ?? statutoryDocs.shifConfirmationUrl,
      p9FormUrl: p9FormUrl ?? statutoryDocs.p9FormUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: OnboardingColors.background,
      child: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const StepHeaderCard(
              icon: Icons.gavel_rounded,
              title: 'Statutory Documents',
              subtitle: 'KRA, NSSF, SHIF & tax compliance documents',
            ),
            const SizedBox(height: 20),

            // ── KRA PIN ──────────────────────────────────────────────────
            FormSection(
              title: 'KRA PIN',
              icon: Icons.receipt_long_outlined,
              children: [
                TextFormField(
                  initialValue: statutoryDocs.kraPinNumber,
                  decoration: onboardingInputDecoration('KRA PIN Number *'),
                  textCapitalization: TextCapitalization.characters,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'KRA PIN is required' : null,
                  onChanged: (v) => onChanged(_copy(kraPinNumber: v)),
                ),
                const SizedBox(height: 14),
                UploadFieldButton(
                  label: 'KRA PIN Certificate',
                  hint: 'Upload the certificate issued by KRA',
                  isRequired: true,
                  isUploading: isUploadingFile,
                  uploadedUrl: statutoryDocs.kraPinCertificateUrl,
                  onPressed: () => onUpload('kra_pin', (url) {
                    onChanged(_copy(kraPinCertificateUrl: url));
                  }),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── NSSF ────────────────────────────────────────────────────
            FormSection(
              title: 'NSSF',
              icon: Icons.verified_user_outlined,
              children: [
                TextFormField(
                  initialValue: statutoryDocs.nssfNumber,
                  decoration: onboardingInputDecoration('NSSF Member Number *'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'NSSF number is required' : null,
                  onChanged: (v) => onChanged(_copy(nssfNumber: v)),
                ),
                const SizedBox(height: 14),
                UploadFieldButton(
                  label: 'NSSF Registration Confirmation',
                  hint: 'NSSF confirmation letter or e-slip',
                  isRequired: true,
                  isUploading: isUploadingFile,
                  uploadedUrl: statutoryDocs.nssfConfirmationUrl,
                  onPressed: () => onUpload('nssf_confirmation', (url) {
                    onChanged(_copy(nssfConfirmationUrl: url));
                  }),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── SHIF / SHA ───────────────────────────────────────────────
            FormSection(
              title: 'SHIF / SHA',
              icon: Icons.health_and_safety_outlined,
              children: [
                TextFormField(
                  initialValue: statutoryDocs.shifNumber,
                  decoration: onboardingInputDecoration('SHIF / SHA Member Number *'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'SHIF number is required' : null,
                  onChanged: (v) => onChanged(_copy(shifNumber: v)),
                ),
                const SizedBox(height: 14),
                UploadFieldButton(
                  label: 'SHIF Registration Confirmation',
                  hint: 'SHIF confirmation letter or e-slip',
                  isRequired: true,
                  isUploading: isUploadingFile,
                  uploadedUrl: statutoryDocs.shifConfirmationUrl,
                  onPressed: () => onUpload('shif_confirmation', (url) {
                    onChanged(_copy(shifConfirmationUrl: url));
                  }),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── P9 Form (optional) ───────────────────────────────────────
            FormSection(
              title: 'P9 Form (Optional)',
              icon: Icons.description_outlined,
              children: [
                InfoBanner(
                  message:
                      'Required only if joining mid-year. Upload the P9 form from your previous employer.',
                  icon: Icons.info_outline_rounded,
                ),
                const SizedBox(height: 14),
                UploadFieldButton(
                  label: 'P9 Form from Previous Employer',
                  hint: 'Required when joining mid-year',
                  isRequired: false,
                  isUploading: isUploadingFile,
                  uploadedUrl: statutoryDocs.p9FormUrl,
                  onPressed: () => onUpload('p9_form', (url) {
                    onChanged(_copy(p9FormUrl: url));
                  }),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}