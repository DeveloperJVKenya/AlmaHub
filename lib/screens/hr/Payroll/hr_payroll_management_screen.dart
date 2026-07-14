import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';

import 'package:almahub/services/excel_generation_service.dart';
import 'package:almahub/services/excel_download_service.dart';

import 'payroll_adhoc_entry_dialog.dart';
import 'payroll_document_actions.dart';
import 'payroll_mark_paid_dialog.dart';
import 'payroll_models.dart';
import 'payroll_pdf_generator.dart';
import 'payroll_providers.dart';
import 'payroll_settings_dialog.dart';

const _brandPurple = Color.fromARGB(255, 86, 10, 119);

/// HR-facing payroll management screen: generate/recompute a monthly run,
/// review and edit each employee's computed record, approve the run, mark
/// employees paid, generate PDF payslips, and export the run to Excel.
class HRPayrollManagementScreen extends ConsumerStatefulWidget {
  const HRPayrollManagementScreen({super.key});

  @override
  ConsumerState<HRPayrollManagementScreen> createState() => _HRPayrollManagementScreenState();
}

class _HRPayrollManagementScreenState extends ConsumerState<HRPayrollManagementScreen> {
  bool _isBusy = false;
  String? _busyMessage;
  String _searchQuery = '';

  /// Filter for the pre-generation eligibility preview: 'all' | 'ready'
  /// (complete payroll details) | 'incomplete' (draft/missing fields).
  String _eligibilityFilter = 'all';

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

  @override
  Widget build(BuildContext context) {
    final month = ref.watch(selectedPayrollMonthProvider);
    final runAsync = ref.watch(payrollRunProvider);

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 225, 221, 226),
      appBar: AppBar(
        backgroundColor: _brandPurple,
        elevation: 2,
        title: const Text(
          'Payroll Management',
          style: TextStyle(fontWeight: FontWeight.w900, color: Color.fromARGB(255, 237, 236, 239), letterSpacing: 0.5),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month, color: Color.fromARGB(255, 242, 241, 243)),
            tooltip: 'Select Month',
            onPressed: _showMonthPickerDialog,
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Color.fromARGB(255, 242, 241, 243)),
            tooltip: 'Payroll Settings',
            onPressed: _openSettingsDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: runAsync.when(
        data: (run) => Column(
          children: [
            if (_isBusy) _buildBusyBanner(),
            _buildToolbar(run, month),
            _buildStatCards(run),
            Expanded(child: _buildRecordsTable(run)),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error loading payroll run: $e')),
      ),
    );
  }

  Widget _buildBusyBanner() {
    return Container(
      width: double.infinity,
      color: _brandPurple.withValues(alpha: 0.1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 12),
          Text(_busyMessage ?? 'Working…', style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildToolbar(PayrollRun? run, String month) {
    final monthLabel = DateFormat('MMMM yyyy').format(DateTime.parse('$month-01'));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(monthLabel, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _brandPurple)),
          if (run != null) _buildStatusChip(run.status),
          const Spacer(),
          SizedBox(
            width: 220,
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search employees…',
                prefixIcon: Icon(Icons.search, size: 20),
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
            ),
          ),
          ElevatedButton.icon(
            onPressed: _isBusy ? null : _generateRun,
            style: ElevatedButton.styleFrom(backgroundColor: _brandPurple, foregroundColor: Colors.white),
            icon: const Icon(Icons.calculate, size: 18),
            label: Text(run == null ? 'Generate Run' : 'Recompute Run'),
          ),
          if (run != null && run.isDraft)
            ElevatedButton.icon(
              onPressed: _isBusy ? null : () => _approveRun(run),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Approve Run'),
            ),
          if (run != null)
            OutlinedButton.icon(
              onPressed: _isBusy ? null : () => _bulkGeneratePayslips(run),
              icon: const Icon(Icons.picture_as_pdf, size: 18),
              label: const Text('Bulk Generate Payslips'),
            ),
          if (run != null)
            OutlinedButton.icon(
              onPressed: _isBusy ? null : () => _exportExcel(run),
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Export Excel'),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'approved':
        color = Colors.blue;
        break;
      case 'paid':
        color = Colors.green;
        break;
      default:
        color = Colors.orange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _buildStatCards(PayrollRun? run) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _statCard('Employees', '${run?.employeeCount ?? 0}', Icons.people, const Color.fromARGB(255, 209, 72, 221)),
            const SizedBox(width: 12),
            _statCard('Gross Pay', 'KES ${NumberFormat('#,###').format(run?.totalGrossPay ?? 0)}', Icons.payments,
                const Color.fromARGB(255, 46, 125, 50)),
            const SizedBox(width: 12),
            _statCard('Statutory Deductions', 'KES ${NumberFormat('#,###').format(run?.totalStatutoryDeductions ?? 0)}',
                Icons.account_balance, const Color.fromARGB(255, 211, 47, 47)),
            const SizedBox(width: 12),
            _statCard('Net Pay', 'KES ${NumberFormat('#,###').format(run?.totalNetPay ?? 0)}',
                Icons.account_balance_wallet, _brandPurple),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _brandPurple),
                    overflow: TextOverflow.ellipsis),
                Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordsTable(PayrollRun? run) {
    if (run == null) {
      return _buildEligibilityPreview();
    }

    final recordsAsync = ref.watch(payrollRecordsProvider(run.id));

    return Column(
      children: [
        _buildProcessedSkippedSummary(run),
        Expanded(
          child: recordsAsync.when(
            data: (records) {
              final filtered = _searchQuery.isEmpty
                  ? records
                  : records
                      .where((r) =>
                          r.employeeName.toLowerCase().contains(_searchQuery) ||
                          r.department.toLowerCase().contains(_searchQuery))
                      .toList();

              if (filtered.isEmpty) {
                return const Center(child: Text('No matching employees.', style: TextStyle(color: Colors.grey)));
              }

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 2))],
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                      headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _brandPurple),
                      dataTextStyle: const TextStyle(fontSize: 13, color: Colors.black87),
                      columnSpacing: 24,
                      columns: const [
                        DataColumn(label: Text('Employee')),
                        DataColumn(label: Text('Department')),
                        DataColumn(label: Text('Basic')),
                        DataColumn(label: Text('Allowances')),
                        DataColumn(label: Text('Overtime')),
                        DataColumn(label: Text('Statutory')),
                        DataColumn(label: Text('Other Deduc.')),
                        DataColumn(label: Text('Net Pay')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Payslip')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: filtered.map((r) => _buildRow(run, r)).toList(),
                    ),
                  ),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Error loading records: $e')),
          ),
        ),
      ],
    );
  }

  /// Pre-generation eligibility preview: shows EVERY `EmployeeDetails`
  /// record with a Ready/Incomplete status, so HR can see and fix data
  /// issues before generating a run instead of getting a mystery-empty run.
  Widget _buildEligibilityPreview() {
    final previewAsync = ref.watch(payrollEligibilityPreviewProvider);

    return previewAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error loading employees: $e')),
      data: (preview) {
        if (preview.isEmpty) {
          return const Center(child: Text('No employee records found.', style: TextStyle(color: Colors.grey)));
        }

        final statusFiltered = switch (_eligibilityFilter) {
          'ready' => preview.where((p) => p.isEligible).toList(),
          'incomplete' => preview.where((p) => !p.isEligible).toList(),
          _ => preview,
        };

        final filtered = _searchQuery.isEmpty
            ? statusFiltered
            : statusFiltered
                .where((p) =>
                    p.employeeName.toLowerCase().contains(_searchQuery) ||
                    p.department.toLowerCase().contains(_searchQuery))
                .toList();

        final readyCount = preview.where((p) => p.isEligible).length;

        return Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _brandPurple.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: _brandPurple, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$readyCount of ${preview.length} employees are ready for payroll. '
                      'Generating a run will process only the ready ones — the rest are listed below with the reason.',
                      style: const TextStyle(fontSize: 12, color: _brandPurple, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _eligibilityFilterChip('all', 'All (${preview.length})'),
                  const SizedBox(width: 8),
                  _eligibilityFilterChip('ready', 'Complete ($readyCount)'),
                  const SizedBox(width: 8),
                  _eligibilityFilterChip('incomplete', 'Draft / Incomplete (${preview.length - readyCount})'),
                ],
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No matching employees.', style: TextStyle(color: Colors.grey)))
                  : Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 2))],
                      ),
                      child: SingleChildScrollView(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                            headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _brandPurple),
                            dataTextStyle: const TextStyle(fontSize: 13, color: Colors.black87),
                            columnSpacing: 24,
                            columns: const [
                              DataColumn(label: Text('Employee')),
                              DataColumn(label: Text('Department')),
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('Reason')),
                            ],
                            rows: filtered
                                .map((p) => DataRow(cells: [
                                      DataCell(SizedBox(width: 150, child: Text(p.employeeName, overflow: TextOverflow.ellipsis))),
                                      DataCell(Text(p.department)),
                                      DataCell(_buildEligibilityBadge(p.isEligible)),
                                      DataCell(SizedBox(
                                        width: 260,
                                        child: Text(
                                          p.isEligible ? '—' : p.reason,
                                          style: TextStyle(color: p.isEligible ? Colors.grey.shade500 : Colors.red.shade700),
                                        ),
                                      )),
                                    ]))
                                .toList(),
                          ),
                        ),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: (_isBusy || readyCount == 0) ? null : _generateRun,
                style: ElevatedButton.styleFrom(backgroundColor: _brandPurple, foregroundColor: Colors.white),
                icon: const Icon(Icons.calculate),
                label: Text(readyCount == 0 ? 'No employees ready yet' : 'Generate Run ($readyCount employees)'),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _eligibilityFilterChip(String value, String label) {
    final isSelected = _eligibilityFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: _brandPurple.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: isSelected ? _brandPurple : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      onSelected: (_) => setState(() => _eligibilityFilter = value),
    );
  }

  Widget _buildEligibilityBadge(bool isEligible) {
    final color = isEligible ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(isEligible ? 'Ready' : 'Incomplete', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  /// Post-generation summary banner: how many were processed vs skipped,
  /// expandable to show each skipped employee and the specific reason.
  Widget _buildProcessedSkippedSummary(PayrollRun run) {
    if (run.skippedEmployees.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 18),
            const SizedBox(width: 8),
            Text('All ${run.employeeCount} eligible employees processed.', style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        leading: const Icon(Icons.warning_amber, color: Colors.orange),
        title: Text(
          '${run.employeeCount} processed, ${run.skippedEmployees.length} skipped',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.orange),
        ),
        subtitle: const Text('Tap to see which employees were skipped and why', style: TextStyle(fontSize: 11)),
        children: run.skippedEmployees
            .map((s) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.person_off_outlined, size: 18, color: Colors.orange),
                  title: Text(s.employeeName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Text(s.reason, style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
                ))
            .toList(),
      ),
    );
  }

  DataRow _buildRow(PayrollRun run, PayrollRecord r) {
    final currency = NumberFormat('#,###');
    return DataRow(cells: [
      DataCell(SizedBox(width: 150, child: Text(r.employeeName, overflow: TextOverflow.ellipsis))),
      DataCell(Text(r.department)),
      DataCell(Text('KES ${currency.format(r.basicSalary)}')),
      DataCell(Text('KES ${currency.format(r.totalAllowances)}')),
      DataCell(Text(r.overtimeHours > 0
          ? '${r.overtimeHours.toStringAsFixed(1)}h / KES ${currency.format(r.overtimePay)}'
          : '-')),
      DataCell(Text('KES ${currency.format(r.totalStatutoryDeductions)}',
          style: const TextStyle(color: Colors.red))),
      DataCell(Text('KES ${currency.format(r.totalOtherDeductions)}')),
      DataCell(Text('KES ${currency.format(r.netPay)}',
          style: const TextStyle(fontWeight: FontWeight.bold, color: _brandPurple))),
      DataCell(_buildRecordStatusBadge(r.status)),
      DataCell(
        r.hasPayslip
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  icon: const Icon(Icons.visibility, size: 18),
                  tooltip: 'View Payslip',
                  onPressed: () => PayrollDocumentActions.openPayslip(context, r),
                ),
                IconButton(
                  icon: const Icon(Icons.download, size: 18),
                  tooltip: 'Download Payslip',
                  onPressed: () => PayrollDocumentActions.downloadPayslip(context, r),
                ),
              ])
            : TextButton(
                onPressed: _isBusy ? null : () => _generateSinglePayslip(r),
                child: const Text('Generate'),
              ),
      ),
      DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
          icon: const Icon(Icons.edit, size: 18),
          tooltip: 'Edit Ad-hoc Entries',
          onPressed: run.isEditable
              ? () => showDialog(context: context, builder: (_) => PayrollAdhocEntryDialog(record: r))
              : null,
        ),
        IconButton(
          icon: const Icon(Icons.payments_outlined, size: 18),
          tooltip: 'Mark Paid',
          onPressed: (!r.isPaid && run.isApproved)
              ? () => showDialog(context: context, builder: (_) => PayrollMarkPaidDialog(record: r))
              : null,
        ),
      ])),
    ]);
  }

  Widget _buildRecordStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'approved':
        color = Colors.blue;
        break;
      case 'paid':
        color = Colors.green;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(status, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 11)),
    );
  }

  void _showMonthPickerDialog() {
    final months = List.generate(12, (i) {
      final now = DateTime.now();
      return DateTime(now.year, now.month - i, 1);
    });
    final currentMonth = ref.read(selectedPayrollMonthProvider);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.calendar_month, color: _brandPurple),
          SizedBox(width: 12),
          Text('Select Payroll Month'),
        ]),
        content: SizedBox(
          width: double.minPositive,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: months.length,
            itemBuilder: (context, index) {
              final month = months[index];
              final key = DateFormat('yyyy-MM').format(month);
              final isSelected = key == currentMonth;
              return ListTile(
                selected: isSelected,
                leading: Icon(isSelected ? Icons.check_circle : Icons.calendar_today,
                    color: isSelected ? _brandPurple : Colors.grey),
                title: Text(DateFormat('MMMM yyyy').format(month)),
                onTap: () {
                  ref.read(selectedPayrollMonthProvider.notifier).state = key;
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))],
      ),
    );
  }

  void _openSettingsDialog() async {
    final settings = await ref.read(payrollServiceProvider).getSettings();
    if (!mounted) return;
    showDialog(context: context, builder: (_) => PayrollSettingsDialog(settings: settings));
  }

  Future<void> _generateRun() async {
    final month = ref.read(selectedPayrollMonthProvider);
    setState(() {
      _isBusy = true;
      _busyMessage = 'Generating payroll run for $month…';
    });
    try {
      final run = await ref.read(payrollServiceProvider).generateRun(month);
      ref.invalidate(payrollEligibilityPreviewProvider);
      if (!mounted) return;
      final skippedCount = run.skippedEmployees.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            skippedCount == 0
                ? 'Payroll run generated for ${run.employeeCount} employees.'
                : 'Payroll run generated: ${run.employeeCount} processed, $skippedCount skipped (see summary below).',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      _logger.e('Error generating run', error: e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not generate run: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _approveRun(PayrollRun run) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Payroll Run?'),
        content: Text(
            'This locks the ${DateFormat('MMMM yyyy').format(DateTime.parse('${run.month}-01'))} run — records can no longer be edited. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _isBusy = true;
      _busyMessage = 'Approving run…';
    });
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final success = await ref.read(payrollServiceProvider).approveRun(run.id, uid);
    if (!mounted) return;
    setState(() => _isBusy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Run approved.' : 'Could not approve run.'),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _generateSinglePayslip(PayrollRecord record) async {
    setState(() {
      _isBusy = true;
      _busyMessage = 'Generating payslip for ${record.employeeName}…';
    });
    final url = await PayrollPdfGenerator.generateAndUpload(record, ref.read(payrollServiceProvider));
    if (!mounted) return;
    setState(() => _isBusy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(url != null ? 'Payslip generated.' : 'Could not generate payslip.'),
        backgroundColor: url != null ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _bulkGeneratePayslips(PayrollRun run) async {
    final records = await ref.read(payrollServiceProvider).getRecords(run.id);
    if (records.isEmpty) return;

    setState(() {
      _isBusy = true;
      _busyMessage = 'Generating 0/${records.length} payslips…';
    });

    await PayrollPdfGenerator.bulkGenerateForRun(
      records,
      ref.read(payrollServiceProvider),
      onProgress: (completed, total) {
        if (mounted) setState(() => _busyMessage = 'Generating $completed/$total payslips…');
      },
    );

    if (!mounted) return;
    setState(() => _isBusy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Generated payslips for ${records.length} employees.'), backgroundColor: Colors.green),
    );
  }

  Future<void> _exportExcel(PayrollRun run) async {
    setState(() {
      _isBusy = true;
      _busyMessage = 'Exporting to Excel…';
    });
    try {
      final records = await ref.read(payrollServiceProvider).getRecords(run.id);
      final result = await ExcelGenerationService.generatePayrollRunExcel(run, records);
      final fileBytes = result['fileBytes'];
      final fileName = result['fileName'] as String;
      final path = await ExcelDownloadService.downloadExcel(fileBytes, fileName);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(kIsWeb ? 'Payroll Excel downloaded: $fileName' : 'Payroll Excel saved to: $path'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _logger.e('Error exporting payroll Excel', error: e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }
}
