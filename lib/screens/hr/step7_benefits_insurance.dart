import 'package:almahub/screens/hr/employee_onboarding_models.dart';
import 'package:almahub/screens/hr/onboarding_shared_widgets.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Step 7 — Benefits & Insurance
class Step7BenefitsInsurance extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final BenefitsInsurance benefitsInsurance;
  final bool isUploadingFile;
  final void Function(BenefitsInsurance updated) onChanged;
  final Future<void> Function(
    String fieldName,
    void Function(String url) onSuccess,
  ) onUpload;

  const Step7BenefitsInsurance({
    super.key,
    required this.formKey,
    required this.benefitsInsurance,
    required this.isUploadingFile,
    required this.onChanged,
    required this.onUpload,
  });

  BenefitsInsurance _copy({
    List<Dependant>? nhifDependants,
    String? medicalInsuranceFormUrl,
    List<Beneficiary>? beneficiaries,
  }) {
    return BenefitsInsurance(
      nhifDependants:
          nhifDependants ?? benefitsInsurance.nhifDependants,
      medicalInsuranceFormUrl:
          medicalInsuranceFormUrl ?? benefitsInsurance.medicalInsuranceFormUrl,
      beneficiaries: beneficiaries ?? benefitsInsurance.beneficiaries,
    );
  }

  double get _totalPercentage => benefitsInsurance.beneficiaries
      .fold(0.0, (acc, b) => acc + b.percentage);

  // ── Add Dependant Dialog ──────────────────────────────────────────────────
  void _showAddDependantDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final relCtrl = TextEditingController();
    DateTime? dob;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.person_add_rounded, color: OnboardingColors.primary),
              SizedBox(width: 10),
              Text('Add NHIF Dependant',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: onboardingInputDecoration('Full Name *'),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: relCtrl,
                  decoration: onboardingInputDecoration(
                      'Relationship (e.g. Spouse, Child) *'),
                ),
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime(2000),
                      firstDate: DateTime(1940),
                      lastDate: DateTime.now(),
                      builder: (c, child) => Theme(
                        data: Theme.of(c).copyWith(
                            colorScheme: const ColorScheme.light(
                                primary: OnboardingColors.primary)),
                        child: child!,
                      ),
                    );
                    if (d != null) setDialogState(() => dob = d);
                  },
                  child: InputDecorator(
                    decoration: onboardingInputDecoration('Date of Birth'),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          dob != null
                              ? DateFormat('dd MMM yyyy').format(dob!)
                              : 'Optional – select date',
                          style: TextStyle(
                            color: dob != null
                                ? OnboardingColors.textPrimary
                                : OnboardingColors.textHint,
                            fontSize: 14,
                          ),
                        ),
                        const Icon(Icons.calendar_today_rounded,
                            size: 18, color: OnboardingColors.primary),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: OnboardingColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                if (nameCtrl.text.trim().isNotEmpty &&
                    relCtrl.text.trim().isNotEmpty) {
                  onChanged(_copy(
                    nhifDependants: [
                      ...benefitsInsurance.nhifDependants,
                      Dependant(
                        name: nameCtrl.text.trim(),
                        relationship: relCtrl.text.trim(),
                        dateOfBirth: dob,
                      ),
                    ],
                  ));
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Add Beneficiary Dialog ────────────────────────────────────────────────
  void _showAddBeneficiaryDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final relCtrl = TextEditingController();
    final contactCtrl = TextEditingController();
    final pctCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.account_circle_rounded, color: OnboardingColors.primary),
            SizedBox(width: 10),
            Text('Add Beneficiary',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: onboardingInputDecoration('Full Name *'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: relCtrl,
                decoration: onboardingInputDecoration('Relationship *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contactCtrl,
                decoration: onboardingInputDecoration('Contact Number *'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pctCtrl,
                decoration: onboardingInputDecoration('Percentage (%) *'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 8),
              Text(
                'Remaining: ${(100 - _totalPercentage).toStringAsFixed(0)}%',
                style: const TextStyle(
                    fontSize: 12, color: OnboardingColors.textSecondary),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: OnboardingColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty ||
                  relCtrl.text.trim().isEmpty ||
                  contactCtrl.text.trim().isEmpty ||
                  pctCtrl.text.trim().isEmpty) {
                return;
              }

              final pct = double.tryParse(pctCtrl.text) ?? 0;
              if (_totalPercentage + pct > 100) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Total percentage cannot exceed 100%'),
                  backgroundColor: OnboardingColors.warning,
                ));
                return;
              }

              onChanged(_copy(
                beneficiaries: [
                  ...benefitsInsurance.beneficiaries,
                  Beneficiary(
                    name: nameCtrl.text.trim(),
                    relationship: relCtrl.text.trim(),
                    contact: contactCtrl.text.trim(),
                    percentage: pct,
                  ),
                ],
              ));
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
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
              icon: Icons.favorite_rounded,
              title: 'Benefits & Insurance',
              subtitle: 'NHIF dependants, medical cover & beneficiaries',
            ),
            const SizedBox(height: 20),

            // ── NHIF Dependants ──────────────────────────────────────────
            FormSection(
              title: 'NHIF Dependants',
              icon: Icons.family_restroom_rounded,
              children: [
                if (benefitsInsurance.nhifDependants.isEmpty)
                  const InfoBanner(
                    message: 'No dependants added yet. Tap below to add.',
                    icon: Icons.info_outline_rounded,
                  )
                else ...[
                  ...benefitsInsurance.nhifDependants.asMap().entries.map((e) {
                    final d = e.value;
                    return _DependantTile(
                      name: d.name,
                      relationship: d.relationship,
                      dateOfBirth: d.dateOfBirth,
                      onDelete: () {
                        final updated = List<Dependant>.from(
                            benefitsInsurance.nhifDependants)
                          ..removeAt(e.key);
                        onChanged(_copy(nhifDependants: updated));
                      },
                    );
                  }),
                  const SizedBox(height: 8),
                ],
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showAddDependantDialog(context),
                    icon: const Icon(Icons.add_rounded,
                        color: OnboardingColors.primary),
                    label: const Text(
                      'Add NHIF Dependant',
                      style: TextStyle(
                          color: OnboardingColors.primary,
                          fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(
                          color: OnboardingColors.primary, width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Medical Insurance ────────────────────────────────────────
            FormSection(
              title: 'Medical Insurance',
              icon: Icons.health_and_safety_rounded,
              children: [
                UploadFieldButton(
                  label: 'Medical Insurance Enrolment Form',
                  hint: 'Upload the completed medical insurance enrolment form',
                  isRequired: false,
                  isUploading: isUploadingFile,
                  uploadedUrl: benefitsInsurance.medicalInsuranceFormUrl,
                  onPressed: () => onUpload('medical_insurance', (url) {
                    onChanged(_copy(medicalInsuranceFormUrl: url));
                  }),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Beneficiaries ────────────────────────────────────────────
            FormSection(
              title: 'Beneficiaries',
              icon: Icons.account_circle_outlined,
              children: [
                // Percentage progress bar
                if (benefitsInsurance.beneficiaries.isNotEmpty) ...[
                  _PercentageBar(total: _totalPercentage),
                  const SizedBox(height: 12),
                ],

                if (benefitsInsurance.beneficiaries.isEmpty)
                  const InfoBanner(
                    message: 'No beneficiaries added yet. Allocate 100% total.',
                    icon: Icons.info_outline_rounded,
                  )
                else ...[
                  ...benefitsInsurance.beneficiaries.asMap().entries.map((e) {
                    final b = e.value;
                    return _BeneficiaryTile(
                      name: b.name,
                      relationship: b.relationship,
                      contact: b.contact,
                      percentage: b.percentage,
                      onDelete: () {
                        final updated = List<Beneficiary>.from(
                            benefitsInsurance.beneficiaries)
                          ..removeAt(e.key);
                        onChanged(_copy(beneficiaries: updated));
                      },
                    );
                  }),
                  const SizedBox(height: 8),
                ],

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _totalPercentage >= 100
                        ? null
                        : () => _showAddBeneficiaryDialog(context),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text(
                      'Add Beneficiary',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      foregroundColor: OnboardingColors.primary,
                      side: const BorderSide(
                          color: OnboardingColors.primary, width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
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
// Dependant tile
// ─────────────────────────────────────────────────────────────────────────────
class _DependantTile extends StatelessWidget {
  final String name;
  final String relationship;
  final DateTime? dateOfBirth;
  final VoidCallback onDelete;

  const _DependantTile({
    required this.name,
    required this.relationship,
    this.dateOfBirth,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: OnboardingColors.primarySurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OnboardingColors.primaryBorder),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: OnboardingColors.primary,
          radius: 20,
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(name,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: OnboardingColors.textPrimary)),
        subtitle: Text(
          dateOfBirth != null
              ? '$relationship · ${DateFormat('dd MMM yyyy').format(dateOfBirth!)}'
              : relationship,
          style: const TextStyle(
              fontSize: 12, color: OnboardingColors.textSecondary),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline_rounded,
              color: Colors.red, size: 20),
          onPressed: onDelete,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Beneficiary tile
// ─────────────────────────────────────────────────────────────────────────────
class _BeneficiaryTile extends StatelessWidget {
  final String name;
  final String relationship;
  final String contact;
  final double percentage;
  final VoidCallback onDelete;

  const _BeneficiaryTile({
    required this.name,
    required this.relationship,
    required this.contact,
    required this.percentage,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF1D4ED8),
          radius: 20,
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(name,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: OnboardingColors.textPrimary)),
        subtitle: Text(
          '$relationship · $contact',
          style: const TextStyle(
              fontSize: 12, color: OnboardingColors.textSecondary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1D4ED8).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${percentage.toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1D4ED8),
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: Colors.red, size: 20),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Percentage progress bar
// ─────────────────────────────────────────────────────────────────────────────
class _PercentageBar extends StatelessWidget {
  final double total;
  const _PercentageBar({required this.total});

  @override
  Widget build(BuildContext context) {
    final isComplete = total >= 100;
    final color = isComplete ? OnboardingColors.success : OnboardingColors.warning;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Total Allocation',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: OnboardingColors.textSecondary),
            ),
            Text(
              '${total.toStringAsFixed(0)}% / 100%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (total / 100).clamp(0.0, 1.0),
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
        if (isComplete) ...[
          const SizedBox(height: 4),
          const Text(
            '✓ 100% allocated',
            style: TextStyle(
                fontSize: 11,
                color: OnboardingColors.success,
                fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }
}