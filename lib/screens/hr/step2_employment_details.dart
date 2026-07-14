import 'package:almahub/models/employee_onboarding_models.dart';
import 'package:almahub/screens/hr/onboarding_shared_widgets.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Step 2 — Employment Details
class Step2EmploymentDetails extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final EmploymentDetails employmentDetails;
  final List<String> availableDepartments;
  final bool isLoadingDepartments;
  final void Function(EmploymentDetails updated) onChanged;
  final VoidCallback onRefreshDepartments;

  const Step2EmploymentDetails({
    super.key,
    required this.formKey,
    required this.employmentDetails,
    required this.availableDepartments,
    required this.isLoadingDepartments,
    required this.onChanged,
    required this.onRefreshDepartments,
  });

  EmploymentDetails _copy({
    String? jobTitle,
    String? department,
    String? employmentType,
    DateTime? startDate,
    String? workingHours,
    String? workLocation,
    String? supervisorName,
  }) {
    return EmploymentDetails(
      jobTitle: jobTitle ?? employmentDetails.jobTitle,
      department: department ?? employmentDetails.department,
      employmentType: employmentType ?? employmentDetails.employmentType,
      startDate: startDate ?? employmentDetails.startDate,
      workingHours: workingHours ?? employmentDetails.workingHours,
      workLocation: workLocation ?? employmentDetails.workLocation,
      supervisorName: supervisorName ?? employmentDetails.supervisorName,
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
              icon: Icons.work_outline_rounded,
              title: 'Employment Details',
              subtitle: 'Role, department & work arrangement',
            ),
            const SizedBox(height: 20),

            // ── Role & Department ────────────────────────────────────────
            FormSection(
              title: 'Role & Department',
              icon: Icons.business_center_outlined,
              children: [
                TextFormField(
                  initialValue: employmentDetails.jobTitle,
                  decoration: onboardingInputDecoration('Job Title *'),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Job title is required' : null,
                  onChanged: (v) => onChanged(_copy(jobTitle: v)),
                ),
                const SizedBox(height: 14),

                // Department dropdown
                if (isLoadingDepartments)
                  const _LoadingField(label: 'Loading departments…')
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: employmentDetails.department.isNotEmpty &&
                                availableDepartments
                                    .contains(employmentDetails.department)
                            ? employmentDetails.department
                            : null,
                        decoration: onboardingInputDecoration(
                          'Department *',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            color: OnboardingColors.primary,
                            tooltip: 'Refresh departments',
                            onPressed: onRefreshDepartments,
                          ),
                        ),
                        hint: Text(
                          availableDepartments.isEmpty
                              ? 'No departments available'
                              : 'Select department',
                          style: const TextStyle(
                              color: OnboardingColors.textHint, fontSize: 14),
                        ),
                        items: availableDepartments.isEmpty
                            ? null
                            : availableDepartments
                                .map((d) => DropdownMenuItem(
                                    value: d, child: Text(d)))
                                .toList(),
                        validator: (v) =>
                            v == null ? 'Department is required' : null,
                        onChanged: availableDepartments.isEmpty
                            ? null
                            : (v) {
                                if (v != null) {
                                  onChanged(_copy(department: v));
                                }
                              },
                      ),
                      if (availableDepartments.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: InfoBanner(
                            message:
                                'No departments found. Please contact your administrator.',
                            icon: Icons.warning_amber_rounded,
                            color: OnboardingColors.warning,
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 14),

                // Employment Type
                DropdownButtonFormField<String>(
                  initialValue: employmentDetails.employmentType.isEmpty
                      ? null
                      : employmentDetails.employmentType,
                  decoration: onboardingInputDecoration('Employment Type *'),
                  items: ['Permanent', 'Contract', 'Casual']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  validator: (v) =>
                      v == null ? 'Employment type is required' : null,
                  onChanged: (v) {
                    if (v != null) onChanged(_copy(employmentType: v));
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Schedule & Location ──────────────────────────────────────
            FormSection(
              title: 'Schedule & Location',
              icon: Icons.schedule_rounded,
              children: [
                // Start Date
                _DatePickerField(
                  label: 'Start Date *',
                  value: employmentDetails.startDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                  onPicked: (d) => onChanged(_copy(startDate: d)),
                ),
                const SizedBox(height: 14),

                TextFormField(
                  initialValue: employmentDetails.workingHours,
                  decoration: onboardingInputDecoration(
                      'Working Hours * (e.g. 8:00 AM – 5:00 PM)'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Working hours is required' : null,
                  onChanged: (v) => onChanged(_copy(workingHours: v)),
                ),
                const SizedBox(height: 14),

                TextFormField(
                  initialValue: employmentDetails.workLocation,
                  decoration: onboardingInputDecoration('Work Location *'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Work location is required' : null,
                  onChanged: (v) => onChanged(_copy(workLocation: v)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Reporting Line ───────────────────────────────────────────
            FormSection(
              title: 'Reporting Line',
              icon: Icons.account_tree_outlined,
              children: [
                TextFormField(
                  initialValue: employmentDetails.supervisorName,
                  decoration:
                      onboardingInputDecoration('Supervisor / Reporting Manager *'),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Supervisor name is required' : null,
                  onChanged: (v) => onChanged(_copy(supervisorName: v)),
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
// Loading placeholder field
// ─────────────────────────────────────────────────────────────────────────────
class _LoadingField extends StatelessWidget {
  final String label;
  const _LoadingField({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OnboardingColors.border),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              color: OnboardingColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal date picker field
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
          initialDate: value ?? DateTime.now(),
          firstDate: firstDate,
          lastDate: lastDate,
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.light(
                  primary: OnboardingColors.primary),
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