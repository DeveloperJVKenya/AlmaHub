import 'package:almahub/models/employee_onboarding_models.dart';
import 'package:almahub/screens/hr/onboarding_completeness.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';

import 'payroll_calculation_service.dart';
import 'payroll_models.dart';

/// Firestore-facing service for the HR Payroll module. Mirrors the shape of
/// `Policy Management/policy_service.dart`: private collection getters,
/// consistent Logger usage, and safe fallbacks instead of throwing to the UI.
class PayrollService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
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

  CollectionReference get _settingsRef => _firestore.collection('PayrollSettings');
  CollectionReference get _runsRef => _firestore.collection('PayrollRuns');
  CollectionReference get _recordsRef => _firestore.collection('PayrollRecords');

  // ═══════════════════════════════════════════════════════════════════════
  //  SETTINGS
  // ═══════════════════════════════════════════════════════════════════════

  Stream<PayrollSettingsModel> settingsStream() {
    return _settingsRef.doc('config').snapshots().map((doc) {
      if (!doc.exists) return const PayrollSettingsModel();
      return PayrollSettingsModel.fromMap(doc.data() as Map<String, dynamic>);
    });
  }

  Future<PayrollSettingsModel> getSettings() async {
    try {
      final doc = await _settingsRef.doc('config').get();
      if (!doc.exists) return const PayrollSettingsModel();
      return PayrollSettingsModel.fromMap(doc.data() as Map<String, dynamic>);
    } catch (e) {
      _logger.e('Error fetching payroll settings', error: e);
      return const PayrollSettingsModel();
    }
  }

  Future<bool> updateSettings(PayrollSettingsModel settings) async {
    try {
      final currentUser = _auth.currentUser;
      await _settingsRef.doc('config').set(
            settings.copyWith(updatedAt: DateTime.now(), updatedBy: currentUser?.uid).toMap(),
          );
      _logger.i('Payroll settings updated');
      return true;
    } catch (e) {
      _logger.e('Error updating payroll settings', error: e);
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  HR OPERATIONS — Payroll Runs & Records
  // ═══════════════════════════════════════════════════════════════════════

  Stream<PayrollRun?> runStream(String monthKey) {
    return _runsRef.doc(monthKey).snapshots().map((doc) {
      if (!doc.exists) return null;
      return PayrollRun.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    });
  }

  Future<PayrollRun?> getRun(String monthKey) async {
    try {
      final doc = await _runsRef.doc(monthKey).get();
      if (!doc.exists) return null;
      return PayrollRun.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    } catch (e) {
      _logger.e('Error fetching payroll run', error: e);
      return null;
    }
  }

  Stream<List<PayrollRun>> runsStream() {
    return _runsRef.orderBy('month', descending: true).snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => PayrollRun.fromMap(doc.data() as Map<String, dynamic>, doc.id))
              .toList(),
        );
  }

  Stream<List<PayrollRecord>> recordsStream(String runId) {
    return _recordsRef.where('runId', isEqualTo: runId).snapshots().map((snapshot) {
      final records = snapshot.docs
          .map((doc) => PayrollRecord.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      records.sort((a, b) => a.employeeName.compareTo(b.employeeName));
      return records;
    });
  }

  Future<List<PayrollRecord>> getRecords(String runId) async {
    try {
      final snapshot = await _recordsRef.where('runId', isEqualTo: runId).get();
      return snapshot.docs
          .map((doc) => PayrollRecord.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      _logger.e('Error fetching payroll records', error: e);
      return [];
    }
  }

  /// Eligibility snapshot for every `EmployeeDetails` doc, independent of any
  /// specific run — backs the Payroll screen's pre-generation preview so HR
  /// can see who's ready and who's missing what *before* generating a run,
  /// instead of an empty run being a mystery. Uses the same admin-exclusion
  /// and payroll-completeness checks as [generateRun].
  Future<List<PayrollEligibility>> getEligibilityPreview() async {
    try {
      final employeeSnapshot = await _firestore.collection('EmployeeDetails').get();
      final departmentsSnapshot = await _firestore.collection('Departments').get();
      final departmentByUid = <String, String>{};
      for (final deptDoc in departmentsSnapshot.docs) {
        final members = (deptDoc.data())['members'] as Map<String, dynamic>? ?? {};
        for (final uid in members.keys) {
          departmentByUid[uid] = deptDoc.id;
        }
      }

      final preview = <PayrollEligibility>[];
      for (final doc in employeeSnapshot.docs) {
        // Each record is isolated in its own try/catch — one malformed
        // legacy/manually-edited doc must never blank out the whole
        // preview for every other employee. A record that fails to parse
        // is still surfaced, just flagged instead of silently vanishing.
        try {
          final data = doc.data();
          final uid = (data['uid'] as String?) ?? doc.id;
          final name = data['personalInfo']?['fullName'] ?? uid;
          final isAdmin = !(await _isNotAdmin(uid));
          final payrollDetails = PayrollDetails.fromMap(
            (data['payrollDetails'] as Map<String, dynamic>?) ?? {},
          );
          preview.add(PayrollEligibility(
            uid: uid,
            employeeName: name,
            department: departmentByUid[uid] ?? '-',
            isAdmin: isAdmin,
            missingFields: isAdmin ? const [] : OnboardingCompleteness.incompletePayrollFields(payrollDetails),
          ));
        } catch (e, stackTrace) {
          _logger.e('Error parsing EmployeeDetails/${doc.id} for payroll eligibility', error: e, stackTrace: stackTrace);
          preview.add(PayrollEligibility(
            uid: doc.id,
            employeeName: doc.id,
            department: '-',
            isAdmin: false,
            missingFields: const ['Record could not be read — check this employee\'s data in EmployeeDetails'],
          ));
        }
      }
      return preview;
    } catch (e, stackTrace) {
      _logger.e('Error building payroll eligibility preview', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  /// Generates (or recomputes) the payroll run for [monthKey] ('yyyy-MM').
  /// Reads every employee from `EmployeeDetails` (excluding Admins),
  /// eligibility decided per-employee purely on payroll-field completeness
  /// (see `OnboardingCompleteness.isPayrollComplete`), independent of overall
  /// onboarding `status`. Every employee who's skipped is recorded on the
  /// resulting [PayrollRun.skippedEmployees] with a specific reason, so HR
  /// always knows exactly who was processed and who wasn't and why — not
  /// just how many. Refuses to touch a run that is no longer a draft, to
  /// protect approved/paid runs from being silently overwritten.
  Future<PayrollRun> generateRun(String monthKey) async {
    final currentUser = _auth.currentUser;
    _logger.i('=== GENERATING PAYROLL RUN: $monthKey ===');

    final existingRun = await getRun(monthKey);
    if (existingRun != null && !existingRun.isDraft) {
      throw StateError('Payroll run for $monthKey is ${existingRun.status} and cannot be regenerated.');
    }

    // Preserve any ad-hoc entries already recorded against this run.
    final existingRecords = existingRun != null ? await getRecords(monthKey) : <PayrollRecord>[];
    final existingAdhocByUid = {
      for (final r in existingRecords) r.employeeUid: r,
    };

    final settings = await getSettings();

    // All onboarding records (draft or submitted) live in EmployeeDetails —
    // eligibility for this run is decided per-employee below, purely on
    // whether their payroll details are filled in (see
    // OnboardingCompleteness.isPayrollComplete), independent of overall
    // onboarding `status`.
    final employeeSnapshot = await _firestore.collection('EmployeeDetails').get();
    final allDocs = employeeSnapshot.docs;

    final departmentsSnapshot = await _firestore.collection('Departments').get();
    final departmentByUid = <String, String>{};
    for (final deptDoc in departmentsSnapshot.docs) {
      final members = (deptDoc.data())['members'] as Map<String, dynamic>? ?? {};
      for (final uid in members.keys) {
        departmentByUid[uid] = deptDoc.id;
      }
    }

    final batch = _firestore.batch();
    int employeeCount = 0;
    double totalGross = 0;
    double totalNet = 0;
    double totalStatutory = 0;
    final skipped = <PayrollSkippedEmployee>[];

    for (final doc in allDocs) {
      final data = doc.data();
      final uid = data['uid'] as String?;
      final name = (data['personalInfo']?['fullName'] as String?) ?? doc.id;

      // Each record is isolated — one malformed doc must never abort the
      // whole run generation for every other employee.
      try {
        if (uid == null || uid.isEmpty) {
          skipped.add(PayrollSkippedEmployee(
            uid: doc.id,
            employeeName: name,
            reason: 'Record has no employee uid',
          ));
          continue;
        }
        if (!await _isNotAdmin(uid)) {
          skipped.add(PayrollSkippedEmployee(
            uid: uid,
            employeeName: name,
            reason: 'Admin account — excluded from payroll',
          ));
          continue;
        }

        // Only employees with complete payroll details (basic salary + bank
        // account) are eligible for payroll — independent of overall
        // onboarding `status`. An employee still in 'draft' who has already
        // filled in their payroll step is included; one who's 'submitted'
        // but never filled in payroll details is not.
        final payrollDetails = PayrollDetails.fromMap(
          (data['payrollDetails'] as Map<String, dynamic>?) ?? {},
        );
        final missingFields = OnboardingCompleteness.incompletePayrollFields(payrollDetails);
        if (missingFields.isNotEmpty) {
          _logger.d('Skipping $name ($uid): missing ${missingFields.join(', ')}');
          skipped.add(PayrollSkippedEmployee(
            uid: uid,
            employeeName: name,
            reason: 'Missing: ${missingFields.join(', ')}',
          ));
          continue;
        }

        final existing = existingAdhocByUid[uid];
        final record = PayrollCalculationService.buildRecord(
          runId: monthKey,
          monthKey: monthKey,
          employeeUid: uid,
          employeeData: data,
          department: departmentByUid[uid] ?? '-',
          settings: settings,
          existingAdhocAllowances: existing?.adhocAllowances,
          existingAdhocDeductions: existing?.adhocDeductions,
        );

        batch.set(_recordsRef.doc(record.id), record.toMap());
        employeeCount++;
        totalGross += record.grossPay;
        totalNet += record.netPay;
        totalStatutory += record.totalStatutoryDeductions;
      } catch (e, stackTrace) {
        _logger.e('Error processing $name ($uid) for payroll run $monthKey', error: e, stackTrace: stackTrace);
        skipped.add(PayrollSkippedEmployee(
          uid: uid ?? doc.id,
          employeeName: name,
          reason: 'Record could not be processed — check this employee\'s data in EmployeeDetails',
        ));
      }
    }

    final run = PayrollRun(
      id: monthKey,
      month: monthKey,
      status: 'draft',
      employeeCount: employeeCount,
      totalGrossPay: totalGross,
      totalNetPay: totalNet,
      totalStatutoryDeductions: totalStatutory,
      createdAt: existingRun?.createdAt ?? DateTime.now(),
      createdBy: existingRun?.createdBy ?? currentUser?.uid,
      generatedAt: DateTime.now(),
      skippedEmployees: skipped,
    );
    batch.set(_runsRef.doc(monthKey), run.toMap());

    await batch.commit();
    _logger.i(
      'Payroll run generated: $monthKey ($employeeCount processed, ${skipped.length} skipped, net KES $totalNet)',
    );
    return run;
  }

  /// Merges new ad-hoc allowance/deduction entries into a record and
  /// recomputes gross/statutory/net accordingly.
  Future<bool> updateRecordAdhocEntries(
    String recordId, {
    Map<String, double>? adhocAllowances,
    Map<String, double>? adhocDeductions,
  }) async {
    try {
      final doc = await _recordsRef.doc(recordId).get();
      if (!doc.exists) return false;
      final record = PayrollRecord.fromMap(doc.data() as Map<String, dynamic>, doc.id);

      final run = await getRun(record.runId);
      if (run != null && !run.isEditable) {
        _logger.w('Refusing to edit record $recordId: run ${run.id} is ${run.status}');
        return false;
      }

      final settings = await getSettings();
      final updated = PayrollCalculationService.recomputeWithAdhoc(
        record: record,
        settings: settings,
        adhocAllowances: adhocAllowances,
        adhocDeductions: adhocDeductions,
      );

      await _recordsRef.doc(recordId).set(updated.toMap());
      await _recomputeRunTotals(record.runId);
      _logger.i('Payroll record updated: $recordId');
      return true;
    } catch (e) {
      _logger.e('Error updating payroll record', error: e);
      return false;
    }
  }

  Future<void> _recomputeRunTotals(String runId) async {
    final records = await getRecords(runId);
    final totalGross = records.fold(0.0, (a, r) => a + r.grossPay);
    final totalNet = records.fold(0.0, (a, r) => a + r.netPay);
    final totalStatutory = records.fold(0.0, (a, r) => a + r.totalStatutoryDeductions);
    await _runsRef.doc(runId).update({
      'employeeCount': records.length,
      'totalGrossPay': totalGross,
      'totalNetPay': totalNet,
      'totalStatutoryDeductions': totalStatutory,
    });
  }

  /// Approves a draft run: locks every record + the run itself.
  Future<bool> approveRun(String runId, String approverUid) async {
    try {
      final run = await getRun(runId);
      if (run == null || !run.isDraft) {
        _logger.w('Cannot approve run $runId: not in draft status');
        return false;
      }

      final records = await getRecords(runId);
      final batch = _firestore.batch();
      for (final record in records) {
        batch.update(_recordsRef.doc(record.id), {'status': 'approved'});
      }
      batch.update(_runsRef.doc(runId), {
        'status': 'approved',
        'approvedAt': Timestamp.now(),
        'approvedBy': approverUid,
      });
      await batch.commit();
      _logger.i('Payroll run approved: $runId');
      return true;
    } catch (e) {
      _logger.e('Error approving payroll run', error: e);
      return false;
    }
  }

  /// Marks one employee's record as paid, and flips the parent run to
  /// 'paid' once every record within it has been paid.
  Future<bool> markRecordPaid(
    String recordId, {
    required String paymentMethod,
    required String transactionRef,
  }) async {
    try {
      final doc = await _recordsRef.doc(recordId).get();
      if (!doc.exists) return false;
      final record = PayrollRecord.fromMap(doc.data() as Map<String, dynamic>, doc.id);

      await _recordsRef.doc(recordId).update({
        'status': 'paid',
        'paymentMethod': paymentMethod,
        'transactionRef': transactionRef,
        'paidAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });

      final siblingRecords = await getRecords(record.runId);
      final allPaid = siblingRecords.every((r) => r.id == recordId || r.isPaid);
      if (allPaid) {
        await _runsRef.doc(record.runId).update({
          'status': 'paid',
          'paidAt': Timestamp.now(),
        });
      }

      _logger.i('Payroll record marked paid: $recordId');
      return true;
    } catch (e) {
      _logger.e('Error marking payroll record paid', error: e);
      return false;
    }
  }

  Future<bool> savePayslipUrl(String recordId, String downloadUrl) async {
    try {
      await _recordsRef.doc(recordId).update({
        'payslipUrl': downloadUrl,
        'payslipGeneratedAt': Timestamp.now(),
      });
      return true;
    } catch (e) {
      _logger.e('Error saving payslip URL', error: e);
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  EMPLOYEE OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════

  /// All of an employee's payroll records across every run, newest first.
  Stream<List<PayrollRecord>> employeePayslipsStream(String employeeUid) {
    return _recordsRef.where('employeeUid', isEqualTo: employeeUid).snapshots().map((snapshot) {
      final records = snapshot.docs
          .map((doc) => PayrollRecord.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      records.sort((a, b) => b.month.compareTo(a.month));
      return records;
    });
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  /// Mirrors the Admin-exclusion check used by the legacy Accountant
  /// dashboard, keyed off the `Users` collection role field.
  Future<bool> _isNotAdmin(String uid) async {
    try {
      final userQuery =
          await _firestore.collection('Users').where('uid', isEqualTo: uid).limit(1).get();
      if (userQuery.docs.isEmpty) return true;
      final role = userQuery.docs.first.data()['role'] as String?;
      return role != 'Admin';
    } catch (e) {
      _logger.e('Error checking admin status for $uid', error: e);
      return true;
    }
  }
}
