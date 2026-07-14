import 'package:almahub/models/employee_onboarding_models.dart';
import 'package:almahub/screens/hr/onboarding_shared_widgets.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Step 6 — Contracts & HR Forms
class Step6ContractsForms extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final ContractsAndForms contractsForms;
  final bool isUploadingFile;
  final void Function(ContractsAndForms updated) onChanged;
  final Future<void> Function(
    String fieldName,
    void Function(String url) onSuccess,
  ) onUpload;

  const Step6ContractsForms({
    super.key,
    required this.formKey,
    required this.contractsForms,
    required this.isUploadingFile,
    required this.onChanged,
    required this.onUpload,
  });

  ContractsAndForms _copy({
    String? employmentContractUrl,
    String? employeeInfoFormUrl,
    String? ndaUrl,
    bool? codeOfConductAcknowledged,
    bool? dataProtectionConsentGiven,
    DateTime? consentDate,
    bool clearConsentDate = false,
  }) {
    return ContractsAndForms(
      employmentContractUrl:
          employmentContractUrl ?? contractsForms.employmentContractUrl,
      employeeInfoFormUrl:
          employeeInfoFormUrl ?? contractsForms.employeeInfoFormUrl,
      ndaUrl: ndaUrl ?? contractsForms.ndaUrl,
      codeOfConductAcknowledged:
          codeOfConductAcknowledged ?? contractsForms.codeOfConductAcknowledged,
      dataProtectionConsentGiven:
          dataProtectionConsentGiven ?? contractsForms.dataProtectionConsentGiven,
      consentDate: clearConsentDate
          ? null
          : (consentDate ?? contractsForms.consentDate),
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
              icon: Icons.article_rounded,
              title: 'Contracts & HR Forms',
              subtitle: 'Employment documents, NDA & legal consents',
            ),
            const SizedBox(height: 20),

            // ── Document Uploads ─────────────────────────────────────────
            FormSection(
              title: 'Employment Documents',
              icon: Icons.description_outlined,
              children: [
                UploadFieldButton(
                  label: 'Signed Employment Contract / Offer Letter',
                  hint: 'The signed copy of the employment contract',
                  isRequired: true,
                  isUploading: isUploadingFile,
                  uploadedUrl: contractsForms.employmentContractUrl,
                  onPressed: () => onUpload('employment_contract', (url) {
                    onChanged(_copy(employmentContractUrl: url));
                  }),
                ),
                const SizedBox(height: 16),

                UploadFieldButton(
                  label: 'Employee Information Form',
                  hint: 'The completed HR information collection form',
                  isRequired: true,
                  isUploading: isUploadingFile,
                  uploadedUrl: contractsForms.employeeInfoFormUrl,
                  onPressed: () => onUpload('employee_info_form', (url) {
                    onChanged(_copy(employeeInfoFormUrl: url));
                  }),
                ),
                const SizedBox(height: 16),

                UploadFieldButton(
                  label: 'Confidentiality / NDA',
                  hint: 'Non-Disclosure Agreement (if applicable)',
                  isRequired: false,
                  isUploading: isUploadingFile,
                  uploadedUrl: contractsForms.ndaUrl,
                  onPressed: () => onUpload('nda', (url) {
                    onChanged(_copy(ndaUrl: url));
                  }),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Acknowledgements & Consents ──────────────────────────────
            FormSection(
              title: 'Acknowledgements & Consents',
              icon: Icons.fact_check_outlined,
              children: [
                // Code of Conduct
                _ConsentTile(
                  title: 'Code of Conduct',
                  subtitle:
                      'I have read and understood the company\'s code of conduct and agree to abide by it.',
                  value: contractsForms.codeOfConductAcknowledged,
                  onChanged: (v) {
                    onChanged(_copy(codeOfConductAcknowledged: v ?? false));
                  },
                ),
                const SizedBox(height: 12),

                // Data Protection Consent
                _ConsentTile(
                  title: 'Data Protection Consent',
                  subtitle:
                      'I consent to the processing of my personal data in accordance with the Kenya Data Protection Act, 2019.',
                  value: contractsForms.dataProtectionConsentGiven,
                  onChanged: (v) {
                    onChanged(_copy(
                      dataProtectionConsentGiven: v ?? false,
                      consentDate: (v ?? false) ? DateTime.now() : null,
                      clearConsentDate: !(v ?? false),
                    ));
                  },
                ),

                // Consent timestamp
                if (contractsForms.dataProtectionConsentGiven &&
                    contractsForms.consentDate != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: OnboardingColors.successSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: OnboardingColors.successBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: OnboardingColors.success, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Consent recorded: ${DateFormat('dd MMM yyyy, HH:mm').format(contractsForms.consentDate!)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: OnboardingColors.success,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Styled consent checkbox tile
// ─────────────────────────────────────────────────────────────────────────────
class _ConsentTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final void Function(bool?) onChanged;

  const _ConsentTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = value
        ? OnboardingColors.successSurface
        : Colors.grey.shade50;
    
    final borderColor = value
        ? OnboardingColors.successBorder
        : OnboardingColors.border;

    return AnimatedPhysicalModel(
      duration: const Duration(milliseconds: 200),
      shape: BoxShape.rectangle,
      elevation: 0,
      color: backgroundColor,
      shadowColor: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor,
            width: value ? 1.5 : 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: CheckboxListTile(
            value: value,
            onChanged: onChanged,
            activeColor: OnboardingColors.primary,
            checkColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            visualDensity: VisualDensity.compact,
            splashRadius: 20,
            title: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: value
                    ? OnboardingColors.success
                    : OnboardingColors.textPrimary,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: OnboardingColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          ),
        ),
      ),
    );
  }
}