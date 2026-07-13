import 'package:almahub/screens/hr/Policy%20Management/company_policy_model.dart';
import 'package:almahub/screens/hr/Policy%20Management/policy_status_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:logger/logger.dart';
import 'dart:io' show File;
import 'dart:typed_data';

/// Service for managing company policies and employee policy statuses.
/// Handles CRUD for policies, file uploads, and real-time status tracking.
class PolicyService {
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

  // ── Collection References ───────────────────────────────────────────────
  CollectionReference get _policiesRef => _firestore.collection('CompanyPolicies');
  CollectionReference get _statusRef => _firestore.collection('PolicyStatus');
  Reference get _storageRef => FirebaseStorage.instance.ref().child('company_policies');

  // ═══════════════════════════════════════════════════════════════════════
  //  COMPANY POLICIES (HR Operations)
  // ═══════════════════════════════════════════════════════════════════════

  /// Stream of all active company policies ordered by upload date.
  Stream<List<CompanyPolicy>> getPoliciesStream() {
    return _policiesRef
        .where('isActive', isEqualTo: true)
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CompanyPolicy.fromMap(
                doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  /// Get all policies as a one-time fetch (for HR dashboard columns).
  Future<List<CompanyPolicy>> getAllPolicies() async {
    try {
      final snapshot = await _policiesRef
          .where('isActive', isEqualTo: true)
          .orderBy('uploadedAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => CompanyPolicy.fromMap(
              doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      _logger.e('Error fetching policies', error: e);
      return [];
    }
  }

  /// Upload a new policy document to Storage and save metadata to Firestore.
  Future<CompanyPolicy?> uploadPolicy({
    required String title,
    String? description,
    required dynamic fileData,        // File (native) or Uint8List (web)
    required String fileName,
    required String fileType,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      _logger.e('No authenticated user for policy upload');
      return null;
    }

    try {
      // 1. Upload file to Firebase Storage
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final safeFileName = '${timestamp}_${_sanitizeFileName(fileName)}';
      final fileRef = _storageRef.child(safeFileName);

      final metadata = SettableMetadata(
        contentType: _getContentType(fileType),
        customMetadata: {
          'uploadedBy': currentUser.uid,
          'policyTitle': title,
        },
      );

      UploadTask uploadTask;
      // ROOT CAUSE FIX: the old guard `kIsWeb && fileData is Uint8List` caused
      // native uploads to always throw ArgumentError after the screen was fixed
      // to send Uint8List on every platform.
      // Fix: branch purely on runtime type — Uint8List always uses putData,
      // File always uses putFile — no platform flag needed.
      if (fileData is Uint8List) {
        uploadTask = fileRef.putData(fileData, metadata);
      } else if (fileData is File) {
        uploadTask = fileRef.putFile(fileData, metadata);
      } else {
        throw ArgumentError(
          'Invalid fileData type: ${fileData.runtimeType}. '
          'Expected Uint8List (both platforms) or File (native fallback).',
        );
      }

      final snapshot = await uploadTask;
      final fileUrl = await snapshot.ref.getDownloadURL();
      _logger.i('Policy file uploaded: $fileUrl');

      // 2. Save policy metadata to Firestore
      final policy = CompanyPolicy(
        id: '',  // Will be auto-generated
        title: title,
        description: description,
        fileUrl: fileUrl,
        fileName: fileName,
        fileType: fileType,
        uploadedBy: currentUser.uid,
        uploadedAt: DateTime.now(),
        isActive: true,
      );

      final docRef = await _policiesRef.add(policy.toMap());
      _logger.i('Policy saved to Firestore: ${docRef.id}');

      return policy.copyWith(id: docRef.id);
    } catch (e, stackTrace) {
      _logger.e('Error uploading policy', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Deactivate (soft-delete) a policy.
  Future<bool> deactivatePolicy(String policyId) async {
    try {
      await _policiesRef.doc(policyId).update({'isActive': false});
      _logger.i('Policy deactivated: $policyId');
      return true;
    } catch (e) {
      _logger.e('Error deactivating policy', error: e);
      return false;
    }
  }

  /// Permanently delete a policy and its storage file.
  Future<bool> deletePolicy(CompanyPolicy policy) async {
    try {
      // Delete from Storage
      if (policy.fileUrl.isNotEmpty) {
        try {
          final ref = FirebaseStorage.instance.refFromURL(policy.fileUrl);
          await ref.delete();
        } catch (e) {
          _logger.w('Could not delete storage file', error: e);
        }
      }

      // Delete from Firestore
      await _policiesRef.doc(policy.id).delete();

      // Clean up all associated status records
      final statusDocs = await _statusRef
          .where('policyId', isEqualTo: policy.id)
          .get();
      final batch = _firestore.batch();
      for (var doc in statusDocs.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      _logger.i('Policy fully deleted: ${policy.id}');
      return true;
    } catch (e, stackTrace) {
      _logger.e('Error deleting policy', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  POLICY STATUS (Employee Operations)
  // ═══════════════════════════════════════════════════════════════════════

  /// Real-time stream of all policy statuses for a specific employee.
  /// Returns a Map policyId, PolicyStatus for easy lookup.
  Stream<Map<String, PolicyStatus>> getEmployeePolicyStatusStream(String employeeUid) {
    return _statusRef
        .where('employeeUid', isEqualTo: employeeUid)
        .snapshots()
        .map((snapshot) {
      final Map<String, PolicyStatus> result = {};
      for (var doc in snapshot.docs) {
        final status = PolicyStatus.fromMap(
            doc.data() as Map<String, dynamic>, doc.id);
        result[status.policyId] = status;
      }
      return result;
    });
  }

  /// Get all policy statuses for an employee (one-time fetch).
  Future<Map<String, PolicyStatus>> getEmployeePolicyStatuses(String employeeUid) async {
    try {
      final snapshot = await _statusRef
          .where('employeeUid', isEqualTo: employeeUid)
          .get();
      final Map<String, PolicyStatus> result = {};
      for (var doc in snapshot.docs) {
        final status = PolicyStatus.fromMap(
            doc.data() as Map<String, dynamic>, doc.id);
        result[status.policyId] = status;
      }
      return result;
    } catch (e) {
      _logger.e('Error fetching policy statuses', error: e);
      return {};
    }
  }

  /// Get all employee statuses for a specific policy (HR view).
  Stream<List<PolicyStatus>> getPolicyStatusStream(String policyId) {
    return _statusRef
        .where('policyId', isEqualTo: policyId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PolicyStatus.fromMap(
                doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  /// Initialize policy status records for a new employee.
  /// Called when a new employee is onboarded or a new policy is added.
  Future<void> initializeEmployeePolicyStatus(
    String employeeUid,
    List<String> policyIds,
  ) async {
    final batch = _firestore.batch();
    final now = DateTime.now();

    for (var policyId in policyIds) {
      final docId = PolicyStatus.generateId(employeeUid, policyId);
      final statusRef = _statusRef.doc(docId);

      // Only create if doesn't exist
      final existing = await statusRef.get();
      if (!existing.exists) {
        batch.set(statusRef, {
          'employeeUid': employeeUid,
          'policyId': policyId,
          'status': 'unread',
          'openedAt': null,
          'acceptedAt': null,
          'lastOpenedAt': null,
          'updatedAt': Timestamp.fromDate(now),
        });
      }
    }

    await batch.commit();
    _logger.i('Initialized policy statuses for employee: $employeeUid');
  }

  /// Record that an employee opened a policy document.
  /// Tracks first open and every subsequent reopen.
  Future<void> recordPolicyOpened(String employeeUid, String policyId) async {
    final docId = PolicyStatus.generateId(employeeUid, policyId);
    final docRef = _statusRef.doc(docId);
    final now = DateTime.now();

    try {
      final doc = await docRef.get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final currentStatus = data['status'] as String? ?? 'unread';

        final updates = <String, dynamic>{
          'lastOpenedAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        };

        // If first time opening, set openedAt and transition status
        if (data['openedAt'] == null) {
          updates['openedAt'] = Timestamp.fromDate(now);
          if (currentStatus == 'unread') {
            updates['status'] = 'opened';
          }
        }

        await docRef.update(updates);
      } else {
        // Create new status record if missing
        await docRef.set({
          'employeeUid': employeeUid,
          'policyId': policyId,
          'status': 'opened',
          'openedAt': Timestamp.fromDate(now),
          'acceptedAt': null,
          'lastOpenedAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        });
      }
      _logger.i('Policy opened: $policyId by $employeeUid');
    } catch (e) {
      _logger.e('Error recording policy open', error: e);
    }
  }

  /// Mark a policy as accepted (read and confirmed) by employee.
  Future<bool> markPolicyAccepted(String employeeUid, String policyId) async {
    final docId = PolicyStatus.generateId(employeeUid, policyId);
    final now = DateTime.now();

    try {
      await _statusRef.doc(docId).update({
        'status': 'accepted',
        'acceptedAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });
      _logger.i('Policy accepted: $policyId by $employeeUid');
      return true;
    } catch (e) {
      _logger.e('Error marking policy accepted', error: e);
      return false;
    }
  }

  /// Get summary statistics for HR dashboard.
  Future<Map<String, dynamic>> getPolicyStatistics(String policyId) async {
    try {
      final snapshot = await _statusRef
          .where('policyId', isEqualTo: policyId)
          .get();

      int accepted = 0;
      int opened = 0;
      int unread = 0;

      for (var doc in snapshot.docs) {
        final status = (doc.data() as Map<String, dynamic>)['status'] as String?;
        switch (status) {
          case 'accepted':
            accepted++;
            break;
          case 'opened':
            opened++;
            break;
          default:
            unread++;
        }
      }

      return {
        'total': snapshot.docs.length,
        'accepted': accepted,
        'opened': opened,
        'unread': unread,
      };
    } catch (e) {
      _logger.e('Error getting policy statistics', error: e);
      return {'total': 0, 'accepted': 0, 'opened': 0, 'unread': 0};
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _sanitizeFileName(String name) {
    return name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  }

  String _getContentType(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'txt':
        return 'text/plain';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      default:
        return 'application/octet-stream';
    }
  }
}