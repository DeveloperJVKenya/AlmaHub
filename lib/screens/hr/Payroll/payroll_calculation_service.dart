import 'payroll_models.dart';
import 'payroll_statutory_calculator.dart';

/// Pure calculation logic for turning one employee's raw Firestore data into
/// a fully-computed [PayrollRecord]. Contains no Firestore/Storage IO so it
/// can be unit-tested and reused by both the initial run generation and any
/// later recompute (e.g. after HR edits an ad-hoc entry).
class PayrollCalculationService {
  const PayrollCalculationService._();

  /// Builds a [PayrollRecord] for [runId]/[monthKey] from [employeeData]
  /// (the raw map stored under `EmployeeDetails`), the employee's
  /// [department], and the active [settings]. Any [existingAdhocAllowances]/
  /// [existingAdhocDeductions] are preserved across a recompute.
  ///
  /// `hoursWorked`/`daysWorked` are approval-gated at the source: HoursService
  /// (see lib/services/hours_service.dart) only ever sums a day into these
  /// monthly maps once a supervisor has approved it, so this method doesn't
  /// need its own completeness/approval check on top.
  static PayrollRecord buildRecord({
    required String runId,
    required String monthKey,
    required String employeeUid,
    required Map<String, dynamic> employeeData,
    required String department,
    required PayrollSettingsModel settings,
    Map<String, double>? existingAdhocAllowances,
    Map<String, double>? existingAdhocDeductions,
  }) {
    final personalInfo = employeeData['personalInfo'] as Map<String, dynamic>? ?? {};
    final payrollData = employeeData['payrollDetails'] as Map<String, dynamic>? ?? {};
    final hoursWorkedMap = employeeData['hoursWorked'] as Map<String, dynamic>? ?? {};
    final daysWorkedMap = employeeData['daysWorked'] as Map<String, dynamic>? ?? {};

    final fullName = personalInfo['fullName'] ?? 'Unknown';
    final basicSalary = (payrollData['basicSalary'] ?? 0).toDouble();

    final standingAllowances = Map<String, double>.from(
      (payrollData['allowances'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, (v ?? 0).toDouble())),
    );
    final standingDeductions = Map<String, double>.from(
      (payrollData['deductions'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, (v ?? 0).toDouble())),
    );
    final bankDetails = payrollData['bankDetails'] as Map<String, dynamic>?;
    final mpesaDetails = payrollData['mpesaDetails'] as Map<String, dynamic>?;

    final hoursWorked = (hoursWorkedMap[monthKey] ?? 0).toDouble();
    final daysWorked = (daysWorkedMap[monthKey] ?? 0) as int;

    final overtimeHours = _calculateOvertimeHours(
      hoursWorked: hoursWorked,
      daysWorked: daysWorked,
      standardHoursPerDay: settings.standardHoursPerDay,
      maxHoursPerDay: settings.maxHoursPerDay,
    );

    final hourlyRate =
        settings.standardMonthlyHours > 0 ? basicSalary / settings.standardMonthlyHours : 0.0;
    final overtimePay = overtimeHours * hourlyRate * settings.overtimeMultiplier;

    final adhocAllowances = existingAdhocAllowances ?? const {};
    final adhocDeductions = existingAdhocDeductions ?? const {};

    final totalStandingAllowances = standingAllowances.values.fold(0.0, (a, b) => a + b);
    final totalAdhocAllowances = adhocAllowances.values.fold(0.0, (a, b) => a + b);
    final totalStandingDeductions = standingDeductions.values.fold(0.0, (a, b) => a + b);
    final totalAdhocDeductions = adhocDeductions.values.fold(0.0, (a, b) => a + b);

    final grossPay =
        basicSalary + totalStandingAllowances + totalAdhocAllowances + overtimePay;

    final statutory = PayrollStatutoryCalculator.calculateAll(grossPay: grossPay);

    final netPay = grossPay -
        statutory.total -
        totalStandingDeductions -
        totalAdhocDeductions;

    return PayrollRecord(
      id: PayrollRecord.buildId(runId, employeeUid),
      runId: runId,
      month: monthKey,
      employeeUid: employeeUid,
      employeeName: fullName,
      department: department,
      basicSalary: basicSalary,
      standingAllowances: standingAllowances,
      standingDeductions: standingDeductions,
      adhocAllowances: adhocAllowances,
      adhocDeductions: adhocDeductions,
      hoursWorked: hoursWorked,
      daysWorked: daysWorked,
      overtimeHours: overtimeHours,
      hourlyRate: hourlyRate,
      overtimePay: overtimePay,
      grossPay: grossPay,
      payeTax: statutory.payeTax,
      nssfDeduction: statutory.nssfDeduction,
      shifDeduction: statutory.shifDeduction,
      housingLevy: statutory.housingLevy,
      totalStatutoryDeductions: statutory.total,
      netPay: netPay,
      bankDetails: bankDetails,
      mpesaDetails: mpesaDetails,
      status: 'draft',
      createdAt: DateTime.now(),
    );
  }

  /// Re-derives a [PayrollRecord] with new ad-hoc entries, keeping every
  /// upstream figure (basic salary, hours, standing allowances/deductions)
  /// unchanged — used when HR edits a record after generation.
  static PayrollRecord recomputeWithAdhoc({
    required PayrollRecord record,
    required PayrollSettingsModel settings,
    Map<String, double>? adhocAllowances,
    Map<String, double>? adhocDeductions,
  }) {
    final newAdhocAllowances = adhocAllowances ?? record.adhocAllowances;
    final newAdhocDeductions = adhocDeductions ?? record.adhocDeductions;

    final totalStandingAllowances = record.standingAllowances.values.fold(0.0, (a, b) => a + b);
    final totalAdhocAllowances = newAdhocAllowances.values.fold(0.0, (a, b) => a + b);
    final totalStandingDeductions = record.standingDeductions.values.fold(0.0, (a, b) => a + b);
    final totalAdhocDeductions = newAdhocDeductions.values.fold(0.0, (a, b) => a + b);

    final grossPay = record.basicSalary +
        totalStandingAllowances +
        totalAdhocAllowances +
        record.overtimePay;

    final statutory = PayrollStatutoryCalculator.calculateAll(grossPay: grossPay);

    final netPay = grossPay - statutory.total - totalStandingDeductions - totalAdhocDeductions;

    return record.copyWith(
      adhocAllowances: newAdhocAllowances,
      adhocDeductions: newAdhocDeductions,
      grossPay: grossPay,
      payeTax: statutory.payeTax,
      nssfDeduction: statutory.nssfDeduction,
      shifDeduction: statutory.shifDeduction,
      housingLevy: statutory.housingLevy,
      totalStatutoryDeductions: statutory.total,
      netPay: netPay,
    );
  }

  /// Ported from the legacy Accountant dashboard: average hours/day over the
  /// month, anything above [standardHoursPerDay] counts as overtime, capped
  /// at [maxHoursPerDay]/day to guard against bad data entry.
  static double _calculateOvertimeHours({
    required double hoursWorked,
    required int daysWorked,
    required double standardHoursPerDay,
    required double maxHoursPerDay,
  }) {
    if (hoursWorked <= 0 || daysWorked <= 0) return 0;

    final avgHoursPerDay = hoursWorked / daysWorked;
    double overtimePerDay = 0;
    if (avgHoursPerDay > standardHoursPerDay) {
      overtimePerDay = avgHoursPerDay <= maxHoursPerDay
          ? avgHoursPerDay - standardHoursPerDay
          : maxHoursPerDay - standardHoursPerDay;
    }
    return overtimePerDay * daysWorked;
  }
}
