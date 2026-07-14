import 'dart:typed_data';
import 'package:almahub/models/employee_onboarding_models.dart';
import 'package:almahub/screens/hr/Payroll/payroll_models.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

class ExcelGenerationService {
  /// Generate an Excel report for one payroll run: one row per employee
  /// record plus a totals row, matching the columns HR reviews on-screen in
  /// the Payroll module. Used by both the HR Payroll screen and the
  /// read-only Accountant dashboard export.
  static Future<Map<String, dynamic>> generatePayrollRunExcel(
    PayrollRun run,
    List<PayrollRecord> records,
  ) async {
    final excel = Excel.createExcel();
    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final sheet = excel['Payroll ${run.month}'];

    final headers = [
      'No.', 'Employee', 'Department', 'Basic Salary', 'Allowances',
      'Overtime Hours', 'Overtime Pay', 'Gross Pay', 'PAYE', 'NSSF',
      'SHIF', 'Housing Levy', 'Other Deductions', 'Net Pay', 'Status',
      'Payment Method', 'Transaction Ref',
    ];
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

    for (int i = 0; i < records.length; i++) {
      final r = records[i];
      sheet.appendRow([
        IntCellValue(i + 1),
        TextCellValue(r.employeeName),
        TextCellValue(r.department),
        DoubleCellValue(r.basicSalary),
        DoubleCellValue(r.totalAllowances),
        DoubleCellValue(r.overtimeHours),
        DoubleCellValue(r.overtimePay),
        DoubleCellValue(r.grossPay),
        DoubleCellValue(r.payeTax),
        DoubleCellValue(r.nssfDeduction),
        DoubleCellValue(r.shifDeduction),
        DoubleCellValue(r.housingLevy),
        DoubleCellValue(r.totalOtherDeductions),
        DoubleCellValue(r.netPay),
        TextCellValue(r.status),
        TextCellValue(r.paymentMethod ?? '-'),
        TextCellValue(r.transactionRef ?? '-'),
      ]);
    }

    sheet.appendRow([
      TextCellValue(''),
      TextCellValue('TOTAL'),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      DoubleCellValue(run.totalGrossPay),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      DoubleCellValue(run.totalStatutoryDeductions),
      DoubleCellValue(run.totalNetPay),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
    ]);

    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('Failed to encode payroll Excel file');
    }

    final fileName = 'Payroll_${run.month}.xlsx';
    return {
      'fileName': fileName,
      'fileBytes': Uint8List.fromList(bytes),
      'fileSize': bytes.length,
    };
  }

  /// Generate comprehensive Excel file with all employee onboarding data
  /// Returns both the file bytes and the filename
  static Future<Map<String, dynamic>> generateEmployeeOnboardingExcel(
    List<EmployeeOnboarding> employees,
  ) async {
    try {
      final excel = Excel.createExcel();
      
      // Remove default sheet if it exists
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }
      
      // Add summary sheet first
      addSummarySheet(excel, employees);
      
      // Create main data sheet
      final sheet = excel['Employee Onboarding Data'];

      // Set column widths for better readability
      _setupColumnWidths(sheet);

      // Add header row with styling
      _addHeaderRow(sheet);

      // Add data rows
      _addDataRows(sheet, employees);

      // Generate filename with timestamp
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'AlmaHub_Employee_Onboarding_$timestamp.xlsx';
      
      // Encode to bytes
      final bytes = excel.encode();
      
      if (bytes == null) {
        throw Exception('Failed to encode Excel file');
      }
      
      return {
        'fileName': fileName,
        'fileBytes': Uint8List.fromList(bytes),
        'fileSize': bytes.length,
      };
    } catch (e) {
      throw Exception('Excel generation failed: $e');
    }
  }

  /// Set up column widths
  static void _setupColumnWidths(Sheet sheet) {
    sheet.setColumnWidth(0, 5.0);   // ID column
    sheet.setColumnWidth(1, 25.0);  // Full Name
    sheet.setColumnWidth(2, 20.0);  // National ID
    sheet.setColumnWidth(3, 15.0);  // Date of Birth
    sheet.setColumnWidth(4, 12.0);  // Gender
    sheet.setColumnWidth(5, 18.0);  // Phone
    sheet.setColumnWidth(6, 25.0);  // Email
    sheet.setColumnWidth(7, 30.0);  // Address
    sheet.setColumnWidth(8, 20.0);  // Next of Kin
    sheet.setColumnWidth(9, 20.0);  // Job Title
    sheet.setColumnWidth(10, 18.0); // Department
    sheet.setColumnWidth(11, 15.0); // Employment Type
    sheet.setColumnWidth(12, 15.0); // Start Date
    sheet.setColumnWidth(13, 20.0); // Supervisor
    sheet.setColumnWidth(14, 18.0); // KRA PIN
    sheet.setColumnWidth(15, 18.0); // NSSF Number
    sheet.setColumnWidth(16, 18.0); // SHIF Number
    sheet.setColumnWidth(17, 18.0); // Basic Salary
    sheet.setColumnWidth(18, 20.0); // Allowances
    sheet.setColumnWidth(19, 20.0); // Deductions
    sheet.setColumnWidth(20, 20.0); // Bank Name
    sheet.setColumnWidth(21, 20.0); // Account Number
    sheet.setColumnWidth(22, 18.0); // M-Pesa
    sheet.setColumnWidth(23, 25.0); // Work Email
    sheet.setColumnWidth(24, 15.0); // Status
    sheet.setColumnWidth(25, 18.0); // Submitted Date
    sheet.setColumnWidth(26, 25.0); // Postal Address
    sheet.setColumnWidth(27, 18.0); // Working Hours
    sheet.setColumnWidth(28, 20.0); // Work Location
    sheet.setColumnWidth(29, 25.0); // Professional Registrations
    sheet.setColumnWidth(30, 25.0); // Academic Certificates
    sheet.setColumnWidth(31, 25.0); // Professional Certificates
    sheet.setColumnWidth(32, 15.0); // Contract Signed
    sheet.setColumnWidth(33, 15.0); // NDA Signed
    sheet.setColumnWidth(34, 20.0); // Code of Conduct
    sheet.setColumnWidth(35, 20.0); // Data Protection
    sheet.setColumnWidth(36, 25.0); // SHIF Dependants
    sheet.setColumnWidth(37, 25.0); // Beneficiaries
    sheet.setColumnWidth(38, 25.0); // Issued Equipment
    sheet.setColumnWidth(39, 18.0); // HRIS Profile
    sheet.setColumnWidth(40, 18.0); // System Access
    sheet.setColumnWidth(41, 18.0); // Housing Allowance
    sheet.setColumnWidth(42, 18.0); // Transport Allowance
    sheet.setColumnWidth(43, 18.0); // Other Allowances
    sheet.setColumnWidth(44, 18.0); // Loans Deduction
    sheet.setColumnWidth(45, 18.0); // SACCO Deduction
    sheet.setColumnWidth(46, 18.0); // Advance Deduction
    sheet.setColumnWidth(47, 20.0); // Bank Branch
    sheet.setColumnWidth(48, 20.0); // M-Pesa Name
  }

  /// Add header row with styling
  static void _addHeaderRow(Sheet sheet) {
    final headerStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#1A237E'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      bold: true,
      fontSize: 11,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final headers = [
      'No.',
      'Full Name',
      'National ID/Passport',
      'Date of Birth',
      'Gender',
      'Phone Number',
      'Email Address',
      'Physical Address',
      'Next of Kin (Name, Relationship, Contact)',
      'Job Title',
      'Department',
      'Employment Type',
      'Start Date',
      'Supervisor/Manager',
      'KRA PIN',
      'NSSF Number',
      'SHIF Number',
      'Basic Salary (KES)',
      'Allowances (KES)',
      'Deductions (KES)',
      'Bank Name',
      'Account Number',
      'M-Pesa Number',
      'Work Email',
      'Status',
      'Submitted Date',
      'Postal Address',
      'Working Hours',
      'Work Location',
      'Professional Registrations',
      'Academic Certificates',
      'Professional Certificates',
      'Contract Signed',
      'NDA Signed',
      'Code of Conduct Acknowledged',
      'Data Protection Consent',
      'SHIF Dependants',
      'Beneficiaries',
      'Issued Equipment',
      'HRIS Profile Created',
      'System Access Granted',
      'Housing Allowance (KES)',
      'Transport Allowance (KES)',
      'Other Allowances (KES)',
      'Loans Deduction (KES)',
      'SACCO Deduction (KES)',
      'Advance Deduction (KES)',
      'Bank Branch',
      'M-Pesa Name',
    ];

    // Add headers
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    // Set header row height
    sheet.setRowHeight(0, 25);
  }

  /// Add data rows
  static void _addDataRows(Sheet sheet, List<EmployeeOnboarding> employees) {
    final dataStyle = CellStyle(
      fontSize: 10,
      verticalAlign: VerticalAlign.Center,
    );

    final dateFormat = DateFormat('dd/MM/yyyy');
    final currencyFormat = NumberFormat('#,##0.00');

    for (int index = 0; index < employees.length; index++) {
      final employee = employees[index];
      final rowIndex = index + 1;

      // Helper function to format allowances/deductions
      String formatMoneyMap(Map<String, double> map) {
        if (map.isEmpty) return '-';
        return map.entries
            .map((e) => '${e.key}: KES ${currencyFormat.format(e.value)}')
            .join('; ');
      }

      // Helper function to get specific allowance
      double getAllowance(Map<String, double> allowances, String key) {
        return allowances[key] ?? 0.0;
      }

      // Helper function to get specific deduction
      double getDeduction(Map<String, double> deductions, String key) {
        return deductions[key] ?? 0.0;
      }

      final rowData = [
        rowIndex, // No.
        employee.personalInfo.fullName,
        employee.personalInfo.nationalIdOrPassport,
        employee.personalInfo.dateOfBirth != null
            ? dateFormat.format(employee.personalInfo.dateOfBirth!)
            : '-',
        employee.personalInfo.gender,
        employee.personalInfo.phoneNumber,
        employee.personalInfo.email,
        employee.personalInfo.physicalAddress,
        '${employee.personalInfo.nextOfKin.name} (${employee.personalInfo.nextOfKin.relationship}) - ${employee.personalInfo.nextOfKin.contact}',
        employee.employmentDetails.jobTitle,
        employee.employmentDetails.department,
        employee.employmentDetails.employmentType,
        employee.employmentDetails.startDate != null
            ? dateFormat.format(employee.employmentDetails.startDate!)
            : '-',
        employee.employmentDetails.supervisorName,
        employee.statutoryDocs.kraPinNumber,
        employee.statutoryDocs.nssfNumber,
        employee.statutoryDocs.shifNumber,
        currencyFormat.format(employee.payrollDetails.basicSalary),
        formatMoneyMap(employee.payrollDetails.allowances),
        formatMoneyMap(employee.payrollDetails.deductions),
        employee.payrollDetails.bankDetails.bankName.isEmpty ? '-' : employee.payrollDetails.bankDetails.bankName,
        employee.payrollDetails.bankDetails.accountNumber.isEmpty
            ? '-'
            : employee.payrollDetails.bankDetails.accountNumber,
        employee.payrollDetails.mpesaDetails?.phoneNumber ?? '-',
        employee.workTools.workEmail ?? '-',
        employee.status.toUpperCase(),
        employee.submittedAt != null
            ? dateFormat.format(employee.submittedAt!)
            : '-',
        employee.personalInfo.postalAddress,
        employee.employmentDetails.workingHours,
        employee.employmentDetails.workLocation,
        employee.academicDocs.professionalRegistrations.entries
            .map((e) => '${e.key}: ${e.value}')
            .join('; '),
        employee.academicDocs.academicCertificates.isNotEmpty
            ? '${employee.academicDocs.academicCertificates.length} certificates uploaded'
            : 'None',
        employee.academicDocs.professionalCertificates.isNotEmpty
            ? '${employee.academicDocs.professionalCertificates.length} certificates uploaded'
            : 'None',
        employee.contractsForms.employmentContractUrl != null ? 'Yes' : 'No',
        employee.contractsForms.ndaUrl != null ? 'Yes' : 'No',
        employee.contractsForms.codeOfConductAcknowledged ? 'Yes' : 'No',
        employee.contractsForms.dataProtectionConsentGiven ? 'Yes' : 'No',
        employee.benefitsInsurance.shifDependants.isNotEmpty
            ? employee.benefitsInsurance.shifDependants
                .map((d) => '${d.name} (${d.relationship})')
                .join('; ')
            : 'None',
        employee.benefitsInsurance.beneficiaries.isNotEmpty
            ? employee.benefitsInsurance.beneficiaries
                .map((b) => '${b.name} (${b.percentage}%)')
                .join('; ')
            : 'None',
        employee.workTools.issuedEquipment.isNotEmpty
            ? employee.workTools.issuedEquipment
                .map((e) => '${e.itemName} - ${e.serialNumber}')
                .join('; ')
            : 'None',
        employee.workTools.hrisProfileCreated ? 'Yes' : 'No',
        employee.workTools.systemAccessGranted ? 'Yes' : 'No',
        currencyFormat.format(getAllowance(employee.payrollDetails.allowances, 'housing')),
        currencyFormat.format(getAllowance(employee.payrollDetails.allowances, 'transport')),
        currencyFormat.format(getAllowance(employee.payrollDetails.allowances, 'other')),
        currencyFormat.format(getDeduction(employee.payrollDetails.deductions, 'loans')),
        currencyFormat.format(getDeduction(employee.payrollDetails.deductions, 'sacco')),
        currencyFormat.format(getDeduction(employee.payrollDetails.deductions, 'advance')),
        employee.payrollDetails.bankDetails.branchName.isEmpty
            ? '-'
            : employee.payrollDetails.bankDetails.branchName,
        employee.payrollDetails.mpesaDetails?.name ?? '-',
      ];

      for (int colIndex = 0; colIndex < rowData.length; colIndex++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: rowIndex),
        );
        
        // Properly set cell value based on type
        final value = rowData[colIndex];
        if (value is int) {
          cell.value = IntCellValue(value);
        } else if (value is double) {
          cell.value = DoubleCellValue(value);
        } else {
          cell.value = TextCellValue(value.toString());
        }
        
        cell.cellStyle = dataStyle;
      }
    }
  }

  /// Generate a summary statistics sheet
  static void addSummarySheet(Excel excel, List<EmployeeOnboarding> employees) {
    final summarySheet = excel['Summary'];

    // Header
    final titleCell = summarySheet.cell(CellIndex.indexByString('A1'));
    titleCell.value = TextCellValue('AlmaHub - Employee Onboarding Summary');
    titleCell.cellStyle = CellStyle(
      bold: true,
      fontSize: 16,
      fontColorHex: ExcelColor.fromHexString('#1A237E'),
    );

    // Statistics
    final totalEmployees = employees.length;
    final submitted = employees.where((e) => e.status == 'submitted').length;
    final approved = employees.where((e) => e.status == 'approved').length;
    final drafts = employees.where((e) => e.status == 'draft').length;
    final rejected = employees.where((e) => e.status == 'rejected').length;

    final stats = [
      ['', ''],
      ['Total Employees:', totalEmployees],
      ['Submitted:', submitted],
      ['Approved:', approved],
      ['Drafts:', drafts],
      ['Rejected:', rejected],
      ['', ''],
      ['Report Generated:', DateFormat('dd MMMM yyyy HH:mm').format(DateTime.now())],
    ];

    final labelStyle = CellStyle(bold: true, fontSize: 11);
    final valueStyle = CellStyle(fontSize: 11);

    for (int i = 0; i < stats.length; i++) {
      final labelCell = summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i + 2));
      final labelValue = stats[i][0];
      labelCell.value = TextCellValue(labelValue.toString());
      labelCell.cellStyle = labelStyle;

      final valueCell = summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: i + 2));
      final cellValue = stats[i][1];
      if (cellValue is int) {
        valueCell.value = IntCellValue(cellValue);
      } else {
        valueCell.value = TextCellValue(cellValue.toString());
      }
      valueCell.cellStyle = valueStyle;
    }

    summarySheet.setColumnWidth(0, 25.0);
    summarySheet.setColumnWidth(1, 20.0);
  }
}