import 'package:almahub/screens/hr/employee_onboarding_models.dart';
import 'package:almahub/screens/hr/onboarding_shared_widgets.dart';
import 'package:almahub/screens/hr/step1_personal_info.dart';
import 'package:almahub/screens/hr/step2_employment_details.dart';
import 'package:almahub/screens/hr/step3_statutory_docs.dart';
import 'package:almahub/screens/hr/step4_payroll_details.dart';
// step4 academic (now used as step 5) — same import fix needed
import 'package:almahub/screens/hr/step5_academic_docs.dart';
import 'package:almahub/screens/hr/step6_contracts_forms.dart';
import 'package:almahub/screens/hr/step7_benefits_insurance.dart';
import 'package:almahub/screens/hr/step8_work_tools.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Step metadata (ordered 0-7)
// ─────────────────────────────────────────────────────────────────────────────
const _kStepMeta = [
  _StepMeta(
    title: 'Personal Info',
    subtitle: 'Identity & next of kin',
    icon: Icons.person_rounded,
    color: Color(0xFF540478),
  ),
  _StepMeta(
    title: 'Employment',
    subtitle: 'Role, department & schedule',
    icon: Icons.work_outline_rounded,
    color: Color(0xFF7C3AED),
  ),
  _StepMeta(
    title: 'Statutory Docs',
    subtitle: 'KRA, NSSF & NHIF',
    icon: Icons.gavel_rounded,
    color: Color(0xFF0891B2),
  ),
  _StepMeta(
    title: 'Payroll Details',
    subtitle: 'Salary, allowances & bank',
    icon: Icons.account_balance_wallet_rounded,
    color: Color(0xFF16A34A),
  ),
  _StepMeta(
    title: 'Academic Docs',
    subtitle: 'Certificates & qualifications',
    icon: Icons.folder_special_rounded,
    color: Color(0xFFD97706),
  ),
  _StepMeta(
    title: 'Contracts & Forms',
    subtitle: 'Employment docs & consents',
    icon: Icons.article_rounded,
    color: Color(0xFFDC2626),
  ),
  _StepMeta(
    title: 'Benefits',
    subtitle: 'Insurance & beneficiaries',
    icon: Icons.health_and_safety_outlined,
    color: Color(0xFF0F766E),
  ),
  _StepMeta(
    title: 'Work Tools',
    subtitle: 'Email, access & equipment',
    icon: Icons.devices_rounded,
    color: Color(0xFF1D4ED8),
  ),
];

class _StepMeta {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  const _StepMeta({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

// ═════════════════════════════════════════════════════════════════════════════
// HREmployeeOnboardingScreen
// ═════════════════════════════════════════════════════════════════════════════

/// Opens the 8-step HR-driven onboarding form.
///
/// Pass [employeeId] + [initialData] when editing an existing record.
/// Pass [collectionSource] ('Draft' or 'EmployeeDetails') so the screen
/// knows which collection the record lives in when editing.
class HREmployeeOnboardingScreen extends StatefulWidget {
  final String? employeeId;
  final Map<String, dynamic>? initialData;
  final String collectionSource;

  const HREmployeeOnboardingScreen({
    super.key,
    this.employeeId,
    this.initialData,
    this.collectionSource = 'Draft',
  });

  @override
  State<HREmployeeOnboardingScreen> createState() =>
      _HREmployeeOnboardingScreenState();
}

class _HREmployeeOnboardingScreenState
    extends State<HREmployeeOnboardingScreen> {
  // ── Step state ─────────────────────────────────────────────────────────────
  int _currentStep = 0;
  final List<GlobalKey<FormState>> _formKeys =
      List.generate(8, (_) => GlobalKey<FormState>());
  final Set<int> _visitedSteps = {0};

  // ── Data models ────────────────────────────────────────────────────────────
  late PersonalInformation _personalInfo;
  late EmploymentDetails _employmentDetails;
  late StatutoryDocuments _statutoryDocs;
  late PayrollDetails _payrollDetails;
  late AcademicDocuments _academicDocs;
  late ContractsAndForms _contractsForms;
  late BenefitsInsurance _benefitsInsurance;
  late WorkToolsAccess _workTools;

  // ── Services ───────────────────────────────────────────────────────────────
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

  // ── UI state ───────────────────────────────────────────────────────────────
  String? _documentId;
  bool _isSaving = false;
  bool _isUploadingFile = false;
  List<String> _availableDepartments = [];
  bool _isLoadingDepartments = false;

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _initModels();
    if (widget.initialData != null) _loadFromMap(widget.initialData!);
    if (widget.employeeId != null) _documentId = widget.employeeId;
    _loadDepartments();
  }

  // ── Model initialisation ───────────────────────────────────────────────────
  void _initModels() {
    _personalInfo = PersonalInformation(
      fullName: '',
      nationalIdOrPassport: '',
      gender: '',
      phoneNumber: '',
      email: '',
      postalAddress: '',
      physicalAddress: '',
      nextOfKin: NextOfKin(name: '', relationship: '', contact: ''),
    );
    _employmentDetails = EmploymentDetails(
      jobTitle: '',
      department: '',
      employmentType: '',
      workingHours: '',
      workLocation: '',
      supervisorName: '',
    );
    _statutoryDocs = StatutoryDocuments(
      kraPinNumber: '',
      nssfNumber: '',
      nhifNumber: '',
    );
    _payrollDetails = PayrollDetails(
      basicSalary: 0,
      allowances: {},
      deductions: {},
      bankDetails: BankDetails(
        bankName: '',
        branchName: '',
        accountName: '',
        accountNumber: '',
      ),
    );
    _academicDocs = AcademicDocuments(
      academicCertificates: [],
      trainingCertificates: [],
      professionalCertificates: [],
      professionalRegistrations: {},
    );
    _contractsForms = ContractsAndForms(
      codeOfConductAcknowledged: false,
      dataProtectionConsentGiven: false,
    );
    _benefitsInsurance = BenefitsInsurance(
      nhifDependants: [],
      beneficiaries: [],
    );
    _workTools = WorkToolsAccess(
      workEmail: '',
      hrisProfileCreated: false,
      systemAccessGranted: false,
      issuedEquipment: [],
    );
  }

  // ── Load from Firestore map (edit mode) ────────────────────────────────────
  void _loadFromMap(Map<String, dynamic> data) {
    // Personal Info
    final pi = (data['personalInfo'] as Map<String, dynamic>?) ?? {};
    final kin = (pi['nextOfKin'] as Map<String, dynamic>?) ?? {};
    _personalInfo = PersonalInformation(
      fullName: pi['fullName'] ?? '',
      nationalIdOrPassport: pi['nationalIdOrPassport'] ?? '',
      idDocumentUrl: pi['idDocumentUrl'],
      dateOfBirth: (pi['dateOfBirth'] as Timestamp?)?.toDate(),
      gender: pi['gender'] ?? '',
      phoneNumber: pi['phoneNumber'] ?? '',
      email: pi['email'] ?? '',
      postalAddress: pi['postalAddress'] ?? '',
      physicalAddress: pi['physicalAddress'] ?? '',
      nextOfKin: NextOfKin(
        name: kin['name'] ?? '',
        relationship: kin['relationship'] ?? '',
        contact: kin['contact'] ?? '',
      ),
    );

    // Employment Details
    final ed = (data['employmentDetails'] as Map<String, dynamic>?) ?? {};
    _employmentDetails = EmploymentDetails(
      jobTitle: ed['jobTitle'] ?? '',
      department: ed['department'] ?? '',
      employmentType: ed['employmentType'] ?? '',
      startDate: (ed['startDate'] as Timestamp?)?.toDate(),
      workingHours: ed['workingHours'] ?? '',
      workLocation: ed['workLocation'] ?? '',
      supervisorName: ed['supervisorName'] ?? '',
    );

    // Statutory Docs
    final sd = (data['statutoryDocs'] as Map<String, dynamic>?) ?? {};
    _statutoryDocs = StatutoryDocuments(
      kraPinNumber: sd['kraPinNumber'] ?? '',
      kraPinCertificateUrl: sd['kraPinCertificateUrl'],
      nssfNumber: sd['nssfNumber'] ?? '',
      nssfConfirmationUrl: sd['nssfConfirmationUrl'],
      nhifNumber: sd['nhifNumber'] ?? '',
      nhifConfirmationUrl: sd['nhifConfirmationUrl'],
      p9FormUrl: sd['p9FormUrl'],
    );

    // Payroll Details
    final pd = (data['payrollDetails'] as Map<String, dynamic>?) ?? {};
    final bd = (pd['bankDetails'] as Map<String, dynamic>?) ?? {};
    _payrollDetails = PayrollDetails(
      basicSalary: (pd['basicSalary'] as num?)?.toDouble() ?? 0,
      allowances: Map<String, double>.from(
        (pd['allowances'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, (v as num).toDouble())),
      ),
      deductions: Map<String, double>.from(
        (pd['deductions'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, (v as num).toDouble())),
      ),
      bankDetails: BankDetails(
        bankName: bd['bankName'] ?? '',
        branchName: bd['branchName'] ?? '',
        accountName: bd['accountName'] ?? '',
        accountNumber: bd['accountNumber'] ?? '',
      ),
    );

    // Academic Docs
    final ad = (data['academicDocs'] as Map<String, dynamic>?) ?? {};
    _academicDocs = AcademicDocuments(
      academicCertificates: _parseDocList(ad['academicCertificates']),
      trainingCertificates: _parseDocList(ad['trainingCertificates']),
      professionalCertificates: _parseDocList(ad['professionalCertificates']),
      professionalRegistrations: Map<String, String>.from(
          (ad['professionalRegistrations'] as Map?)?.map(
                (k, v) => MapEntry(k.toString(), v?.toString() ?? ''),
              ) ??
              {}),
    );

    // Contracts & Forms
    final cf = (data['contractsForms'] as Map<String, dynamic>?) ?? {};
    _contractsForms = ContractsAndForms(
      employmentContractUrl: cf['employmentContractUrl'],
      employeeInfoFormUrl: cf['employeeInfoFormUrl'],
      ndaUrl: cf['ndaUrl'],
      codeOfConductAcknowledged: cf['codeOfConductAcknowledged'] ?? false,
      dataProtectionConsentGiven: cf['dataProtectionConsentGiven'] ?? false,
      consentDate: (cf['consentDate'] as Timestamp?)?.toDate(),
    );

    // Benefits & Insurance
    final bi = (data['benefitsInsurance'] as Map<String, dynamic>?) ?? {};
    _benefitsInsurance = BenefitsInsurance(
      nhifDependants: _parseDependants(bi['nhifDependants']),
      medicalInsuranceFormUrl: bi['medicalInsuranceFormUrl'],
      beneficiaries: _parseBeneficiaries(bi['beneficiaries']),
    );

    // Work Tools
    final wt = (data['workTools'] as Map<String, dynamic>?) ?? {};
    _workTools = WorkToolsAccess(
      workEmail: wt['workEmail'] ?? '',
      hrisProfileCreated: wt['hrisProfileCreated'] ?? false,
      systemAccessGranted: wt['systemAccessGranted'] ?? false,
      issuedEquipment: _parseEquipment(wt['issuedEquipment']),
    );
  }

  // ── Parse helpers ──────────────────────────────────────────────────────────
  List<DocumentInfo> _parseDocList(dynamic raw) {
    if (raw == null) return [];
    return (raw as List<dynamic>)
        .map((m) => DocumentInfo(
              name: m['name'] ?? '',
              url: m['url'] ?? '',
              type: m['type'] ?? 'pdf',
              uploadedAt:
                  (m['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            ))
        .toList();
  }

  List<Dependant> _parseDependants(dynamic raw) {
    if (raw == null) return [];
    return (raw as List<dynamic>)
        .map((m) => Dependant(
              name: m['name'] ?? '',
              relationship: m['relationship'] ?? '',
              dateOfBirth: (m['dateOfBirth'] as Timestamp?)?.toDate(),
            ))
        .toList();
  }

  List<Beneficiary> _parseBeneficiaries(dynamic raw) {
    if (raw == null) return [];
    return (raw as List<dynamic>)
        .map((m) => Beneficiary(
              name: m['name'] ?? '',
              relationship: m['relationship'] ?? '',
              percentage:
                  (m['percentage'] as num?)?.toDouble() ?? 0.0,
            ))
        .toList();
  }

  List<IssuedEquipment> _parseEquipment(dynamic raw) {
    if (raw == null) return [];
    return (raw as List<dynamic>)
        .map((m) => IssuedEquipment(
              itemName: m['itemName'] ?? '',
              serialNumber: m['serialNumber'] ?? '',
              issuedDate: (m['issuedDate'] as Timestamp?)?.toDate(),
            ))
        .toList();
  }

  // ── Departments ────────────────────────────────────────────────────────────
  Future<void> _loadDepartments() async {
    setState(() => _isLoadingDepartments = true);
    try {
      final snap = await _firestore.collection('Departments').get();
      final deps = snap.docs
          .map((d) => (d.data()['name'] as String?) ?? d.id)
          .where((s) => s.isNotEmpty)
          .toList()
        ..sort();
      if (mounted) setState(() => _availableDepartments = deps);
    } catch (e) {
      _logger.e('Failed to load departments', error: e);
    } finally {
      if (mounted) setState(() => _isLoadingDepartments = false);
    }
  }

  // ── File upload ────────────────────────────────────────────────────────────
  //
  // Storage path MUST match the rules:
  //   employee_documents/{employeeName}/{fieldName}/{filename}
  //
  // Content-type metadata is required because the storage rules validate
  // request.resource.contentType on every create/update operation.
  // ─────────────────────────────────────────────────────────────────────────
  String _contentTypeFromExtension(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _handleUpload(
    String fieldName,
    void Function(String url) onSuccess,
  ) async {
    try {
      // Extensions are kept in sync with the content-types allowed by the
      // storage rules (pdf · images · msword · openxmlformats-officedocument)
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) return;

      setState(() => _isUploadingFile = true);

      // Sanitise the employee name to produce a safe path segment.
      final sanitisedName = _personalInfo.fullName.isNotEmpty
          ? _personalInfo.fullName
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9]'), '_')
          : 'unknown_employee';

      final ts = DateTime.now().millisecondsSinceEpoch;

      // ✅ Path now matches the storage rule:
      //    employee_documents/{employeeName}/{fieldName}/{filename}
      final storagePath =
          'employee_documents/$sanitisedName/$fieldName/${ts}_${file.name}';

      // ✅ Explicit content-type so the rule's contentType check always passes.
      final ext = (file.extension ?? '').toLowerCase();
      final metadata = SettableMetadata(contentType: _contentTypeFromExtension(ext));

      final ref = FirebaseStorage.instance.ref(storagePath);
      await ref.putData(bytes, metadata);
      final url = await ref.getDownloadURL();

      onSuccess(url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File uploaded successfully ✓'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      _logger.e('Upload error', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingFile = false);
    }
  }

  // ── Build Firestore map ────────────────────────────────────────────────────
  Map<String, dynamic> _buildDataMap() => {
        'personalInfo': {
          'fullName': _personalInfo.fullName,
          'nationalIdOrPassport': _personalInfo.nationalIdOrPassport,
          'idDocumentUrl': _personalInfo.idDocumentUrl,
          'dateOfBirth': _personalInfo.dateOfBirth != null
              ? Timestamp.fromDate(_personalInfo.dateOfBirth!)
              : null,
          'gender': _personalInfo.gender,
          'phoneNumber': _personalInfo.phoneNumber,
          'email': _personalInfo.email,
          'postalAddress': _personalInfo.postalAddress,
          'physicalAddress': _personalInfo.physicalAddress,
          'nextOfKin': {
            'name': _personalInfo.nextOfKin.name,
            'relationship': _personalInfo.nextOfKin.relationship,
            'contact': _personalInfo.nextOfKin.contact,
          },
        },
        'employmentDetails': {
          'jobTitle': _employmentDetails.jobTitle,
          'department': _employmentDetails.department,
          'employmentType': _employmentDetails.employmentType,
          'startDate': _employmentDetails.startDate != null
              ? Timestamp.fromDate(_employmentDetails.startDate!)
              : null,
          'workingHours': _employmentDetails.workingHours,
          'workLocation': _employmentDetails.workLocation,
          'supervisorName': _employmentDetails.supervisorName,
        },
        'statutoryDocs': {
          'kraPinNumber': _statutoryDocs.kraPinNumber,
          'kraPinCertificateUrl': _statutoryDocs.kraPinCertificateUrl,
          'nssfNumber': _statutoryDocs.nssfNumber,
          'nssfConfirmationUrl': _statutoryDocs.nssfConfirmationUrl,
          'nhifNumber': _statutoryDocs.nhifNumber,
          'nhifConfirmationUrl': _statutoryDocs.nhifConfirmationUrl,
          'p9FormUrl': _statutoryDocs.p9FormUrl,
        },
        'payrollDetails': {
          'basicSalary': _payrollDetails.basicSalary,
          'allowances': _payrollDetails.allowances,
          'deductions': _payrollDetails.deductions,
          'bankDetails': {
            'bankName': _payrollDetails.bankDetails.bankName,
            'branchName': _payrollDetails.bankDetails.branchName,
            'accountName': _payrollDetails.bankDetails.accountName,
            'accountNumber': _payrollDetails.bankDetails.accountNumber,
          },
        },
        'academicDocs': {
          'academicCertificates': _academicDocs.academicCertificates
              .map((d) => _docToMap(d))
              .toList(),
          'trainingCertificates': _academicDocs.trainingCertificates
              .map((d) => _docToMap(d))
              .toList(),
          'professionalCertificates': _academicDocs.professionalCertificates
              .map((d) => _docToMap(d))
              .toList(),
          'professionalRegistrations': _academicDocs.professionalRegistrations,
        },
        'contractsForms': {
          'employmentContractUrl': _contractsForms.employmentContractUrl,
          'employeeInfoFormUrl': _contractsForms.employeeInfoFormUrl,
          'ndaUrl': _contractsForms.ndaUrl,
          'codeOfConductAcknowledged':
              _contractsForms.codeOfConductAcknowledged,
          'dataProtectionConsentGiven':
              _contractsForms.dataProtectionConsentGiven,
          'consentDate': _contractsForms.consentDate != null
              ? Timestamp.fromDate(_contractsForms.consentDate!)
              : null,
        },
        'benefitsInsurance': {
          'nhifDependants': _benefitsInsurance.nhifDependants
              .map((d) => {
                    'name': d.name,
                    'relationship': d.relationship,
                    'dateOfBirth': d.dateOfBirth != null
                        ? Timestamp.fromDate(d.dateOfBirth!)
                        : null,
                  })
              .toList(),
          'medicalInsuranceFormUrl':
              _benefitsInsurance.medicalInsuranceFormUrl,
          'beneficiaries': _benefitsInsurance.beneficiaries
              .map((b) => {
                    'name': b.name,
                    'relationship': b.relationship,
                    'percentage': b.percentage,
                  })
              .toList(),
        },
        'workTools': {
          'workEmail': _workTools.workEmail,
          'hrisProfileCreated': _workTools.hrisProfileCreated,
          'systemAccessGranted': _workTools.systemAccessGranted,
          'issuedEquipment': _workTools.issuedEquipment
              .map((e) => {
                    'itemName': e.itemName,
                    'serialNumber': e.serialNumber,
                    'issuedDate': e.issuedDate != null
                        ? Timestamp.fromDate(e.issuedDate!)
                        : null,
                  })
              .toList(),
        },
      };

  Map<String, dynamic> _docToMap(DocumentInfo d) => {
        'name': d.name,
        'url': d.url,
        'type': d.type,
        'uploadedAt': Timestamp.fromDate(d.uploadedAt),
      };

  // ── Sanitized document ID ──────────────────────────────────────────────────
  //
  // Converts the employee full name into a human-readable Firestore document ID
  // that preserves original casing and uses underscores in place of spaces.
  //
  //   "Fabron Lubanga"      → "Fabron_Lubanga"
  //   "Mary-Anne O'Brien"   → "Mary-Anne_OBrien"
  //   "  Jane   Doe  "      → "Jane_Doe"
  //
  // Falls back to a timestamp-based ID when the name field is still empty so
  // the form can still be saved at step 1 before the name has been entered.
  // ─────────────────────────────────────────────────────────────────────────
  String _buildDocumentId() {
    final name = _personalInfo.fullName.trim();
    if (name.isEmpty) {
      return 'Employee_${DateTime.now().millisecondsSinceEpoch}';
    }
    return name
        .replaceAll(RegExp(r"['\u2018\u2019\u0060]"), '') // strip apostrophes / backticks
        .replaceAll(RegExp(r'[^a-zA-Z0-9\s\-]'), '')     // remove unsafe chars (keep hyphens)
        .trim()
        .replaceAll(RegExp(r'\s+'), '_')                  // spaces  → underscores
        .replaceAll(RegExp(r'-{2,}'), '-')                // collapse consecutive hyphens
        .replaceAll(RegExp(r'_{2,}'), '_');               // collapse consecutive underscores
  }

  // ── Save Draft ─────────────────────────────────────────────────────────────
  Future<void> _saveDraft() async {
    setState(() => _isSaving = true);
    try {
      final payload = _buildDataMap()
        ..['status'] = 'draft'
        ..['updatedAt'] = FieldValue.serverTimestamp();

      // Resolve the document ID:
      //   • edit mode  → reuse the ID we already have
      //   • new record → build a sanitized name-based ID (e.g. "Fabron_Lubanga")
      final docId = _documentId ?? _buildDocumentId();

      await _firestore
          .collection('Draft')
          .doc(docId)
          .set(payload, SetOptions(merge: true));

      if (_documentId == null) {
        setState(() => _documentId = docId);
      }

      _logger.i('Draft saved: $_documentId');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.save_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Draft saved successfully'),
              ],
            ),
            backgroundColor: Color(0xFF540478),
          ),
        );
      }
    } catch (e) {
      _logger.e('Save draft error', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Submit ─────────────────────────────────────────────────────────────────
  Future<void> _submitOnboarding() async {
    // Validate the current (last) step's form first
    final isValid = _formKeys[_currentStep].currentState?.validate() ?? false;
    if (!isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete all required fields before submitting.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.send_rounded, color: Color(0xFF540478)),
            SizedBox(width: 10),
            Text('Submit Onboarding'),
          ],
        ),
        content: Text(
          'Submit the onboarding record for '
          '${_personalInfo.fullName.isNotEmpty ? _personalInfo.fullName : "this employee"}?'
          '\n\nThe record will be moved to Submitted Applications.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('Submit'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF540478),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSaving = true);
    try {
      final payload = _buildDataMap()
        ..['status'] = 'submitted'
        ..['submittedAt'] = FieldValue.serverTimestamp()
        ..['updatedAt'] = FieldValue.serverTimestamp();

      // Delete draft if it existed, then write to EmployeeDetails.
      // The EmployeeDetails document uses the same sanitized name as the
      // Draft so the record is identifiable at a glance in the console
      // (e.g. "Fabron_Lubanga" instead of a random UID).
      final employeeDocId = _buildDocumentId();

      if (_documentId != null) {
        await _firestore.collection('Draft').doc(_documentId).delete();
      }
      payload['createdAt'] = FieldValue.serverTimestamp();
      await _firestore
          .collection('EmployeeDetails')
          .doc(employeeDocId)
          .set(payload, SetOptions(merge: true));

      _logger.i('Onboarding submitted for: ${_personalInfo.fullName}');

      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF16A34A), size: 48),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Onboarding Submitted!',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_personalInfo.fullName}\'s record has been submitted '
                  'and is pending HR approval.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFF6B7280), fontSize: 14),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF540478),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pop(context); // back to dashboard
                    },
                    child: const Text('Back to Dashboard'),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      _logger.e('Submit error', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Submit failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Navigation ─────────────────────────────────────────────────────────────
  void _goToStep(int step) {
    setState(() {
      _currentStep = step;
      _visitedSteps.add(step);
    });
  }

  void _goNext() {
    if (_currentStep < 7) {
      setState(() {
        _currentStep++;
        _visitedSteps.add(_currentStep);
      });
    }
  }

  void _goPrev() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isEditing = widget.employeeId != null;
    return Scaffold(
      backgroundColor: OnboardingColors.background,
      appBar: _buildAppBar(isEditing),
      body: LayoutBuilder(
        builder: (ctx, constraints) {
          if (constraints.maxWidth >= 720) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSidebar(),
                const VerticalDivider(width: 1, color: OnboardingColors.border),
                Expanded(child: _buildStepContent()),
              ],
            );
          }
          return Column(
            children: [
              _buildCompactStepBar(),
              Expanded(child: _buildStepContent()),
            ],
          );
        },
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(bool isEditing) {
    return AppBar(
      backgroundColor: const Color(0xFF540478),
      elevation: 2,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () async {
          final leave = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Leave Onboarding?'),
              content: const Text(
                  'Unsaved changes will be lost. Save as draft first?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child:
                      const Text('Leave', style: TextStyle(color: Colors.red)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF540478)),
                  onPressed: () async {
                    Navigator.pop(ctx, false);
                    await _saveDraft();
                    if (mounted) Navigator.pop(context);
                  },
                  child: const Text('Save & Leave',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
          if (leave == true && mounted) Navigator.pop(context);
        },
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEditing ? 'Edit Employee Record' : 'Onboard New Employee',
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16),
          ),
          Text(
            'Step ${_currentStep + 1} of 8 — ${_kStepMeta[_currentStep].title}',
            style:
                TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12),
          ),
        ],
      ),
      actions: [
        // Quick-save draft
        _isSaving
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child:
                      CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                ),
              )
            : TextButton.icon(
                onPressed: _saveDraft,
                icon: const Icon(Icons.save_outlined,
                    color: Colors.white70, size: 18),
                label: const Text('Save Draft',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ),
        const SizedBox(width: 8),
      ],
    );
  }

  // ── Sidebar (≥720 px) ──────────────────────────────────────────────────────
  Widget _buildSidebar() {
    return Container(
      width: 230,
      color: Colors.white,
      child: Column(
        children: [
          // Employee name preview
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: const Color(0xFFF3E8FF),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Employee',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF540478),
                      letterSpacing: 0.5),
                ),
                const SizedBox(height: 4),
                Text(
                  _personalInfo.fullName.isNotEmpty
                      ? _personalInfo.fullName
                      : 'Not yet entered',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _personalInfo.fullName.isNotEmpty
                        ? const Color(0xFF111827)
                        : const Color(0xFF9CA3AF),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: OnboardingColors.border),

          // Step list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _kStepMeta.length,
              itemBuilder: (ctx, i) => _SidebarStepItem(
                index: i,
                meta: _kStepMeta[i],
                isCurrent: i == _currentStep,
                isVisited: _visitedSteps.contains(i),
                onTap: () => _goToStep(i),
              ),
            ),
          ),

          // Progress indicator at bottom
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: OnboardingColors.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_visitedSteps.length} of 8 visited',
                      style: const TextStyle(
                          fontSize: 11, color: OnboardingColors.textSecondary),
                    ),
                    Text(
                      '${((_visitedSteps.length / 8) * 100).round()}%',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF540478)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _visitedSteps.length / 8,
                    backgroundColor: const Color(0xFFE5E7EB),
                    color: const Color(0xFF540478),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Compact top step bar (<720 px) ─────────────────────────────────────────
  Widget _buildCompactStepBar() {
    return Container(
      height: 72,
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        itemCount: _kStepMeta.length,
        itemBuilder: (ctx, i) {
          final isCurrent = i == _currentStep;
          final isVisited = _visitedSteps.contains(i);
          final meta = _kStepMeta[i];
          return GestureDetector(
            onTap: () => _goToStep(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isCurrent
                    ? meta.color.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isCurrent ? meta.color : const Color(0xFFE5E7EB),
                  width: isCurrent ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? meta.color
                          : isVisited
                              ? meta.color.withValues(alpha: 0.15)
                              : const Color(0xFFF3F4F6),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: isVisited && !isCurrent
                          ? Icon(Icons.check_rounded,
                              size: 12,
                              color:
                                  meta.color)
                          : Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isCurrent
                                    ? Colors.white
                                    : const Color(0xFF6B7280),
                              ),
                            ),
                    ),
                  ),
                  if (isCurrent) ...[
                    const SizedBox(width: 6),
                    Text(
                      meta.title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: meta.color,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Step content ───────────────────────────────────────────────────────────
  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return Step1PersonalInfo(
          formKey: _formKeys[0],
          personalInfo: _personalInfo,
          isUploadingFile: _isUploadingFile,
          onChanged: (updated) => setState(() => _personalInfo = updated),
          onUpload: _handleUpload,
        );
      case 1:
        return Step2EmploymentDetails(
          formKey: _formKeys[1],
          employmentDetails: _employmentDetails,
          availableDepartments: _availableDepartments,
          isLoadingDepartments: _isLoadingDepartments,
          onChanged: (updated) =>
              setState(() => _employmentDetails = updated),
          onRefreshDepartments: _loadDepartments,
        );
      case 2:
        return Step3StatutoryDocs(
          formKey: _formKeys[2],
          statutoryDocs: _statutoryDocs,
          isUploadingFile: _isUploadingFile,
          onChanged: (updated) => setState(() => _statutoryDocs = updated),
          onUpload: _handleUpload,
        );
      case 3:
        // Step 4 — Payroll & Payment Details
        return Step4PayrollDetails(
          formKey: _formKeys[3],
          payrollDetails: _payrollDetails,
          onChanged: (updated) => setState(() => _payrollDetails = updated),
        );
      case 4:
        // Step 5 — Academic & Professional Documents 
        return Step5AcademicDocs(
          formKey: _formKeys[4],
          academicDocs: _academicDocs,
          isUploadingFile: _isUploadingFile,
          employeeName: _personalInfo.fullName,
          onChanged: (updated) => setState(() => _academicDocs = updated),
          onUpload: _handleUpload,
        );
      case 5:
        // Step 6 — Contracts & HR Forms 
        return Step6ContractsForms(
          formKey: _formKeys[5],
          contractsForms: _contractsForms,
          isUploadingFile: _isUploadingFile,
          onChanged: (updated) => setState(() => _contractsForms = updated),
          onUpload: _handleUpload,
        );
      case 6:
        // Step 7 — Benefits & Insurance 
        return Step7BenefitsInsurance(
          formKey: _formKeys[6],
          benefitsInsurance: _benefitsInsurance,
          isUploadingFile: _isUploadingFile,
          onChanged: (updated) =>
              setState(() => _benefitsInsurance = updated),
          onUpload: _handleUpload,
        );
      case 7:
        // Step 8 — Work Tools & System Access 
        return Step8WorkTools(
          formKey: _formKeys[7],
          workTools: _workTools,
          onChanged: (updated) => setState(() => _workTools = updated),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  // ── Bottom action bar ──────────────────────────────────────────────────────
  Widget _buildBottomBar() {
    final isFirst = _currentStep == 0;
    final isLast = _currentStep == 7;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: OnboardingColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: SafeArea(
        child: Row(
          children: [
            // Previous
            if (!isFirst)
              OutlinedButton.icon(
                onPressed: _goPrev,
                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                label: const Text('Previous'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF540478),
                  side: const BorderSide(color: Color(0xFF540478)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            if (!isFirst) const SizedBox(width: 10),

            // Save Draft (center, subtle)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isSaving ? null : _saveDraft,
                icon: _isSaving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF540478)),
                      )
                    : const Icon(Icons.save_outlined,
                        size: 16, color: Color(0xFF540478)),
                label: Text(
                  _isSaving ? 'Saving…' : 'Save Draft',
                  style: const TextStyle(color: Color(0xFF540478)),
                ),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  side: const BorderSide(
                      color: OnboardingColors.border),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Next / Submit
            ElevatedButton.icon(
              onPressed: _isSaving
                  ? null
                  : (isLast ? _submitOnboarding : _goNext),
              icon: Icon(
                isLast
                    ? Icons.send_rounded
                    : Icons.arrow_forward_rounded,
                size: 16,
              ),
              label: Text(isLast ? 'Submit' : 'Next'),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isLast ? const Color(0xFF16A34A) : const Color(0xFF540478),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sidebar Step Item
// ─────────────────────────────────────────────────────────────────────────────
class _SidebarStepItem extends StatelessWidget {
  final int index;
  final _StepMeta meta;
  final bool isCurrent;
  final bool isVisited;
  final VoidCallback onTap;

  const _SidebarStepItem({
    required this.index,
    required this.meta,
    required this.isCurrent,
    required this.isVisited,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isCurrent
            ? meta.color.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCurrent
              ? meta.color.withValues(alpha: 0.4)
              : Colors.transparent,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: ListTile(
        onTap: onTap,
        dense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isCurrent
                ? meta.color
                : isVisited
                    ? meta.color.withValues(alpha: 0.15)
                    : const Color(0xFFF3F4F6),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isVisited && !isCurrent
                ? Icon(Icons.check_rounded, size: 14, color: meta.color)
                : Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isCurrent
                          ? Colors.white
                          : const Color(0xFF6B7280),
                    ),
                  ),
          ),
        ),
        title: Text(
          meta.title,
          style: TextStyle(
            fontSize: 13,
            fontWeight:
                isCurrent ? FontWeight.w700 : FontWeight.w500,
            color: isCurrent ? meta.color : OnboardingColors.textPrimary,
          ),
        ),
        subtitle: Text(
          meta.subtitle,
          style: const TextStyle(
              fontSize: 11, color: OnboardingColors.textSecondary),
        ),
      ),
      ),
    );
  }
}