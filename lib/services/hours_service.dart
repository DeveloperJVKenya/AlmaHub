import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

import '../models/hours_models.dart';

/// Owns all Firestore IO for the employee/supervisor hours workflow:
/// employee self-submission, supervisor review (approve/reject/bulk-approve),
/// the rare supervisor manual-entry fallback, and the monthly rollup
/// (`hoursWorked`/`daysWorked`/`workQuality` maps on the parent
/// `EmployeeDetails` doc) that HR's Payroll module already reads unmodified.
///
/// The rollup only ever sums `status == 'approved'` daily entries — that's
/// the single gate between a raw hours submission and it counting toward
/// payroll. See CLAUDE.md's "Known quirks" section for the full chain.
class HoursService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
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

  CollectionReference<Map<String, dynamic>> get _employeeDetails =>
      _firestore.collection('EmployeeDetails');

  /// Finds the `EmployeeDetails` doc id for a given employee uid.
  Future<String?> findDocumentId(String uid) async {
    try {
      final query = await _employeeDetails.where('uid', isEqualTo: uid).limit(1).get();
      if (query.docs.isEmpty) return null;
      return query.docs.first.id;
    } catch (e, stackTrace) {
      _logger.e('Error finding EmployeeDetails doc for uid=$uid', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  static String _dateKey(DateTime date) => DateFormat('yyyy-MM-dd').format(date);
  static String _monthKey(DateTime date) => DateFormat('yyyy-MM').format(date);

  /// Employee submits (or resubmits after a rejection) their own hours for a
  /// day. Always lands as `pending` — a full overwrite of any prior entry
  /// for that day, which naturally clears any stale reviewer/rejection
  /// fields from a previous rejected attempt.
  Future<void> submitEmployeeEntry({
    required String uid,
    required DateTime date,
    required String entryTime,
    required String exitTime,
    required int breakMinutes,
    required double hours,
    String? note,
  }) async {
    final documentId = await findDocumentId(uid);
    if (documentId == null) {
      throw Exception('Employee record not found for uid: $uid');
    }

    final dateKey = _dateKey(date);
    final monthKey = _monthKey(date);

    _logger.i('Employee submitting hours: uid=$uid date=$dateKey hours=$hours');

    final entry = DailyHoursEntry(
      dateKey: dateKey,
      date: date,
      entryTime: entryTime,
      exitTime: exitTime,
      breakMinutes: breakMinutes,
      hours: hours,
      monthKey: monthKey,
      uid: uid,
      note: note,
      status: HoursEntryStatus.pending,
      source: HoursEntrySource.employee,
      submittedByUid: uid,
      submittedAt: DateTime.now(),
    );

    await _employeeDetails
        .doc(documentId)
        .collection('DailyHours')
        .doc(dateKey)
        .set(entry.toMap()..['submittedAt'] = FieldValue.serverTimestamp());

    await _recomputeMonthlyTotals(documentId, uid, monthKey);
  }

  /// Supervisor manual-entry fallback (e.g. employee without app access).
  /// Requires a justification [note] and is written already `approved`,
  /// since the supervisor is personally asserting it — but always tagged
  /// `source: supervisor` so it never reads as an independently-checked,
  /// self-reported entry.
  Future<void> submitSupervisorEntry({
    required String uid,
    required DateTime date,
    required String entryTime,
    required String exitTime,
    required int breakMinutes,
    required double hours,
    required String note,
    required String supervisorUid,
  }) async {
    if (note.trim().isEmpty) {
      throw Exception('A justification note is required for a manual entry.');
    }

    final documentId = await findDocumentId(uid);
    if (documentId == null) {
      throw Exception('Employee record not found for uid: $uid');
    }

    final dateKey = _dateKey(date);
    final monthKey = _monthKey(date);

    _logger.i('Supervisor manual entry: uid=$uid date=$dateKey hours=$hours by=$supervisorUid');

    final entry = DailyHoursEntry(
      dateKey: dateKey,
      date: date,
      entryTime: entryTime,
      exitTime: exitTime,
      breakMinutes: breakMinutes,
      hours: hours,
      monthKey: monthKey,
      uid: uid,
      note: note.trim(),
      status: HoursEntryStatus.approved,
      source: HoursEntrySource.supervisor,
      submittedByUid: supervisorUid,
      submittedAt: DateTime.now(),
      reviewedByUid: supervisorUid,
      reviewedAt: DateTime.now(),
    );

    await _employeeDetails.doc(documentId).collection('DailyHours').doc(dateKey).set(
      entry.toMap()
        ..['submittedAt'] = FieldValue.serverTimestamp()
        ..['reviewedAt'] = FieldValue.serverTimestamp(),
    );

    await _recomputeMonthlyTotals(documentId, uid, monthKey);
  }

  /// Approves a pending (or previously-approved, being re-confirmed) entry.
  Future<void> approveEntry({
    required String documentId,
    required String dateKey,
    required String reviewerUid,
    double? workQuality,
  }) async {
    final ref = _employeeDetails.doc(documentId).collection('DailyHours').doc(dateKey);
    final snapshot = await ref.get();
    if (!snapshot.exists) {
      throw Exception('Hours entry not found: $documentId/$dateKey');
    }
    final data = snapshot.data()!;
    final uid = data['uid'] as String;
    final monthKey = data['monthKey'] as String;

    _logger.i('Approving entry: doc=$documentId date=$dateKey by=$reviewerUid');

    await ref.update({
      'status': HoursEntryStatus.approved,
      'reviewedByUid': reviewerUid,
      'reviewedAt': FieldValue.serverTimestamp(),
      'rejectionReason': FieldValue.delete(),
      'workQuality': ?workQuality,
    });

    await _recomputeMonthlyTotals(documentId, uid, monthKey);
  }

  /// Rejects a pending entry, or re-opens a previously-approved one that
  /// turned out to be a mistake — same action either way, just requires a
  /// reason.
  Future<void> rejectEntry({
    required String documentId,
    required String dateKey,
    required String reviewerUid,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) {
      throw Exception('A rejection reason is required.');
    }

    final ref = _employeeDetails.doc(documentId).collection('DailyHours').doc(dateKey);
    final snapshot = await ref.get();
    if (!snapshot.exists) {
      throw Exception('Hours entry not found: $documentId/$dateKey');
    }
    final data = snapshot.data()!;
    final uid = data['uid'] as String;
    final monthKey = data['monthKey'] as String;

    _logger.i('Rejecting entry: doc=$documentId date=$dateKey by=$reviewerUid reason=$reason');

    await ref.update({
      'status': HoursEntryStatus.rejected,
      'reviewedByUid': reviewerUid,
      'reviewedAt': FieldValue.serverTimestamp(),
      'rejectionReason': reason.trim(),
    });

    await _recomputeMonthlyTotals(documentId, uid, monthKey);
  }

  /// Bulk-approves a batch of pending entries for a single employee doc —
  /// used by the review screen's multi-select action.
  Future<void> bulkApprove({
    required String documentId,
    required List<String> dateKeys,
    required String reviewerUid,
  }) async {
    if (dateKeys.isEmpty) return;

    _logger.i('Bulk approving ${dateKeys.length} entries in doc=$documentId by=$reviewerUid');

    final batch = _firestore.batch();
    final collection = _employeeDetails.doc(documentId).collection('DailyHours');
    for (final dateKey in dateKeys) {
      batch.update(collection.doc(dateKey), {
        'status': HoursEntryStatus.approved,
        'reviewedByUid': reviewerUid,
        'reviewedAt': FieldValue.serverTimestamp(),
        'rejectionReason': FieldValue.delete(),
      });
    }
    await batch.commit();

    // Recompute per affected month — read back the entries to know which
    // employee/months were touched (usually just one).
    final monthKeys = <String>{};
    String? uid;
    for (final dateKey in dateKeys) {
      final doc = await collection.doc(dateKey).get();
      final data = doc.data();
      if (data == null) continue;
      uid ??= data['uid'] as String?;
      monthKeys.add(data['monthKey'] as String);
    }
    if (uid != null) {
      for (final monthKey in monthKeys) {
        await _recomputeMonthlyTotals(documentId, uid, monthKey);
      }
    }
  }

  /// Recomputes `hoursWorked`/`workQuality`/`daysWorked` for [monthKey] from
  /// scratch, counting only `status == 'approved'` entries, and merges the
  /// result onto the parent `EmployeeDetails/{documentId}` doc. This is the
  /// single gate that determines what Payroll and the supervisor dashboard
  /// see as "this employee's hours this month."
  Future<void> _recomputeMonthlyTotals(String documentId, String uid, String monthKey) async {
    try {
      final dailyEntries = await _employeeDetails
          .doc(documentId)
          .collection('DailyHours')
          .where('monthKey', isEqualTo: monthKey)
          .get();

      double totalHours = 0;
      double totalQualityWeighted = 0;
      double qualityWeightedHours = 0;
      int daysWorked = 0;

      for (final doc in dailyEntries.docs) {
        final data = doc.data();
        if (data['status'] != HoursEntryStatus.approved) continue;

        final dayHours = (data['hours'] ?? 0).toDouble();
        totalHours += dayHours;
        daysWorked++;

        final quality = (data['workQuality'] as num?)?.toDouble();
        if (quality != null) {
          totalQualityWeighted += dayHours * quality;
          qualityWeightedHours += dayHours;
        }
      }

      final avgWorkQuality = qualityWeightedHours > 0
          ? totalQualityWeighted / qualityWeightedHours
          : 80.0;

      await _employeeDetails.doc(documentId).set({
        'hoursWorked': {monthKey: totalHours},
        'workQuality': {monthKey: avgWorkQuality},
        'daysWorked': {monthKey: daysWorked},
        'lastHoursUpdate': FieldValue.serverTimestamp(),
        'uid': uid,
      }, SetOptions(merge: true));

      _logger.i('Recomputed $monthKey for doc=$documentId: $totalHours hrs, $daysWorked days (approved only)');
    } catch (e, stackTrace) {
      _logger.e('Error recomputing monthly totals', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// All daily entries for one employee/month, newest first.
  Stream<List<DailyHoursEntry>> dailyEntriesStream(String documentId, String monthKey) {
    return _employeeDetails
        .doc(documentId)
        .collection('DailyHours')
        .where('monthKey', isEqualTo: monthKey)
        .snapshots()
        .map((snap) {
      final entries = snap.docs.map((d) => DailyHoursEntry.fromMap(d.data(), d.id)).toList();
      entries.sort((a, b) => b.date.compareTo(a.date));
      return entries;
    });
  }

  /// uid -> {fullname, email} roster for a department, or for every
  /// department when [department] is null (mirrors the supervisor
  /// dashboard's own all-departments aggregation).
  Future<Map<String, Map<String, String>>> departmentRoster({String? department}) async {
    final roster = <String, Map<String, String>>{};

    if (department != null) {
      final doc = await _firestore.collection('Departments').doc(department).get();
      final members = (doc.data()?['members'] as Map<String, dynamic>?) ?? {};
      for (final entry in members.entries) {
        final memberData = entry.value as Map<String, dynamic>?;
        if (memberData == null) continue;
        roster[entry.key] = {
          'fullname': memberData['fullname'] ?? memberData['fullName'] ?? 'Unknown',
          'email': memberData['email'] ?? 'Unknown',
          'department': department,
        };
      }
      return roster;
    }

    final deptSnapshot = await _firestore.collection('Departments').get();
    for (final deptDoc in deptSnapshot.docs) {
      final members = (deptDoc.data()['members'] as Map<String, dynamic>?) ?? {};
      for (final entry in members.entries) {
        final memberData = entry.value as Map<String, dynamic>?;
        if (memberData == null) continue;
        roster[entry.key] = {
          'fullname': memberData['fullname'] ?? memberData['fullName'] ?? 'Unknown',
          'email': memberData['email'] ?? 'Unknown',
          'department': deptDoc.id,
        };
      }
    }
    return roster;
  }

  /// Pending entries across a department (or every department when
  /// [department] is null), newest submission first. Uses a collectionGroup
  /// query on `DailyHours` filtered to `status == 'pending'`, then narrows
  /// client-side to the department roster — same "avoid a composite index"
  /// convention already used elsewhere in this codebase.
  Stream<List<DailyHoursEntry>> pendingEntriesStream({String? department}) async* {
    final roster = await departmentRoster(department: department);
    final allowedUids = roster.keys.toSet();

    await for (final snap in _firestore
        .collectionGroup('DailyHours')
        .where('status', isEqualTo: HoursEntryStatus.pending)
        .snapshots()) {
      final entries = snap.docs
          .map((d) => DailyHoursEntry.fromMap(d.data(), d.id))
          .where((e) => allowedUids.contains(e.uid))
          .toList()
        ..sort((a, b) => (b.submittedAt ?? b.date).compareTo(a.submittedAt ?? a.date));
      yield entries;
    }
  }

  /// Live pending-entry count for the AppBar badge.
  Stream<int> pendingCountStream({String? department}) {
    return pendingEntriesStream(department: department).map((entries) => entries.length);
  }

  /// True per-day overtime, summed — more accurate than an average-hours-
  /// per-day approximation since real daily data is now reliably available
  /// and approval-gated.
  static double computeOvertimeHours({
    required List<DailyHoursEntry> approvedEntries,
    required double standardHoursPerDay,
    required double maxHoursPerDay,
  }) {
    double total = 0;
    for (final entry in approvedEntries) {
      if (entry.hours <= standardHoursPerDay) continue;
      final cappedHours = entry.hours > maxHoursPerDay ? maxHoursPerDay : entry.hours;
      total += cappedHours - standardHoursPerDay;
    }
    return total;
  }
}
