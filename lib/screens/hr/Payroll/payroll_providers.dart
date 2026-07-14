import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'payroll_models.dart';
import 'payroll_service.dart';

/// Riverpod providers for the HR Payroll module. Scoped to this feature
/// only — the rest of the app keeps its existing StatefulWidget/setState
/// pattern untouched. `ProviderScope` at the app root (see main.dart) makes
/// these available anywhere they're watched, including a lightweight
/// `Consumer` embedded inside the still-StatefulWidget employee dashboard.
final payrollServiceProvider = Provider<PayrollService>((ref) => PayrollService());

/// Currently selected payroll month, as 'yyyy-MM'. Defaults to the current
/// month.
final selectedPayrollMonthProvider = StateProvider<String>(
  (ref) => DateFormat('yyyy-MM').format(DateTime.now()),
);

final payrollSettingsProvider = StreamProvider<PayrollSettingsModel>(
  (ref) => ref.watch(payrollServiceProvider).settingsStream(),
);

/// The payroll run for the currently selected month (null if not yet
/// generated).
final payrollRunProvider = StreamProvider<PayrollRun?>((ref) {
  final month = ref.watch(selectedPayrollMonthProvider);
  return ref.watch(payrollServiceProvider).runStream(month);
});

/// All payroll runs, newest first — backs the "Payroll Runs" history list.
final payrollRunsProvider = StreamProvider<List<PayrollRun>>(
  (ref) => ref.watch(payrollServiceProvider).runsStream(),
);

/// Per-employee records for a given run id.
final payrollRecordsProvider = StreamProvider.family<List<PayrollRecord>, String>(
  (ref, runId) => ref.watch(payrollServiceProvider).recordsStream(runId),
);

/// An employee's full payslip history across every run — feeds the Employee
/// dashboard's "Payslip History" section.
final employeePayslipsProvider = StreamProvider.family<List<PayrollRecord>, String>(
  (ref, employeeUid) => ref.watch(payrollServiceProvider).employeePayslipsStream(employeeUid),
);

/// Pre-generation eligibility preview across every `EmployeeDetails` doc —
/// backs the "who's ready / who's missing what" table shown before a run
/// exists. Not month-scoped (payroll-field completeness isn't tied to a
/// specific month) — invalidate this provider after data that affects
/// eligibility changes (e.g. right after generating a run) to refresh it.
final payrollEligibilityPreviewProvider = FutureProvider<List<PayrollEligibility>>(
  (ref) => ref.watch(payrollServiceProvider).getEligibilityPreview(),
);
