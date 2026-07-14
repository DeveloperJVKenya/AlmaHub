import 'package:almahub/models/employee_onboarding_models.dart';
import 'package:almahub/screens/hr/onboarding_shared_widgets.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Step 1 — Personal Information
///
/// Receives the current [personalInfo] model and fires [onChanged] with the
/// updated model whenever the user edits any field.  Upload is delegated to
/// the parent wizard via [onUpload].
class Step1PersonalInfo extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final PersonalInformation personalInfo;
  final String? registeredUsername;
  final String? registeredEmail;
  final bool isUploadingFile;
  final void Function(PersonalInformation updated) onChanged;
  final Future<void> Function(
    String fieldName,
    void Function(String url) onSuccess,
  ) onUpload;

  const Step1PersonalInfo({
    super.key,
    required this.formKey,
    required this.personalInfo,
    this.registeredUsername,
    this.registeredEmail,
    required this.isUploadingFile,
    required this.onChanged,
    required this.onUpload,
  });

  // ── Convenience copy helper ──────────────────────────────────────────────
  PersonalInformation _copy({
    String? fullName,
    String? nationalIdOrPassport,
    String? idDocumentUrl,
    DateTime? dateOfBirth,
    bool clearDob = false,
    String? gender,
    String? phoneNumber,
    String? email,
    String? postalAddress,
    String? physicalAddress,
    NextOfKin? nextOfKin,
  }) {
    return PersonalInformation(
      fullName: fullName ?? personalInfo.fullName,
      nationalIdOrPassport:
          nationalIdOrPassport ?? personalInfo.nationalIdOrPassport,
      idDocumentUrl: idDocumentUrl ?? personalInfo.idDocumentUrl,
      dateOfBirth: clearDob ? null : (dateOfBirth ?? personalInfo.dateOfBirth),
      gender: gender ?? personalInfo.gender,
      phoneNumber: phoneNumber ?? personalInfo.phoneNumber,
      email: email ?? personalInfo.email,
      postalAddress: postalAddress ?? personalInfo.postalAddress,
      physicalAddress: physicalAddress ?? personalInfo.physicalAddress,
      nextOfKin: nextOfKin ?? personalInfo.nextOfKin,
    );
  }

  NextOfKin _copyKin({String? name, String? relationship, String? contact}) {
    return NextOfKin(
      name: name ?? personalInfo.nextOfKin.name,
      relationship: relationship ?? personalInfo.nextOfKin.relationship,
      contact: contact ?? personalInfo.nextOfKin.contact,
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
            // ── Header ──────────────────────────────────────────────────────
            const StepHeaderCard(
              icon: Icons.person_rounded,
              title: 'Personal Information',
              subtitle: 'Basic details, identity & next of kin',
            ),
            const SizedBox(height: 20),

            // ── Registered-user notice ───────────────────────────────────
            if (registeredUsername != null && registeredUsername!.isNotEmpty) ...[
              InfoBanner(
                message: 'Registered as: $registeredUsername',
                icon: Icons.verified_user_outlined,
              ),
              const SizedBox(height: 16),
            ],

            // ── Identity Details ─────────────────────────────────────────
            FormSection(
              title: 'Identity Details',
              icon: Icons.badge_outlined,
              children: [
                TextFormField(
                  initialValue: personalInfo.fullName,
                  decoration: onboardingInputDecoration('Full Name *'),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Full name is required' : null,
                  onChanged: (v) => onChanged(_copy(fullName: v)),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  initialValue: personalInfo.nationalIdOrPassport,
                  decoration:
                      onboardingInputDecoration('National ID / Passport Number *'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'ID / Passport is required' : null,
                  onChanged: (v) => onChanged(_copy(nationalIdOrPassport: v)),
                ),
                const SizedBox(height: 14),
                UploadFieldButton(
                  label: 'Upload ID / Passport Document',
                  hint: 'PDF, JPG or PNG · max 10 MB',
                  isRequired: true,
                  isUploading: isUploadingFile,
                  uploadedUrl: personalInfo.idDocumentUrl,
                  onPressed: () => onUpload('id_document', (url) {
                    onChanged(_copy(idDocumentUrl: url));
                  }),
                ),
                const SizedBox(height: 14),

                // ── Date of Birth ────────────────────────────────────────
                _DatePickerField(
                  label: 'Date of Birth *',
                  value: personalInfo.dateOfBirth,
                  firstDate: DateTime(1940),
                  lastDate: DateTime.now(),
                  onPicked: (d) => onChanged(_copy(dateOfBirth: d)),
                ),
                const SizedBox(height: 14),

                // ── Gender ───────────────────────────────────────────────
                DropdownButtonFormField<String>(
                  initialValue: personalInfo.gender.isEmpty ? null : personalInfo.gender,
                  decoration: onboardingInputDecoration('Gender *'),
                  items: ['Male', 'Female', 'Other']
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                  validator: (v) => v == null ? 'Gender is required' : null,
                  onChanged: (v) {
                    if (v != null) onChanged(_copy(gender: v));
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Contact Details ──────────────────────────────────────────
            FormSection(
              title: 'Contact Details',
              icon: Icons.contact_phone_outlined,
              children: [
                TextFormField(
                  initialValue: personalInfo.phoneNumber,
                  decoration: onboardingInputDecoration('Phone Number *'),
                  keyboardType: TextInputType.phone,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Phone number is required' : null,
                  onChanged: (v) => onChanged(_copy(phoneNumber: v)),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  initialValue: personalInfo.email.isNotEmpty
                      ? personalInfo.email
                      : registeredEmail ?? '',
                  decoration: onboardingInputDecoration(
                    'Email Address *',
                    suffixIcon: registeredEmail != null
                        ? const Tooltip(
                            message: 'Pre-filled from registration',
                            child: Icon(Icons.check_circle_rounded,
                                color: Color(0xFF16A34A), size: 20),
                          )
                        : null,
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email is required';
                    if (!v.contains('@')) return 'Enter a valid email address';
                    return null;
                  },
                  onChanged: (v) => onChanged(_copy(email: v)),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  initialValue: personalInfo.postalAddress,
                  decoration: onboardingInputDecoration('Postal Address *'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Postal address is required' : null,
                  onChanged: (v) => onChanged(_copy(postalAddress: v)),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  initialValue: personalInfo.physicalAddress,
                  decoration: onboardingInputDecoration('Physical / Residential Address *'),
                  maxLines: 2,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Physical address is required' : null,
                  onChanged: (v) => onChanged(_copy(physicalAddress: v)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Next of Kin ──────────────────────────────────────────────
            FormSection(
              title: 'Next of Kin',
              icon: Icons.family_restroom_rounded,
              children: [
                TextFormField(
                  initialValue: personalInfo.nextOfKin.name,
                  decoration: onboardingInputDecoration('Full Name *'),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Next of kin name is required' : null,
                  onChanged: (v) => onChanged(_copy(nextOfKin: _copyKin(name: v))),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  initialValue: personalInfo.nextOfKin.relationship,
                  decoration: onboardingInputDecoration('Relationship *'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Relationship is required' : null,
                  onChanged: (v) =>
                      onChanged(_copy(nextOfKin: _copyKin(relationship: v))),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  initialValue: personalInfo.nextOfKin.contact,
                  decoration: onboardingInputDecoration('Contact Number *'),
                  keyboardType: TextInputType.phone,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Contact number is required' : null,
                  onChanged: (v) =>
                      onChanged(_copy(nextOfKin: _copyKin(contact: v))),
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

// ─────────────────────────────────────────────────────────────────────────────
// Internal date-picker field widget
// ─────────────────────────────────────────────────────────────────────────────
class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final DateTime firstDate;
  final DateTime lastDate;
  final void Function(DateTime) onPicked;

  const _DatePickerField({
    required this.label,
    required this.value,
    required this.firstDate,
    required this.lastDate,
    required this.onPicked,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime(1990),
          firstDate: firstDate,
          lastDate: lastDate,
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.light(
                primary: OnboardingColors.primary,
              ),
            ),
            child: child!,
          ),
        );
        if (d != null) onPicked(d);
      },
      child: InputDecorator(
        decoration: onboardingInputDecoration(label),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              value != null
                  ? DateFormat('dd MMM yyyy').format(value!)
                  : 'Select date',
              style: TextStyle(
                fontSize: 14,
                color: value != null
                    ? OnboardingColors.textPrimary
                    : OnboardingColors.textHint,
              ),
            ),
            const Icon(Icons.calendar_today_rounded,
                size: 18, color: OnboardingColors.primary),
          ],
        ),
      ),
    );
  }
}