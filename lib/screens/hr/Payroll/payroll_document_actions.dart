import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:almahub/screens/hr/Policy%20Management/policy_document_actions.dart';
import 'payroll_models.dart';

/// Thin payslip-specific wrapper around [PolicyDocumentActions] — payslips
/// are always PDFs served from a Firebase Storage download URL, so the
/// generic view/download/cache/permission handling already built for policy
/// documents applies unchanged. This just supplies payslip-appropriate file
/// names and guards against a missing [PayrollRecord.payslipUrl].
class PayrollDocumentActions {
  PayrollDocumentActions._();

  static String _fileNameFor(PayrollRecord record) {
    final monthLabel = DateFormat('yyyy-MM').format(DateTime.parse('${record.month}-01'));
    final safeName = record.employeeName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return 'Payslip_${monthLabel}_$safeName.pdf';
  }

  static Future<void> openPayslip(BuildContext context, PayrollRecord record) async {
    if (!record.hasPayslip) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payslip has not been generated yet.')),
      );
      return;
    }
    await PolicyDocumentActions.openDocument(
      context: context,
      url: record.payslipUrl!,
      fileType: 'pdf',
      fileName: _fileNameFor(record),
    );
  }

  static Future<void> downloadPayslip(BuildContext context, PayrollRecord record) async {
    if (!record.hasPayslip) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payslip has not been generated yet.')),
      );
      return;
    }
    await PolicyDocumentActions.downloadDocument(
      context: context,
      url: record.payslipUrl!,
      fileName: _fileNameFor(record),
    );
  }
}
