import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/hours_models.dart';
import '../screens/hr/Payroll/payroll_models.dart';
import '../screens/hr/Payroll/payroll_providers.dart';
import '../services/hours_service.dart';

/// Riverpod providers for the employee/supervisor hours workflow. Scoped to
/// this feature only, the same deliberate way Payroll's providers are —
/// the rest of the app keeps its existing StatefulWidget/setState pattern.
/// Wired in via `Consumer`/`ConsumerWidget` embedded inside otherwise
/// untouched Stateful screens (supervisor dashboard, employee dashboard).
final hoursServiceProvider = Provider<HoursService>((ref) => HoursService());

/// Currently selected hours month, as 'yyyy-MM'. Defaults to the current
/// month.
final selectedHoursMonthProvider = StateProvider<String>(
  (ref) => DateFormat('yyyy-MM').format(DateTime.now()),
);

/// Daily entries for one employee/month — backs both the employee's own
/// "My Work Hours" list and the supervisor's per-employee history view.
final dailyHoursEntriesProvider =
    StreamProvider.family<List<DailyHoursEntry>, ({String documentId, String monthKey})>(
  (ref, key) => ref.watch(hoursServiceProvider).dailyEntriesStream(key.documentId, key.monthKey),
);

/// Pending entries awaiting supervisor review. `department == null` means
/// "all departments" (Admin/HR/Accountant view).
final pendingHoursEntriesProvider = StreamProvider.family<List<DailyHoursEntry>, String?>(
  (ref, department) => ref.watch(hoursServiceProvider).pendingEntriesStream(department: department),
);

/// Live pending-entry count, for the "Review Hours" AppBar badge.
final pendingHoursCountProvider = StreamProvider.family<int, String?>(
  (ref, department) => ref.watch(hoursServiceProvider).pendingCountStream(department: department),
);

/// uid -> {fullname, email, department} roster, for resolving names in the
/// review screen's pending-entries list.
final departmentRosterProvider = FutureProvider.family<Map<String, Map<String, String>>, String?>(
  (ref, department) => ref.watch(hoursServiceProvider).departmentRoster(department: department),
);

/// Shared overtime thresholds — reads HR's Payroll settings so the number a
/// supervisor sees on the dashboard matches what Payroll will actually pay,
/// instead of a second, independently-hardcoded 8/12hr constant pair.
final hoursOvertimeThresholdsProvider = Provider<({double standardHoursPerDay, double maxHoursPerDay})>((ref) {
  final settingsAsync = ref.watch(payrollSettingsProvider);
  final settings = settingsAsync.value ?? const PayrollSettingsModel();
  return (
    standardHoursPerDay: settings.standardHoursPerDay,
    maxHoursPerDay: settings.maxHoursPerDay,
  );
});
