import 'package:almahub/models/employee_onboarding_models.dart';
import 'package:almahub/screens/hr/onboarding_shared_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Step 4 — Payroll & Payment Details
///
/// Covers:
///   • Basic Salary
///   • Allowances   (Housing, Transport, Other)
///   • Deductions   (Loans, SACCO, Advances, Other)
///   • Bank Details (Bank Name, Branch, Account Name, Account Number)
///
/// M-Pesa section has been removed as per requirements.
class Step4PayrollDetails extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final PayrollDetails payrollDetails;
  final void Function(PayrollDetails updated) onChanged;

  const Step4PayrollDetails({
    super.key,
    required this.formKey,
    required this.payrollDetails,
    required this.onChanged,
  });

  // ── Copy helpers ────────────────────────────────────────────────────────────
  PayrollDetails _copy({
    double? basicSalary,
    Map<String, double>? allowances,
    Map<String, double>? deductions,
    BankDetails? bankDetails,
  }) {
    return PayrollDetails(
      basicSalary: basicSalary ?? payrollDetails.basicSalary,
      allowances: allowances ?? payrollDetails.allowances,
      deductions: deductions ?? payrollDetails.deductions,
      bankDetails: bankDetails ?? payrollDetails.bankDetails,
      // mpesaDetails intentionally omitted / null — removed from UI
    );
  }

  BankDetails _copyBank({
    String? bankName,
    String? branchName,
    String? accountName,
    String? accountNumber,
  }) {
    return BankDetails(
      bankName: bankName ?? payrollDetails.bankDetails.bankName,
      branchName: branchName ?? payrollDetails.bankDetails.branchName,
      accountName: accountName ?? payrollDetails.bankDetails.accountName,
      accountNumber: accountNumber ?? payrollDetails.bankDetails.accountNumber,
    );
  }

  Map<String, double> _updateMap(
    Map<String, double> source,
    String key,
    String rawValue,
  ) {
    final updated = Map<String, double>.from(source);
    final amount = double.tryParse(rawValue) ?? 0;
    if (amount > 0) {
      updated[key] = amount;
    } else {
      updated.remove(key);
    }
    return updated;
  }

  // ── Salary summary chip ─────────────────────────────────────────────────────
  Widget _buildSalaryChip(String label, double value, Color color) {
    if (value <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Text(
        '$label: KES ${value.toStringAsFixed(0)}',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  // ── Gross / Net summary ─────────────────────────────────────────────────────
  Widget _buildSalarySummary() {
    final totalAllowances =
        payrollDetails.allowances.values.fold(0.0, (a, b) => a + b);
    final totalDeductions =
        payrollDetails.deductions.values.fold(0.0, (a, b) => a + b);
    final gross = payrollDetails.basicSalary + totalAllowances;
    final net = gross - totalDeductions;

    if (payrollDetails.basicSalary <= 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF540478), Color(0xFF7B2FBE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF540478).withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.calculate_rounded, color: Colors.white70, size: 18),
              SizedBox(width: 8),
              Text(
                'Salary Summary',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SummaryItem(
                  label: 'Basic',
                  value: payrollDetails.basicSalary,
                  color: Colors.white,
                ),
              ),
              if (totalAllowances > 0) ...[
                const _Divider(),
                Expanded(
                  child: _SummaryItem(
                    label: 'Allowances',
                    value: totalAllowances,
                    color: Colors.greenAccent.shade100,
                  ),
                ),
              ],
              if (totalDeductions > 0) ...[
                const _Divider(),
                Expanded(
                  child: _SummaryItem(
                    label: 'Deductions',
                    value: totalDeductions,
                    color: Colors.redAccent.shade100,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Estimated Net Pay',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'KES ${net.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
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
            // ── Header ────────────────────────────────────────────────────
            const StepHeaderCard(
              icon: Icons.account_balance_wallet_rounded,
              title: 'Payroll & Payment Details',
              subtitle: 'Salary, allowances, deductions & bank information',
            ),
            const SizedBox(height: 20),

            // ── Live salary summary ───────────────────────────────────────
            _buildSalarySummary(),
            if (payrollDetails.basicSalary > 0) const SizedBox(height: 16),

            // ── Basic Salary ──────────────────────────────────────────────
            FormSection(
              title: 'Basic Salary',
              icon: Icons.payments_outlined,
              children: [
                TextFormField(
                  initialValue: payrollDetails.basicSalary > 0
                      ? payrollDetails.basicSalary.toStringAsFixed(0)
                      : '',
                  decoration: onboardingInputDecoration(
                    'Basic Salary (KES) *',
                    suffixIcon: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                      child: Text(
                        'KES',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: OnboardingColors.primary,
                        ),
                      ),
                    ),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Basic salary is required';
                    }
                    if (double.tryParse(v) == null || double.parse(v) <= 0) {
                      return 'Enter a valid salary amount';
                    }
                    return null;
                  },
                  onChanged: (v) => onChanged(
                    _copy(basicSalary: double.tryParse(v) ?? 0),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Allowances ────────────────────────────────────────────────
            FormSection(
              title: 'Allowances',
              icon: Icons.add_circle_outline_rounded,
              iconColor: const Color(0xFF16A34A),
              children: [
                const SubSectionLabel(
                  'Enter applicable allowances (leave blank if not applicable)',
                ),
                const SizedBox(height: 14),
                _AllowanceField(
                  label: 'Housing Allowance (KES)',
                  initialValue:
                      payrollDetails.allowances['housing']?.toStringAsFixed(0),
                  onChanged: (v) => onChanged(
                    _copy(
                      allowances:
                          _updateMap(payrollDetails.allowances, 'housing', v),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _AllowanceField(
                  label: 'Transport Allowance (KES)',
                  initialValue:
                      payrollDetails.allowances['transport']?.toStringAsFixed(0),
                  onChanged: (v) => onChanged(
                    _copy(
                      allowances:
                          _updateMap(payrollDetails.allowances, 'transport', v),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _AllowanceField(
                  label: 'Other Allowances (KES)',
                  initialValue:
                      payrollDetails.allowances['other']?.toStringAsFixed(0),
                  onChanged: (v) => onChanged(
                    _copy(
                      allowances:
                          _updateMap(payrollDetails.allowances, 'other', v),
                    ),
                  ),
                ),
                // Summary chips
                if (payrollDetails.allowances.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: payrollDetails.allowances.entries
                        .where((e) => e.value > 0)
                        .map((e) => _buildSalaryChip(
                              e.key[0].toUpperCase() + e.key.substring(1),
                              e.value,
                              const Color(0xFF16A34A),
                            ))
                        .toList(),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // ── Deductions ────────────────────────────────────────────────
            FormSection(
              title: 'Deductions',
              icon: Icons.remove_circle_outline_rounded,
              iconColor: const Color(0xFFDC2626),
              children: [
                const SubSectionLabel(
                  'Enter applicable deductions (leave blank if not applicable)',
                ),
                const SizedBox(height: 14),
                _AllowanceField(
                  label: 'Loans (KES)',
                  initialValue:
                      payrollDetails.deductions['loans']?.toStringAsFixed(0),
                  onChanged: (v) => onChanged(
                    _copy(
                      deductions:
                          _updateMap(payrollDetails.deductions, 'loans', v),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _AllowanceField(
                  label: 'SACCO Deductions (KES)',
                  initialValue:
                      payrollDetails.deductions['sacco']?.toStringAsFixed(0),
                  onChanged: (v) => onChanged(
                    _copy(
                      deductions:
                          _updateMap(payrollDetails.deductions, 'sacco', v),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _AllowanceField(
                  label: 'Advances (KES)',
                  initialValue:
                      payrollDetails.deductions['advances']?.toStringAsFixed(0),
                  onChanged: (v) => onChanged(
                    _copy(
                      deductions:
                          _updateMap(payrollDetails.deductions, 'advances', v),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _AllowanceField(
                  label: 'Other Deductions (KES)',
                  initialValue:
                      payrollDetails.deductions['other']?.toStringAsFixed(0),
                  onChanged: (v) => onChanged(
                    _copy(
                      deductions:
                          _updateMap(payrollDetails.deductions, 'other', v),
                    ),
                  ),
                ),
                // Summary chips
                if (payrollDetails.deductions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: payrollDetails.deductions.entries
                        .where((e) => e.value > 0)
                        .map((e) => _buildSalaryChip(
                              e.key[0].toUpperCase() + e.key.substring(1),
                              e.value,
                              const Color(0xFFDC2626),
                            ))
                        .toList(),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // ── Bank Details ──────────────────────────────────────────────
            FormSection(
              title: 'Bank Details',
              icon: Icons.account_balance_outlined,
              children: [
                InfoBanner(
                  message:
                      'Salary will be disbursed to the bank account below. Ensure the details are accurate.',
                  icon: Icons.info_outline_rounded,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  initialValue: payrollDetails.bankDetails.bankName,
                  decoration: onboardingInputDecoration('Bank Name *'),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Bank name is required' : null,
                  onChanged: (v) =>
                      onChanged(_copy(bankDetails: _copyBank(bankName: v))),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  initialValue: payrollDetails.bankDetails.branchName,
                  decoration: onboardingInputDecoration('Branch Name *'),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Branch name is required'
                      : null,
                  onChanged: (v) =>
                      onChanged(_copy(bankDetails: _copyBank(branchName: v))),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  initialValue: payrollDetails.bankDetails.accountName,
                  decoration: onboardingInputDecoration('Account Name *'),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Account name is required'
                      : null,
                  onChanged: (v) =>
                      onChanged(_copy(bankDetails: _copyBank(accountName: v))),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  initialValue: payrollDetails.bankDetails.accountNumber,
                  decoration: onboardingInputDecoration('Account Number *'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Account number is required'
                      : null,
                  onChanged: (v) =>
                      onChanged(_copy(bankDetails: _copyBank(accountNumber: v))),
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
// Reusable numeric input for allowances / deductions
// ─────────────────────────────────────────────────────────────────────────────
class _AllowanceField extends StatelessWidget {
  final String label;
  final String? initialValue;
  final void Function(String) onChanged;

  const _AllowanceField({
    required this.label,
    this.initialValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initialValue ?? '',
      decoration: onboardingInputDecoration(label),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      onChanged: onChanged,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Summary card sub-widgets
// ─────────────────────────────────────────────────────────────────────────────
class _SummaryItem extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color.withValues(alpha: 0.75),
            fontSize: 10,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'KES ${value.toStringAsFixed(0)}',
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: Colors.white.withValues(alpha: 0.25),
    );
  }
}