import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'payroll_models.dart';
import 'payroll_service.dart';

/// Builds and uploads PDF payslips for [PayrollRecord]s.
class PayrollPdfGenerator {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  static final _brandPurple = PdfColor.fromInt(0xFF560A77);
  static final _currency = NumberFormat('#,##0.00');

  /// Renders a single A4 payslip for [record] and returns the PDF bytes.
  static Future<Uint8List> buildPayslipPdf(
    PayrollRecord record, {
    String companyName = 'JV Almacis',
  }) async {
    final doc = pw.Document();
    final monthLabel = DateFormat('MMMM yyyy').format(DateTime.parse('${record.month}-01'));

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader(companyName, monthLabel),
              pw.SizedBox(height: 16),
              _buildEmployeeMeta(record),
              pw.SizedBox(height: 16),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(child: _buildEarningsTable(record)),
                  pw.SizedBox(width: 16),
                  pw.Expanded(child: _buildDeductionsTable(record)),
                ],
              ),
              pw.SizedBox(height: 16),
              _buildNetPaySummary(record),
              pw.Spacer(),
              pw.Divider(),
              pw.Text(
                'This is a computer-generated payslip and does not require a signature.',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  static pw.Widget _buildHeader(String companyName, String monthLabel) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(color: _brandPurple, borderRadius: pw.BorderRadius.circular(6)),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            companyName,
            style: pw.TextStyle(color: PdfColors.white, fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('PAYSLIP', style: const pw.TextStyle(color: PdfColors.white, fontSize: 14)),
              pw.Text(monthLabel, style: const pw.TextStyle(color: PdfColors.white, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildEmployeeMeta(PayrollRecord record) {
    final bank = record.bankDetails;
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _metaRow('Employee', record.employeeName),
                _metaRow('Department', record.department),
                _metaRow('Hours Worked', record.hoursWorked.toStringAsFixed(1)),
                _metaRow('Overtime Hours', record.overtimeHours.toStringAsFixed(1)),
              ],
            ),
          ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _metaRow('Bank', bank?['bankName']?.toString() ?? '-'),
                _metaRow('Account No.', bank?['accountNumber']?.toString() ?? '-'),
                // 'branch' is a legacy key from older self-onboarding
                // records, superseded by 'branchName'.
                _metaRow('Branch', (bank?['branchName'] ?? bank?['branch'])?.toString() ?? '-'),
                _metaRow('Status', record.status.toUpperCase()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _metaRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        children: [
          pw.SizedBox(width: 90, child: pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700))),
          pw.Text(value, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  static pw.Widget _buildEarningsTable(PayrollRecord record) {
    final rows = <List<String>>[
      ['Basic Salary', _currency.format(record.basicSalary)],
      ...record.standingAllowances.entries.map((e) => [_titleCase(e.key), _currency.format(e.value)]),
      ...record.adhocAllowances.entries.map((e) => [e.key, _currency.format(e.value)]),
      if (record.overtimePay > 0) ['Overtime Pay', _currency.format(record.overtimePay)],
    ];
    return _buildTable('Earnings', rows, record.grossPay, 'Gross Pay');
  }

  static pw.Widget _buildDeductionsTable(PayrollRecord record) {
    final rows = <List<String>>[
      ['PAYE Tax', _currency.format(record.payeTax)],
      ['NSSF', _currency.format(record.nssfDeduction)],
      ['SHIF', _currency.format(record.shifDeduction)],
      ['Housing Levy', _currency.format(record.housingLevy)],
      ...record.standingDeductions.entries.map((e) => [_titleCase(e.key), _currency.format(e.value)]),
      ...record.adhocDeductions.entries.map((e) => [e.key, _currency.format(e.value)]),
    ];
    final total = record.totalStatutoryDeductions + record.totalOtherDeductions;
    return _buildTable('Deductions', rows, total, 'Total Deductions');
  }

  static pw.Widget _buildTable(String title, List<List<String>> rows, double total, String totalLabel) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _brandPurple)),
        pw.SizedBox(height: 4),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          columnWidths: const {0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(1)},
          children: [
            for (final row in rows)
              pw.TableRow(children: [
                pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(row[0], style: const pw.TextStyle(fontSize: 9))),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(row[1], style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.right),
                ),
              ]),
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(totalLabel, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(_currency.format(total),
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildNetPaySummary(PayrollRecord record) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(color: _brandPurple, borderRadius: pw.BorderRadius.circular(6)),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('NET PAY', style: pw.TextStyle(color: PdfColors.white, fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.Text('KES ${_currency.format(record.netPay)}',
              style: pw.TextStyle(color: PdfColors.white, fontSize: 14, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  static String _titleCase(String key) =>
      key.isEmpty ? key : '${key[0].toUpperCase()}${key.substring(1)}';

  /// Builds the payslip PDF, uploads it to Storage under
  /// `payroll_payslips/{runId}/{employeeUid}.pdf`, persists the download URL
  /// on the record via [service], and returns that URL.
  static Future<String?> generateAndUpload(PayrollRecord record, PayrollService service) async {
    try {
      final bytes = await buildPayslipPdf(record);
      final ref = FirebaseStorage.instance
          .ref()
          .child('payroll_payslips')
          .child(record.runId)
          .child('${record.employeeUid}.pdf');

      await ref.putData(
        bytes,
        SettableMetadata(
          contentType: 'application/pdf',
          customMetadata: {
            'employeeUid': record.employeeUid,
            'month': record.month,
          },
        ),
      );

      final url = await ref.getDownloadURL();
      await service.savePayslipUrl(record.id, url);
      _logger.i('Payslip generated for ${record.employeeName} (${record.month})');
      return url;
    } catch (e, stackTrace) {
      _logger.e('Error generating payslip for ${record.id}', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Bulk-generates payslips for every record in a run, reporting progress
  /// via [onProgress] (completed count, total count).
  static Future<void> bulkGenerateForRun(
    List<PayrollRecord> records,
    PayrollService service, {
    void Function(int completed, int total)? onProgress,
  }) async {
    var completed = 0;
    for (final record in records) {
      await generateAndUpload(record, service);
      completed++;
      onProgress?.call(completed, records.length);
    }
  }
}
