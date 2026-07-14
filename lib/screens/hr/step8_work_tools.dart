import 'package:almahub/models/employee_onboarding_models.dart';
import 'package:almahub/screens/hr/onboarding_shared_widgets.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Step 8 — Work Tools & System Access
///
/// Captured by HR/IT to track what has been provisioned for the new employee:
///   • Work e-mail address
///   • HRIS / Payroll system profile status
///   • Internal system access status
///   • Issued equipment (laptops, phones, PPE, etc.)
class Step8WorkTools extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final WorkToolsAccess workTools;
  final void Function(WorkToolsAccess updated) onChanged;

  const Step8WorkTools({
    super.key,
    required this.formKey,
    required this.workTools,
    required this.onChanged,
  });

  // ── Copy helper ────────────────────────────────────────────────────────────
  WorkToolsAccess _copy({
    String? workEmail,
    bool? hrisProfileCreated,
    bool? systemAccessGranted,
    List<IssuedEquipment>? issuedEquipment,
  }) {
    return WorkToolsAccess(
      workEmail: workEmail ?? workTools.workEmail,
      hrisProfileCreated: hrisProfileCreated ?? workTools.hrisProfileCreated,
      systemAccessGranted: systemAccessGranted ?? workTools.systemAccessGranted,
      issuedEquipment: issuedEquipment ?? workTools.issuedEquipment,
    );
  }

  // ── Add Equipment dialog ───────────────────────────────────────────────────
  void _showAddEquipmentDialog(BuildContext context) {
    final itemNameCtrl = TextEditingController();
    final serialCtrl = TextEditingController();
    DateTime? issuedDate;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.devices_rounded, color: OnboardingColors.primary),
              SizedBox(width: 10),
              Text(
                'Add Issued Equipment',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Item Name
                TextField(
                  controller: itemNameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: onboardingInputDecoration(
                      'Item Name (e.g. Laptop, Phone, PPE)'),
                ),
                const SizedBox(height: 14),

                // Serial Number
                TextField(
                  controller: serialCtrl,
                  decoration: onboardingInputDecoration('Serial Number'),
                ),
                const SizedBox(height: 14),

                // Issue Date
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      builder: (c, child) => Theme(
                        data: Theme.of(c).copyWith(
                          colorScheme: const ColorScheme.light(
                              primary: OnboardingColors.primary),
                        ),
                        child: child!,
                      ),
                    );
                    if (d != null) setDialogState(() => issuedDate = d);
                  },
                  child: InputDecorator(
                    decoration: onboardingInputDecoration('Issue Date'),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          issuedDate != null
                              ? DateFormat('dd MMM yyyy').format(issuedDate!)
                              : 'Select date',
                          style: TextStyle(
                            fontSize: 14,
                            color: issuedDate != null
                                ? OnboardingColors.textPrimary
                                : OnboardingColors.textHint,
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
            ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
              style: ElevatedButton.styleFrom(
                backgroundColor: OnboardingColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                if (itemNameCtrl.text.trim().isEmpty ||
                    serialCtrl.text.trim().isEmpty) {
                  return;
                }
                onChanged(_copy(
                  issuedEquipment: [
                    ...workTools.issuedEquipment,
                    IssuedEquipment(
                      itemName: itemNameCtrl.text.trim(),
                      serialNumber: serialCtrl.text.trim(),
                      issuedDate: issuedDate,
                    ),
                  ],
                ));
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
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
            // ── Header ────────────────────────────────────────────────────
            const StepHeaderCard(
              icon: Icons.computer_rounded,
              title: 'Work Tools & System Access',
              subtitle: 'Email provisioning, system access & issued equipment',
            ),
            const SizedBox(height: 20),

            // ── Work Email ────────────────────────────────────────────────
            FormSection(
              title: 'Work Email',
              icon: Icons.email_outlined,
              children: [
                InfoBanner(
                  message:
                      'Work email is provisioned by IT. Enter the address once created.',
                  icon: Icons.info_outline_rounded,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  initialValue: workTools.workEmail,
                  decoration: onboardingInputDecoration('Work Email Address'),
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (v) => onChanged(_copy(workEmail: v)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── System Access ─────────────────────────────────────────────
            FormSection(
              title: 'System Access & Profiles',
              icon: Icons.admin_panel_settings_outlined,
              children: [
                _SwitchTile(
                  icon: Icons.manage_accounts_rounded,
                  title: 'HRIS / Payroll Profile Created',
                  subtitle:
                      'Employee profile set up in the HR information system',
                  value: workTools.hrisProfileCreated,
                  onChanged: (v) =>
                      onChanged(_copy(hrisProfileCreated: v)),
                ),
                const SizedBox(height: 12),
                _SwitchTile(
                  icon: Icons.lock_open_rounded,
                  title: 'Internal System Access Granted',
                  subtitle:
                      'Access to required internal platforms and tools confirmed',
                  value: workTools.systemAccessGranted,
                  onChanged: (v) =>
                      onChanged(_copy(systemAccessGranted: v)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Issued Equipment ──────────────────────────────────────────
            FormSection(
              title: 'Issued Equipment',
              icon: Icons.devices_rounded,
              children: [
                const SubSectionLabel(
                  'Record all items issued to the employee',
                  hint: 'e.g. Laptop, Mobile Phone, Access Card, PPE, Uniform',
                ),
                const SizedBox(height: 14),

                // Equipment list
                if (workTools.issuedEquipment.isNotEmpty) ...[
                  ...workTools.issuedEquipment.asMap().entries.map((e) {
                    final eq = e.value;
                    return _EquipmentTile(
                      equipment: eq,
                      onDelete: () {
                        final updated =
                            List<IssuedEquipment>.from(workTools.issuedEquipment)
                              ..removeAt(e.key);
                        onChanged(_copy(issuedEquipment: updated));
                      },
                    );
                  }),
                  const SizedBox(height: 8),
                ],

                // Add Equipment button
                AddDocumentButton(
                  label: 'Add Issued Equipment',
                  isUploading: false,
                  onPressed: () => _showAddEquipmentDialog(context),
                ),

                // Count badge
                if (workTools.issuedEquipment.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _CountBadge(
                    count: workTools.issuedEquipment.length,
                    label: 'item(s) issued',
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),

            // ── Completion notice ─────────────────────────────────────────
            InfoBanner(
              message:
                  'This is the final step. Review all sections before submitting.',
              icon: Icons.check_circle_outline_rounded,
              color: OnboardingColors.success,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Styled toggle switch tile
// ─────────────────────────────────────────────────────────────────────────────
class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final void Function(bool) onChanged;

  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: value
            ? OnboardingColors.successSurface
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value
              ? OnboardingColors.successBorder
              : OnboardingColors.border,
          width: value ? 1.5 : 1,
        ),
      ),
      child: SwitchListTile(
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: value
                ? OnboardingColors.success.withValues(alpha: 0.12)
                : Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: value
                ? OnboardingColors.success
                : OnboardingColors.textSecondary,
          ),
        ),
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
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            color: OnboardingColors.textSecondary,
            height: 1.4,
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeThumbColor: OnboardingColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Equipment list tile
// ─────────────────────────────────────────────────────────────────────────────
class _EquipmentTile extends StatelessWidget {
  final IssuedEquipment equipment;
  final VoidCallback onDelete;

  const _EquipmentTile({
    required this.equipment,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: OnboardingColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OnboardingColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: OnboardingColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.devices_rounded,
            size: 20,
            color: OnboardingColors.primary,
          ),
        ),
        title: Text(
          equipment.itemName,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: OnboardingColors.textPrimary,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'S/N: ${equipment.serialNumber}',
              style: const TextStyle(
                  fontSize: 12, color: OnboardingColors.textSecondary),
            ),
            if (equipment.issuedDate != null)
              Text(
                'Issued: ${DateFormat('dd MMM yyyy').format(equipment.issuedDate!)}',
                style: const TextStyle(
                    fontSize: 12, color: OnboardingColors.textSecondary),
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline_rounded,
              color: OnboardingColors.error, size: 20),
          tooltip: 'Remove',
          onPressed: onDelete,
        ),
        isThreeLine: equipment.issuedDate != null,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Count badge
// ─────────────────────────────────────────────────────────────────────────────
class _CountBadge extends StatelessWidget {
  final int count;
  final String label;

  const _CountBadge({required this.count, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: OnboardingColors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: OnboardingColors.primary.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded,
                  size: 14, color: OnboardingColors.primary),
              const SizedBox(width: 6),
              Text(
                '$count $label',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: OnboardingColors.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}