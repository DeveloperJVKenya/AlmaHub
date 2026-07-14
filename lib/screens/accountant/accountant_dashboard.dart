import 'package:almahub/screens/hr/Payroll/payroll_document_actions.dart';
import 'package:almahub/screens/hr/Payroll/payroll_models.dart';
import 'package:almahub/screens/hr/Payroll/payroll_service.dart';
import 'package:almahub/services/excel_download_service.dart';
import 'package:almahub/services/excel_generation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

const _brandPurple = Color.fromARGB(255, 86, 10, 119);

/// Read-only payroll report for the Accountant role. Payroll creation,
/// editing, approval and payment now live in the HR Payroll module
/// (lib/screens/hr/Payroll/) — Accountant only reviews the same
/// HR-generated runs and can export them to Excel. No write actions are
/// ever rendered here.
class AccountantDashboard extends StatefulWidget {
  const AccountantDashboard({super.key});

  @override
  State<AccountantDashboard> createState() => _AccountantDashboardState();
}

class _AccountantDashboardState extends State<AccountantDashboard> {
  final PayrollService _payrollService = PayrollService();
  DateTime _selectedMonth = DateTime.now();
  String _searchQuery = '';
  bool _isDownloading = false;

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

  String get _monthKey => DateFormat('yyyy-MM').format(_selectedMonth);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 225, 221, 226),
      appBar: AppBar(
        backgroundColor: _brandPurple,
        elevation: 2,
        title: const Text(
          'Accountant Dashboard — Payroll Reports',
          style: TextStyle(fontWeight: FontWeight.w900, color: Color.fromARGB(255, 237, 236, 239), letterSpacing: 0.5),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month, color: Color.fromARGB(255, 242, 241, 243)),
            onPressed: _showMonthPickerDialog,
            tooltip: 'Select Month',
          ),
          IconButton(
            icon: const Icon(Icons.search, color: Color.fromARGB(255, 242, 241, 243)),
            onPressed: _showSearchDialog,
            tooltip: 'Search Employees',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<PayrollRun?>(
        stream: _payrollService.runStream(_monthKey),
        builder: (context, runSnapshot) {
          final run = runSnapshot.data;
          return Column(
            children: [
              _buildBanner(),
              _buildHeaderCard(run),
              Expanded(child: _buildRecordsList(run)),
            ],
          );
        },
      ),
      floatingActionButton: StreamBuilder<PayrollRun?>(
        stream: _payrollService.runStream(_monthKey),
        builder: (context, snapshot) {
          if (snapshot.data == null) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: _isDownloading ? null : () => _downloadExcel(snapshot.data!),
            backgroundColor: _isDownloading ? Colors.grey.shade400 : _brandPurple,
            foregroundColor: Colors.white,
            icon: _isDownloading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                  )
                : const Icon(Icons.download_rounded),
            label: Text(_isDownloading ? 'Generating...' : 'Export Excel'),
          );
        },
      ),
    );
  }

  Widget _buildBanner() {
    return Container(
      width: double.infinity,
      color: Colors.orange.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: const Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: Colors.orange),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Read-only view. Payroll runs are generated and managed by HR.',
              style: TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(PayrollRun? run) {
    final monthLabel = DateFormat('MMMM yyyy').format(_selectedMonth);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _statCard('Period', monthLabel, Icons.calendar_today, Colors.blue),
            const SizedBox(width: 12),
            _statCard('Status', run?.status.toUpperCase() ?? 'NOT GENERATED', Icons.flag,
                run == null ? Colors.grey : _brandPurple),
            const SizedBox(width: 12),
            _statCard('Employees', '${run?.employeeCount ?? 0}', Icons.people, const Color.fromARGB(255, 209, 72, 221)),
            const SizedBox(width: 12),
            _statCard('Gross Pay', 'KES ${NumberFormat('#,###').format(run?.totalGrossPay ?? 0)}', Icons.payments,
                const Color.fromARGB(255, 46, 125, 50)),
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
      width: 200,
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
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _brandPurple),
                    overflow: TextOverflow.ellipsis),
                Text(title, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordsList(PayrollRun? run) {
    if (run == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('No payroll run for ${DateFormat('MMMM yyyy').format(_selectedMonth)} yet.',
                style: const TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 8),
            const Text('Ask HR to generate this month\'s payroll run.', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return StreamBuilder<List<PayrollRecord>>(
      stream: _payrollService.recordsStream(run.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final allRecords = snapshot.data ?? [];
        final records = _searchQuery.isEmpty
            ? allRecords
            : allRecords
                .where((r) =>
                    r.employeeName.toLowerCase().contains(_searchQuery) ||
                    r.department.toLowerCase().contains(_searchQuery) ||
                    (r.bankDetails?['accountNumber']?.toString().toLowerCase().contains(_searchQuery) ?? false))
                .toList();

        if (records.isEmpty) {
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
                  DataColumn(label: Text('Basic Salary')),
                  DataColumn(label: Text('Allowances')),
                  DataColumn(label: Text('Overtime')),
                  DataColumn(label: Text('Statutory Deduc.')),
                  DataColumn(label: Text('Other Deduc.')),
                  DataColumn(label: Text('Net Pay')),
                  DataColumn(label: Text('Bank')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Payslip')),
                ],
                rows: records.map(_buildRow).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  DataRow _buildRow(PayrollRecord r) {
    final currency = NumberFormat('#,###');
    return DataRow(cells: [
      DataCell(SizedBox(width: 150, child: Text(r.employeeName, overflow: TextOverflow.ellipsis))),
      DataCell(Text(r.department)),
      DataCell(Text('KES ${currency.format(r.basicSalary)}')),
      DataCell(Text('KES ${currency.format(r.totalAllowances)}')),
      DataCell(Text(r.overtimeHours > 0 ? '${r.overtimeHours.toStringAsFixed(1)} hrs' : '-')),
      DataCell(Text('KES ${currency.format(r.totalStatutoryDeductions)}', style: const TextStyle(color: Colors.red))),
      DataCell(Text('KES ${currency.format(r.totalOtherDeductions)}')),
      DataCell(Text('KES ${currency.format(r.netPay)}',
          style: const TextStyle(fontWeight: FontWeight.bold, color: _brandPurple))),
      DataCell(Text(r.bankDetails?['bankName']?.toString() ?? '-')),
      DataCell(_buildStatusBadge(r.status)),
      DataCell(
        r.hasPayslip
            ? IconButton(
                icon: const Icon(Icons.visibility, size: 20, color: _brandPurple),
                tooltip: 'View Payslip',
                onPressed: () => PayrollDocumentActions.openPayslip(context, r),
              )
            : const Text('Not issued', style: TextStyle(color: Colors.grey, fontSize: 12)),
      ),
    ]);
  }

  Widget _buildStatusBadge(String status) {
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }

  void _showMonthPickerDialog() {
    final months = List.generate(12, (i) {
      final now = DateTime.now();
      return DateTime(now.year, now.month - i, 1);
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.calendar_month, color: _brandPurple),
          SizedBox(width: 12),
          Text('Select Viewing Period'),
        ]),
        content: SizedBox(
          width: double.minPositive,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: months.length,
            itemBuilder: (context, index) {
              final month = months[index];
              final isSelected = month.month == _selectedMonth.month && month.year == _selectedMonth.year;
              return ListTile(
                selected: isSelected,
                leading: Icon(isSelected ? Icons.check_circle : Icons.calendar_today,
                    color: isSelected ? _brandPurple : Colors.grey),
                title: Text(DateFormat('MMMM yyyy').format(month)),
                onTap: () {
                  setState(() => _selectedMonth = month);
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

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Employees'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter name, department, or account...',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => setState(() => _searchQuery = value.trim().toLowerCase()),
          onSubmitted: (value) {
            setState(() => _searchQuery = value.trim().toLowerCase());
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _searchQuery = '');
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: _brandPurple),
            child: const Text('Search', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadExcel(PayrollRun run) async {
    setState(() => _isDownloading = true);
    try {
      final records = await _payrollService.getRecords(run.id);
      final result = await ExcelGenerationService.generatePayrollRunExcel(run, records);
      final path = await ExcelDownloadService.downloadExcel(result['fileBytes'], result['fileName'] as String);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(kIsWeb ? 'Payroll Excel downloaded!' : 'Payroll Excel saved to: $path'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e, st) {
      _logger.e('Error exporting payroll Excel', error: e, stackTrace: st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating payroll Excel: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }
}
