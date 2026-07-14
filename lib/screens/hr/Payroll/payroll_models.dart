import 'package:cloud_firestore/cloud_firestore.dart';

/// Configurable payroll knobs, stored as a single Firestore document so HR
/// can tune overtime/hours assumptions without a code change.
/// Collection: 'PayrollSettings', doc id: 'config'.
class PayrollSettingsModel {
  final double overtimeMultiplier;
  final double standardMonthlyHours;
  final double standardHoursPerDay;
  final double maxHoursPerDay;
  final DateTime? updatedAt;
  final String? updatedBy;

  const PayrollSettingsModel({
    this.overtimeMultiplier = 1.5,
    this.standardMonthlyHours = 195,
    this.standardHoursPerDay = 8,
    this.maxHoursPerDay = 12,
    this.updatedAt,
    this.updatedBy,
  });

  factory PayrollSettingsModel.fromMap(Map<String, dynamic> map) {
    return PayrollSettingsModel(
      overtimeMultiplier: (map['overtimeMultiplier'] ?? 1.5).toDouble(),
      standardMonthlyHours: (map['standardMonthlyHours'] ?? 195).toDouble(),
      standardHoursPerDay: (map['standardHoursPerDay'] ?? 8).toDouble(),
      maxHoursPerDay: (map['maxHoursPerDay'] ?? 12).toDouble(),
      updatedAt: map['updatedAt'] != null ? (map['updatedAt'] as Timestamp).toDate() : null,
      updatedBy: map['updatedBy'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'overtimeMultiplier': overtimeMultiplier,
      'standardMonthlyHours': standardMonthlyHours,
      'standardHoursPerDay': standardHoursPerDay,
      'maxHoursPerDay': maxHoursPerDay,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : Timestamp.now(),
      'updatedBy': updatedBy,
    };
  }

  PayrollSettingsModel copyWith({
    double? overtimeMultiplier,
    double? standardMonthlyHours,
    double? standardHoursPerDay,
    double? maxHoursPerDay,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return PayrollSettingsModel(
      overtimeMultiplier: overtimeMultiplier ?? this.overtimeMultiplier,
      standardMonthlyHours: standardMonthlyHours ?? this.standardMonthlyHours,
      standardHoursPerDay: standardHoursPerDay ?? this.standardHoursPerDay,
      maxHoursPerDay: maxHoursPerDay ?? this.maxHoursPerDay,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }
}

/// One skipped employee from a payroll run generation, with the reason they
/// were excluded — surfaced to HR instead of only being logged.
class PayrollSkippedEmployee {
  final String uid;
  final String employeeName;
  final String reason;

  const PayrollSkippedEmployee({
    required this.uid,
    required this.employeeName,
    required this.reason,
  });

  factory PayrollSkippedEmployee.fromMap(Map<String, dynamic> map) {
    return PayrollSkippedEmployee(
      uid: map['uid'] ?? '',
      employeeName: map['employeeName'] ?? 'Unknown',
      reason: map['reason'] ?? 'Unknown reason',
    );
  }

  Map<String, dynamic> toMap() {
    return {'uid': uid, 'employeeName': employeeName, 'reason': reason};
  }
}

/// One monthly payroll run. Collection: 'PayrollRuns', doc id: 'yyyy-MM'.
class PayrollRun {
  final String id; // yyyy-MM
  final String month;
  final String status; // draft | approved | paid
  final int employeeCount;
  final double totalGrossPay;
  final double totalNetPay;
  final double totalStatutoryDeductions;
  final DateTime createdAt;
  final String? createdBy;
  final DateTime? approvedAt;
  final String? approvedBy;
  final DateTime? paidAt;
  final DateTime? generatedAt;
  final List<PayrollSkippedEmployee> skippedEmployees;

  const PayrollRun({
    required this.id,
    required this.month,
    required this.status,
    required this.employeeCount,
    required this.totalGrossPay,
    required this.totalNetPay,
    required this.totalStatutoryDeductions,
    required this.createdAt,
    this.createdBy,
    this.approvedAt,
    this.approvedBy,
    this.paidAt,
    this.generatedAt,
    this.skippedEmployees = const [],
  });

  bool get isDraft => status == 'draft';
  bool get isApproved => status == 'approved';
  bool get isPaid => status == 'paid';
  bool get isEditable => status == 'draft';

  factory PayrollRun.fromMap(Map<String, dynamic> map, String docId) {
    return PayrollRun(
      id: docId,
      month: map['month'] ?? docId,
      status: map['status'] ?? 'draft',
      employeeCount: (map['employeeCount'] ?? 0) as int,
      totalGrossPay: (map['totalGrossPay'] ?? 0).toDouble(),
      totalNetPay: (map['totalNetPay'] ?? 0).toDouble(),
      totalStatutoryDeductions: (map['totalStatutoryDeductions'] ?? 0).toDouble(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: map['createdBy'],
      approvedAt: map['approvedAt'] != null ? (map['approvedAt'] as Timestamp).toDate() : null,
      approvedBy: map['approvedBy'],
      paidAt: map['paidAt'] != null ? (map['paidAt'] as Timestamp).toDate() : null,
      generatedAt: map['generatedAt'] != null ? (map['generatedAt'] as Timestamp).toDate() : null,
      skippedEmployees: ((map['skippedEmployees'] as List<dynamic>?) ?? [])
          .map((e) => PayrollSkippedEmployee.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'month': month,
      'status': status,
      'employeeCount': employeeCount,
      'totalGrossPay': totalGrossPay,
      'totalNetPay': totalNetPay,
      'totalStatutoryDeductions': totalStatutoryDeductions,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'approvedBy': approvedBy,
      'paidAt': paidAt != null ? Timestamp.fromDate(paidAt!) : null,
      'generatedAt': generatedAt != null ? Timestamp.fromDate(generatedAt!) : Timestamp.now(),
      'skippedEmployees': skippedEmployees.map((e) => e.toMap()).toList(),
    };
  }

  PayrollRun copyWith({
    String? status,
    int? employeeCount,
    double? totalGrossPay,
    double? totalNetPay,
    double? totalStatutoryDeductions,
    String? createdBy,
    DateTime? approvedAt,
    String? approvedBy,
    DateTime? paidAt,
    DateTime? generatedAt,
    List<PayrollSkippedEmployee>? skippedEmployees,
  }) {
    return PayrollRun(
      id: id,
      month: month,
      status: status ?? this.status,
      employeeCount: employeeCount ?? this.employeeCount,
      totalGrossPay: totalGrossPay ?? this.totalGrossPay,
      totalNetPay: totalNetPay ?? this.totalNetPay,
      totalStatutoryDeductions: totalStatutoryDeductions ?? this.totalStatutoryDeductions,
      createdAt: createdAt,
      createdBy: createdBy ?? this.createdBy,
      approvedAt: approvedAt ?? this.approvedAt,
      approvedBy: approvedBy ?? this.approvedBy,
      paidAt: paidAt ?? this.paidAt,
      generatedAt: generatedAt ?? this.generatedAt,
      skippedEmployees: skippedEmployees ?? this.skippedEmployees,
    );
  }
}

/// Pre-generation eligibility snapshot for one `EmployeeDetails` doc — backs
/// the Payroll screen's "who's ready / who's missing what" preview shown
/// before HR clicks Generate Run, so an empty run isn't a mystery.
class PayrollEligibility {
  final String uid;
  final String employeeName;
  final String department;
  final bool isAdmin;
  final List<String> missingFields;

  const PayrollEligibility({
    required this.uid,
    required this.employeeName,
    required this.department,
    required this.isAdmin,
    required this.missingFields,
  });

  bool get isEligible => !isAdmin && missingFields.isEmpty;

  String get reason {
    if (isAdmin) return 'Admin account — excluded from payroll';
    if (missingFields.isNotEmpty) return 'Missing: ${missingFields.join(', ')}';
    return 'Ready';
  }
}

/// One employee's payroll line for a given run.
/// Collection: 'PayrollRecords', doc id: '{runId}_{employeeUid}'.
///
/// All monetary/standing fields are a SNAPSHOT taken at generation time —
/// later edits to the employee's onboarding `payrollDetails` never mutate a
/// historical record.
class PayrollRecord {
  final String id;
  final String runId;
  final String month;
  final String employeeUid;
  final String employeeName;
  final String department;

  final double basicSalary;
  final Map<String, double> standingAllowances;
  final Map<String, double> standingDeductions;
  final Map<String, double> adhocAllowances;
  final Map<String, double> adhocDeductions;

  final double hoursWorked;
  final int daysWorked;
  final double overtimeHours;
  final double hourlyRate;
  final double overtimePay;

  final double grossPay;
  final double payeTax;
  final double nssfDeduction;
  final double shifDeduction;
  final double housingLevy;
  final double totalStatutoryDeductions;
  final double netPay;

  final Map<String, dynamic>? bankDetails;
  final Map<String, dynamic>? mpesaDetails;

  final String status; // draft | approved | paid
  final String? paymentMethod; // bank | mpesa | airtel_money
  final String? transactionRef;
  final DateTime? paidAt;
  final String? payslipUrl;
  final DateTime? payslipGeneratedAt;

  final DateTime createdAt;
  final DateTime? updatedAt;

  const PayrollRecord({
    required this.id,
    required this.runId,
    required this.month,
    required this.employeeUid,
    required this.employeeName,
    this.department = '-',
    required this.basicSalary,
    this.standingAllowances = const {},
    this.standingDeductions = const {},
    this.adhocAllowances = const {},
    this.adhocDeductions = const {},
    this.hoursWorked = 0,
    this.daysWorked = 0,
    this.overtimeHours = 0,
    this.hourlyRate = 0,
    this.overtimePay = 0,
    required this.grossPay,
    this.payeTax = 0,
    this.nssfDeduction = 0,
    this.shifDeduction = 0,
    this.housingLevy = 0,
    this.totalStatutoryDeductions = 0,
    required this.netPay,
    this.bankDetails,
    this.mpesaDetails,
    this.status = 'draft',
    this.paymentMethod,
    this.transactionRef,
    this.paidAt,
    this.payslipUrl,
    this.payslipGeneratedAt,
    required this.createdAt,
    this.updatedAt,
  });

  static String buildId(String runId, String employeeUid) => '${runId}_$employeeUid';

  double get totalStandingAllowances => standingAllowances.values.fold(0.0, (a, b) => a + b);
  double get totalStandingDeductions => standingDeductions.values.fold(0.0, (a, b) => a + b);
  double get totalAdhocAllowances => adhocAllowances.values.fold(0.0, (a, b) => a + b);
  double get totalAdhocDeductions => adhocDeductions.values.fold(0.0, (a, b) => a + b);
  double get totalAllowances => totalStandingAllowances + totalAdhocAllowances;
  double get totalOtherDeductions => totalStandingDeductions + totalAdhocDeductions;

  bool get isDraft => status == 'draft';
  bool get isApproved => status == 'approved';
  bool get isPaid => status == 'paid';
  bool get hasPayslip => payslipUrl != null && payslipUrl!.isNotEmpty;

  factory PayrollRecord.fromMap(Map<String, dynamic> map, String docId) {
    return PayrollRecord(
      id: docId,
      runId: map['runId'] ?? '',
      month: map['month'] ?? '',
      employeeUid: map['employeeUid'] ?? '',
      employeeName: map['employeeName'] ?? '',
      department: map['department'] ?? '-',
      basicSalary: (map['basicSalary'] ?? 0).toDouble(),
      standingAllowances: Map<String, double>.from(
        (map['standingAllowances'] ?? {}).map((k, v) => MapEntry(k as String, (v ?? 0).toDouble())),
      ),
      standingDeductions: Map<String, double>.from(
        (map['standingDeductions'] ?? {}).map((k, v) => MapEntry(k as String, (v ?? 0).toDouble())),
      ),
      adhocAllowances: Map<String, double>.from(
        (map['adhocAllowances'] ?? {}).map((k, v) => MapEntry(k as String, (v ?? 0).toDouble())),
      ),
      adhocDeductions: Map<String, double>.from(
        (map['adhocDeductions'] ?? {}).map((k, v) => MapEntry(k as String, (v ?? 0).toDouble())),
      ),
      hoursWorked: (map['hoursWorked'] ?? 0).toDouble(),
      daysWorked: (map['daysWorked'] ?? 0) as int,
      overtimeHours: (map['overtimeHours'] ?? 0).toDouble(),
      hourlyRate: (map['hourlyRate'] ?? 0).toDouble(),
      overtimePay: (map['overtimePay'] ?? 0).toDouble(),
      grossPay: (map['grossPay'] ?? 0).toDouble(),
      payeTax: (map['payeTax'] ?? 0).toDouble(),
      nssfDeduction: (map['nssfDeduction'] ?? 0).toDouble(),
      shifDeduction: (map['shifDeduction'] ?? 0).toDouble(),
      housingLevy: (map['housingLevy'] ?? 0).toDouble(),
      totalStatutoryDeductions: (map['totalStatutoryDeductions'] ?? 0).toDouble(),
      netPay: (map['netPay'] ?? 0).toDouble(),
      bankDetails: map['bankDetails'] != null ? Map<String, dynamic>.from(map['bankDetails']) : null,
      mpesaDetails: map['mpesaDetails'] != null ? Map<String, dynamic>.from(map['mpesaDetails']) : null,
      status: map['status'] ?? 'draft',
      paymentMethod: map['paymentMethod'],
      transactionRef: map['transactionRef'],
      paidAt: map['paidAt'] != null ? (map['paidAt'] as Timestamp).toDate() : null,
      payslipUrl: map['payslipUrl'],
      payslipGeneratedAt:
          map['payslipGeneratedAt'] != null ? (map['payslipGeneratedAt'] as Timestamp).toDate() : null,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: map['updatedAt'] != null ? (map['updatedAt'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'runId': runId,
      'month': month,
      'employeeUid': employeeUid,
      'employeeName': employeeName,
      'department': department,
      'basicSalary': basicSalary,
      'standingAllowances': standingAllowances,
      'standingDeductions': standingDeductions,
      'adhocAllowances': adhocAllowances,
      'adhocDeductions': adhocDeductions,
      'hoursWorked': hoursWorked,
      'daysWorked': daysWorked,
      'overtimeHours': overtimeHours,
      'hourlyRate': hourlyRate,
      'overtimePay': overtimePay,
      'grossPay': grossPay,
      'payeTax': payeTax,
      'nssfDeduction': nssfDeduction,
      'shifDeduction': shifDeduction,
      'housingLevy': housingLevy,
      'totalStatutoryDeductions': totalStatutoryDeductions,
      'netPay': netPay,
      'bankDetails': bankDetails,
      'mpesaDetails': mpesaDetails,
      'status': status,
      'paymentMethod': paymentMethod,
      'transactionRef': transactionRef,
      'paidAt': paidAt != null ? Timestamp.fromDate(paidAt!) : null,
      'payslipUrl': payslipUrl,
      'payslipGeneratedAt': payslipGeneratedAt != null ? Timestamp.fromDate(payslipGeneratedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.now(),
    };
  }

  PayrollRecord copyWith({
    Map<String, double>? adhocAllowances,
    Map<String, double>? adhocDeductions,
    double? grossPay,
    double? payeTax,
    double? nssfDeduction,
    double? shifDeduction,
    double? housingLevy,
    double? totalStatutoryDeductions,
    double? netPay,
    String? status,
    String? paymentMethod,
    String? transactionRef,
    DateTime? paidAt,
    String? payslipUrl,
    DateTime? payslipGeneratedAt,
  }) {
    return PayrollRecord(
      id: id,
      runId: runId,
      month: month,
      employeeUid: employeeUid,
      employeeName: employeeName,
      department: department,
      basicSalary: basicSalary,
      standingAllowances: standingAllowances,
      standingDeductions: standingDeductions,
      adhocAllowances: adhocAllowances ?? this.adhocAllowances,
      adhocDeductions: adhocDeductions ?? this.adhocDeductions,
      hoursWorked: hoursWorked,
      daysWorked: daysWorked,
      overtimeHours: overtimeHours,
      hourlyRate: hourlyRate,
      overtimePay: overtimePay,
      grossPay: grossPay ?? this.grossPay,
      payeTax: payeTax ?? this.payeTax,
      nssfDeduction: nssfDeduction ?? this.nssfDeduction,
      shifDeduction: shifDeduction ?? this.shifDeduction,
      housingLevy: housingLevy ?? this.housingLevy,
      totalStatutoryDeductions: totalStatutoryDeductions ?? this.totalStatutoryDeductions,
      netPay: netPay ?? this.netPay,
      bankDetails: bankDetails,
      mpesaDetails: mpesaDetails,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      transactionRef: transactionRef ?? this.transactionRef,
      paidAt: paidAt ?? this.paidAt,
      payslipUrl: payslipUrl ?? this.payslipUrl,
      payslipGeneratedAt: payslipGeneratedAt ?? this.payslipGeneratedAt,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
