import 'package:cloud_firestore/cloud_firestore.dart';

/// Employee Onboarding Data Model
class EmployeeOnboarding {
  final String id;
  final String status; // draft, submitted, approved, rejected
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? submittedAt;
  
  // A. Personal Information
  final PersonalInformation personalInfo;
  
  // B. Employment Details
  final EmploymentDetails employmentDetails;
  
  // C. Statutory Documents
  final StatutoryDocuments statutoryDocs;
  
  // D. Payroll & Payment Details
  final PayrollDetails payrollDetails;
  
  // E. Academic & Professional Documents
  final AcademicDocuments academicDocs;
  
  // F. Contracts & HR Forms
  final ContractsAndForms contractsForms;
  
  // G. Benefits & Insurance
  final BenefitsInsurance benefitsInsurance;
  
  // H. Work Tools & Access
  final WorkToolsAccess workTools;
  
  EmployeeOnboarding({
    required this.id,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.submittedAt,
    required this.personalInfo,
    required this.employmentDetails,
    required this.statutoryDocs,
    required this.payrollDetails,
    required this.academicDocs,
    required this.contractsForms,
    required this.benefitsInsurance,
    required this.workTools,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'submittedAt': submittedAt != null ? Timestamp.fromDate(submittedAt!) : null,
      'personalInfo': personalInfo.toMap(),
      'employmentDetails': employmentDetails.toMap(),
      'statutoryDocs': statutoryDocs.toMap(),
      'payrollDetails': payrollDetails.toMap(),
      'academicDocs': academicDocs.toMap(),
      'contractsForms': contractsForms.toMap(),
      'benefitsInsurance': benefitsInsurance.toMap(),
      'workTools': workTools.toMap(),
    };
  }

  factory EmployeeOnboarding.fromMap(Map<String, dynamic> map) {
    return EmployeeOnboarding(
      id: map['id'] ?? '',
      status: map['status'] ?? 'draft',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: map['updatedAt'] != null ? (map['updatedAt'] as Timestamp).toDate() : null,
      submittedAt: map['submittedAt'] != null ? (map['submittedAt'] as Timestamp).toDate() : null,
      personalInfo: PersonalInformation.fromMap(map['personalInfo'] ?? {}),
      employmentDetails: EmploymentDetails.fromMap(map['employmentDetails'] ?? {}),
      statutoryDocs: StatutoryDocuments.fromMap(map['statutoryDocs'] ?? {}),
      payrollDetails: PayrollDetails.fromMap(map['payrollDetails'] ?? {}),
      academicDocs: AcademicDocuments.fromMap(map['academicDocs'] ?? {}),
      contractsForms: ContractsAndForms.fromMap(map['contractsForms'] ?? {}),
      benefitsInsurance: BenefitsInsurance.fromMap(map['benefitsInsurance'] ?? {}),
      workTools: WorkToolsAccess.fromMap(map['workTools'] ?? {}),
    );
  }
}

// A. Personal Information
class PersonalInformation {
  final String fullName;
  final String nationalIdOrPassport;
  final String? idDocumentUrl;
  final DateTime? dateOfBirth;
  final String gender;
  final String phoneNumber;
  final String email;
  final String postalAddress;
  final String physicalAddress;
  final NextOfKin nextOfKin;

  PersonalInformation({
    this.fullName = '',
    this.nationalIdOrPassport = '',
    this.idDocumentUrl,
    this.dateOfBirth,
    this.gender = '',
    this.phoneNumber = '',
    this.email = '',
    this.postalAddress = '',
    this.physicalAddress = '',
    required this.nextOfKin,
  });

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'nationalIdOrPassport': nationalIdOrPassport,
      'idDocumentUrl': idDocumentUrl,
      'dateOfBirth': dateOfBirth != null ? Timestamp.fromDate(dateOfBirth!) : null,
      'gender': gender,
      'phoneNumber': phoneNumber,
      'email': email,
      'postalAddress': postalAddress,
      'physicalAddress': physicalAddress,
      'nextOfKin': nextOfKin.toMap(),
    };
  }

  factory PersonalInformation.fromMap(Map<String, dynamic> map) {
    return PersonalInformation(
      fullName: map['fullName'] ?? '',
      nationalIdOrPassport: map['nationalIdOrPassport'] ?? '',
      idDocumentUrl: map['idDocumentUrl'],
      dateOfBirth: map['dateOfBirth'] != null ? (map['dateOfBirth'] as Timestamp).toDate() : null,
      gender: map['gender'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      email: map['email'] ?? '',
      postalAddress: map['postalAddress'] ?? '',
      physicalAddress: map['physicalAddress'] ?? '',
      nextOfKin: NextOfKin.fromMap(map['nextOfKin'] ?? {}),
    );
  }
}

class NextOfKin {
  final String name;
  final String relationship;
  final String contact;

  NextOfKin({
    this.name = '',
    this.relationship = '',
    this.contact = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'relationship': relationship,
      'contact': contact,
    };
  }

  factory NextOfKin.fromMap(Map<String, dynamic> map) {
    return NextOfKin(
      name: map['name'] ?? '',
      relationship: map['relationship'] ?? '',
      contact: map['contact'] ?? '',
    );
  }
}

// B. Employment Details
class EmploymentDetails {
  final String jobTitle;
  final String department;
  final String employmentType; // Permanent / Contract / Casual
  final DateTime? startDate;
  final String workingHours;
  final String workLocation;
  final String supervisorName;

  EmploymentDetails({
    this.jobTitle = '',
    this.department = '',
    this.employmentType = '',
    this.startDate,
    this.workingHours = '',
    this.workLocation = '',
    this.supervisorName = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'jobTitle': jobTitle,
      'department': department,
      'employmentType': employmentType,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'workingHours': workingHours,
      'workLocation': workLocation,
      'supervisorName': supervisorName,
    };
  }

  factory EmploymentDetails.fromMap(Map<String, dynamic> map) {
    return EmploymentDetails(
      jobTitle: map['jobTitle'] ?? '',
      department: map['department'] ?? '',
      employmentType: map['employmentType'] ?? '',
      startDate: map['startDate'] != null ? (map['startDate'] as Timestamp).toDate() : null,
      workingHours: map['workingHours'] ?? '',
      workLocation: map['workLocation'] ?? '',
      supervisorName: map['supervisorName'] ?? '',
    );
  }
}

// C. Mandatory Statutory Documents
class StatutoryDocuments {
  final String kraPinNumber;
  final String? kraPinCertificateUrl;
  final String nssfNumber;
  final String? nssfConfirmationUrl;
  final String shifNumber;
  final String? shifConfirmationUrl;
  final String? p9FormUrl;

  StatutoryDocuments({
    this.kraPinNumber = '',
    this.kraPinCertificateUrl,
    this.nssfNumber = '',
    this.nssfConfirmationUrl,
    this.shifNumber = '',
    this.shifConfirmationUrl,
    this.p9FormUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'kraPinNumber': kraPinNumber,
      'kraPinCertificateUrl': kraPinCertificateUrl,
      'nssfNumber': nssfNumber,
      'nssfConfirmationUrl': nssfConfirmationUrl,
      'shifNumber': shifNumber,
      'shifConfirmationUrl': shifConfirmationUrl,
      'p9FormUrl': p9FormUrl,
    };
  }

  factory StatutoryDocuments.fromMap(Map<String, dynamic> map) {
    return StatutoryDocuments(
      kraPinNumber: map['kraPinNumber'] ?? '',
      kraPinCertificateUrl: map['kraPinCertificateUrl'],
      nssfNumber: map['nssfNumber'] ?? '',
      nssfConfirmationUrl: map['nssfConfirmationUrl'],
      // NHIF was replaced by SHIF/SHA — 'nhifNumber'/'nhifConfirmationUrl'
      // are the legacy keys written before this rename; fall back to them
      // for records onboarded before the switch.
      shifNumber: map['shifNumber'] ?? map['nhifNumber'] ?? '',
      shifConfirmationUrl: map['shifConfirmationUrl'] ?? map['nhifConfirmationUrl'],
      p9FormUrl: map['p9FormUrl'],
    );
  }
}

// D. Payroll & Payment Details
class PayrollDetails {
  final double basicSalary;
  final Map<String, double> allowances; // housing, transport, other
  final Map<String, double> deductions; // loans, SACCO, advances
  final BankDetails bankDetails;
  final MpesaDetails? mpesaDetails;

  PayrollDetails({
    this.basicSalary = 0.0,
    this.allowances = const {},
    this.deductions = const {},
    this.bankDetails = const BankDetails(),
    this.mpesaDetails,
  });

  Map<String, dynamic> toMap() {
    return {
      'basicSalary': basicSalary,
      'allowances': allowances,
      'deductions': deductions,
      'bankDetails': bankDetails.toMap(),
      'mpesaDetails': mpesaDetails?.toMap(),
    };
  }

  factory PayrollDetails.fromMap(Map<String, dynamic> map) {
    return PayrollDetails(
      basicSalary: (map['basicSalary'] ?? 0.0).toDouble(),
      // Cast via `num` rather than `Map<String, double>.from(...)` directly —
      // Firestore may hand back whole-number values as `int`, and a direct
      // `.from` cast throws at runtime if any value isn't already a double.
      allowances: Map<String, double>.from(
        (map['allowances'] as Map<String, dynamic>? ?? {}).map((k, v) => MapEntry(k, (v as num).toDouble())),
      ),
      deductions: Map<String, double>.from(
        (map['deductions'] as Map<String, dynamic>? ?? {}).map((k, v) => MapEntry(k, (v as num).toDouble())),
      ),
      bankDetails: map['bankDetails'] != null ? BankDetails.fromMap(map['bankDetails']) : const BankDetails(),
      mpesaDetails: map['mpesaDetails'] != null ? MpesaDetails.fromMap(map['mpesaDetails']) : null,
    );
  }
}

class BankDetails {
  final String bankName;
  final String branchName;
  final String accountName;
  final String accountNumber;

  const BankDetails({
    this.bankName = '',
    this.branchName = '',
    this.accountName = '',
    this.accountNumber = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'bankName': bankName,
      'branchName': branchName,
      'accountName': accountName,
      'accountNumber': accountNumber,
    };
  }

  factory BankDetails.fromMap(Map<String, dynamic> map) {
    return BankDetails(
      bankName: map['bankName'] ?? '',
      // 'branch' is the legacy key written by older self-onboarding records
      // before this was unified with the HR onboarding flow's 'branchName'.
      branchName: map['branchName'] ?? map['branch'] ?? '',
      accountName: map['accountName'] ?? '',
      accountNumber: map['accountNumber'] ?? '',
    );
  }
}

class MpesaDetails {
  final String phoneNumber;
  final String name;

  MpesaDetails({
    this.phoneNumber = '',
    this.name = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'phoneNumber': phoneNumber,
      'name': name,
    };
  }

  factory MpesaDetails.fromMap(Map<String, dynamic> map) {
    return MpesaDetails(
      phoneNumber: map['phoneNumber'] ?? '',
      name: map['name'] ?? '',
    );
  }
}

// E. Academic & Professional Documents
class AcademicDocuments {
  final List<DocumentInfo> academicCertificates;
  final List<DocumentInfo> trainingCertificates;
  final List<DocumentInfo> professionalCertificates;
  final Map<String, String> professionalRegistrations; // e.g., EBK, ICPAK, IHRM

  AcademicDocuments({
    this.academicCertificates = const [],
    this.trainingCertificates = const [],
    this.professionalCertificates = const [],
    this.professionalRegistrations = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'academicCertificates': academicCertificates.map((doc) => doc.toMap()).toList(),
      'trainingCertificates': trainingCertificates.map((doc) => doc.toMap()).toList(),
      'professionalCertificates': professionalCertificates.map((doc) => doc.toMap()).toList(),
      'professionalRegistrations': professionalRegistrations,
    };
  }

  factory AcademicDocuments.fromMap(Map<String, dynamic> map) {
    return AcademicDocuments(
      academicCertificates: (map['academicCertificates'] as List<dynamic>?)
          ?.map((item) => DocumentInfo.fromMap(item))
          .toList() ?? [],
      trainingCertificates: (map['trainingCertificates'] as List<dynamic>?)
          ?.map((item) => DocumentInfo.fromMap(item))
          .toList() ?? [],
      professionalCertificates: (map['professionalCertificates'] as List<dynamic>?)
          ?.map((item) => DocumentInfo.fromMap(item))
          .toList() ?? [],
      professionalRegistrations: Map<String, String>.from(map['professionalRegistrations'] ?? {}),
    );
  }
}

class DocumentInfo {
  final String name;
  final String url;
  final String type; // pdf, image, etc.
  final DateTime uploadedAt;

  DocumentInfo({
    required this.name,
    required this.url,
    required this.type,
    required this.uploadedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'url': url,
      'type': type,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
    };
  }

  factory DocumentInfo.fromMap(Map<String, dynamic> map) {
    return DocumentInfo(
      name: map['name'] ?? '',
      url: map['url'] ?? '',
      type: map['type'] ?? '',
      uploadedAt: (map['uploadedAt'] as Timestamp).toDate(),
    );
  }
}

// F. Contracts & HR Forms
class ContractsAndForms {
  final String? employmentContractUrl;
  final String? employeeInfoFormUrl;
  final String? ndaUrl;
  final bool codeOfConductAcknowledged;
  final bool dataProtectionConsentGiven;
  final DateTime? consentDate;

  ContractsAndForms({
    this.employmentContractUrl,
    this.employeeInfoFormUrl,
    this.ndaUrl,
    this.codeOfConductAcknowledged = false,
    this.dataProtectionConsentGiven = false,
    this.consentDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'employmentContractUrl': employmentContractUrl,
      'employeeInfoFormUrl': employeeInfoFormUrl,
      'ndaUrl': ndaUrl,
      'codeOfConductAcknowledged': codeOfConductAcknowledged,
      'dataProtectionConsentGiven': dataProtectionConsentGiven,
      'consentDate': consentDate != null ? Timestamp.fromDate(consentDate!) : null,
    };
  }

  factory ContractsAndForms.fromMap(Map<String, dynamic> map) {
    return ContractsAndForms(
      employmentContractUrl: map['employmentContractUrl'],
      employeeInfoFormUrl: map['employeeInfoFormUrl'],
      ndaUrl: map['ndaUrl'],
      codeOfConductAcknowledged: map['codeOfConductAcknowledged'] ?? false,
      dataProtectionConsentGiven: map['dataProtectionConsentGiven'] ?? false,
      consentDate: map['consentDate'] != null ? (map['consentDate'] as Timestamp).toDate() : null,
    );
  }
}

// G. Benefits & Insurance
class BenefitsInsurance {
  final List<Dependant> shifDependants;
  final String? medicalInsuranceFormUrl;
  final List<Beneficiary> beneficiaries;

  BenefitsInsurance({
    this.shifDependants = const [],
    this.medicalInsuranceFormUrl,
    this.beneficiaries = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'shifDependants': shifDependants.map((d) => d.toMap()).toList(),
      'medicalInsuranceFormUrl': medicalInsuranceFormUrl,
      'beneficiaries': beneficiaries.map((b) => b.toMap()).toList(),
    };
  }

  factory BenefitsInsurance.fromMap(Map<String, dynamic> map) {
    return BenefitsInsurance(
      // 'nhifDependants' is the legacy key from before NHIF was replaced by
      // SHIF/SHA — fall back to it for records written before the rename.
      shifDependants: ((map['shifDependants'] ?? map['nhifDependants']) as List<dynamic>?)
          ?.map((item) => Dependant.fromMap(item))
          .toList() ?? [],
      medicalInsuranceFormUrl: map['medicalInsuranceFormUrl'],
      beneficiaries: (map['beneficiaries'] as List<dynamic>?)
          ?.map((item) => Beneficiary.fromMap(item))
          .toList() ?? [],
    );
  }
}

class Dependant {
  final String name;
  final String relationship;
  final DateTime? dateOfBirth;

  Dependant({
    this.name = '',
    this.relationship = '',
    this.dateOfBirth,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'relationship': relationship,
      'dateOfBirth': dateOfBirth != null ? Timestamp.fromDate(dateOfBirth!) : null,
    };
  }

  factory Dependant.fromMap(Map<String, dynamic> map) {
    return Dependant(
      name: map['name'] ?? '',
      relationship: map['relationship'] ?? '',
      dateOfBirth: map['dateOfBirth'] != null ? (map['dateOfBirth'] as Timestamp).toDate() : null,
    );
  }
}

class Beneficiary {
  final String name;
  final String relationship;
  final String contact;
  final double percentage;

  Beneficiary({
    this.name = '',
    this.relationship = '',
    this.contact = '',
    this.percentage = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'relationship': relationship,
      'contact': contact,
      'percentage': percentage,
    };
  }

  factory Beneficiary.fromMap(Map<String, dynamic> map) {
    return Beneficiary(
      name: map['name'] ?? '',
      relationship: map['relationship'] ?? '',
      contact: map['contact'] ?? '',
      percentage: (map['percentage'] ?? 0.0).toDouble(),
    );
  }
}

// H. Work Tools & Access
class WorkToolsAccess {
  final String? workEmail;
  final bool hrisProfileCreated;
  final bool systemAccessGranted;
  final List<IssuedEquipment> issuedEquipment;

  WorkToolsAccess({
    this.workEmail,
    this.hrisProfileCreated = false,
    this.systemAccessGranted = false,
    this.issuedEquipment = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'workEmail': workEmail,
      'hrisProfileCreated': hrisProfileCreated,
      'systemAccessGranted': systemAccessGranted,
      'issuedEquipment': issuedEquipment.map((e) => e.toMap()).toList(),
    };
  }

  factory WorkToolsAccess.fromMap(Map<String, dynamic> map) {
    return WorkToolsAccess(
      workEmail: map['workEmail'],
      hrisProfileCreated: map['hrisProfileCreated'] ?? false,
      systemAccessGranted: map['systemAccessGranted'] ?? false,
      issuedEquipment: (map['issuedEquipment'] as List<dynamic>?)
          ?.map((item) => IssuedEquipment.fromMap(item))
          .toList() ?? [],
    );
  }
}

class IssuedEquipment {
  final String itemName;
  final String serialNumber;
  final DateTime? issuedDate;

  IssuedEquipment({
    this.itemName = '',
    this.serialNumber = '',
    this.issuedDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'itemName': itemName,
      'serialNumber': serialNumber,
      'issuedDate': issuedDate != null ? Timestamp.fromDate(issuedDate!) : null,
    };
  }

  factory IssuedEquipment.fromMap(Map<String, dynamic> map) {
    return IssuedEquipment(
      itemName: map['itemName'] ?? '',
      serialNumber: map['serialNumber'] ?? '',
      issuedDate: map['issuedDate'] != null ? (map['issuedDate'] as Timestamp).toDate() : null,
    );
  }
}