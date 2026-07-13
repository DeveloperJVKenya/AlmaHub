import 'package:almahub/models/employee_onboarding_models.dart';
import 'package:almahub/models/user_model.dart';
import 'package:almahub/screens/employee/employee_hours_view.dart';
import 'package:almahub/screens/role_selection_screen.dart';
import 'package:almahub/screens/settings_screen.dart';
import 'package:almahub/screens/hr/hr_dashboard.dart';
import 'package:almahub/screens/supervisor/supervisor_dashboard.dart';
import 'package:almahub/screens/hr/Policy%20Management/company_policy_model.dart';
import 'package:almahub/screens/hr/Policy%20Management/policy_status_model.dart';
import 'package:almahub/screens/hr/Policy%20Management/policy_service.dart';
import 'package:almahub/screens/hr/Policy%20Management/policy_document_actions.dart';
// PolicyViewerScreen replaced by _openDocument() — same viewer approach as DrawingsScreen
// import 'package:almahub/screens/hr/Policy%20Management/policy_viewer_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;

class EmployeeDashboard extends StatefulWidget {
  final String? employeeEmail;
  const EmployeeDashboard({super.key, this.employeeEmail});
  @override
  State<EmployeeDashboard> createState() => _EmployeeDashboardState();
}

class _EmployeeDashboardState extends State<EmployeeDashboard>
    with SingleTickerProviderStateMixin {
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late AnimationController _animationController;
  StreamSubscription<DocumentSnapshot>? _roleListener;
  String? _currentUserRole;
  bool _isCheckingRole = true;
  EmployeeOnboarding? _employeeData;
  bool _isLoadingEmployee = true;
  String _activeMenuItem = 'Personal Information';
  bool _showLeaveForm = false;
  Map<String, dynamic>? _leaveBalance;
  List<QueryDocumentSnapshot> _leaveHistory = [];
  bool _isLoadingLeave = true;

  final PolicyService _policyService = PolicyService();
  List<CompanyPolicy> _policies = [];
  Map<String, PolicyStatus> _policyStatuses = {};
  bool _isLoadingPolicies = true;
  StreamSubscription? _policiesSubscription;
  StreamSubscription? _policyStatusSubscription;

  // Profile Photo
  String? _profilePhotoUrl;
  File? _profileImageFile;
  Uint8List? _profileImageBytes;
  bool _isUploadingPhoto = false;
  final ImagePicker _imagePicker = ImagePicker();

  final List<_MenuItem> _menuItems = [
    _MenuItem(
      'Personal Information',
      Icons.person_outline_rounded,
      Colors.blue,
    ),
    _MenuItem('Employment Details', Icons.work_outline_rounded, Colors.teal),
    _MenuItem(
      'Statutory & Remuneration',
      Icons.account_balance_wallet_outlined,
      Colors.purple,
    ),
    _MenuItem(
      'Academic & File Documents',
      Icons.school_outlined,
      Colors.orange,
    ),
    _MenuItem(
      'Contracts & Internal Compliance',
      Icons.gavel_outlined,
      Colors.indigo,
    ),
    _MenuItem(
      'Work Tools & System Benefits',
      Icons.card_membership_outlined,
      Colors.green,
    ),
    _MenuItem(
      'Leave Application',
      Icons.calendar_month_outlined,
      Colors.redAccent,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _logger.i(
      'EmployeeDashboard initialized with email: ${widget.employeeEmail}',
    );
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animationController.forward();
    _setupRoleListener();
    _loadEmployeeData();
    _loadLeaveData();
    _loadProfilePhoto();
    _loadPolicies();
  }

  void _loadPolicies() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      setState(() => _isLoadingPolicies = false);
      return;
    }

    // Listen to policies stream
    _policiesSubscription = _policyService.getPoliciesStream().listen(
      (policies) {
        if (!mounted) return;
        setState(() => _policies = policies);

        // Initialize status records for any new policies
        if (policies.isNotEmpty) {
          _policyService.initializeEmployeePolicyStatus(
            currentUser.uid,
            policies.map((p) => p.id).toList(),
          );
        }
      },
      onError: (e) {
        _logger.e('Error loading policies', error: e);
        if (mounted) setState(() => _isLoadingPolicies = false);
      },
    );

    // Listen to policy status stream for this employee
    _policyStatusSubscription = _policyService
        .getEmployeePolicyStatusStream(currentUser.uid)
        .listen(
      (statuses) {
        if (!mounted) return;
        setState(() {
          _policyStatuses = statuses;
          _isLoadingPolicies = false;
        });
      },
      onError: (e) {
        _logger.e('Error loading policy statuses', error: e);
        if (mounted) setState(() => _isLoadingPolicies = false);
      },
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _roleListener?.cancel();
    _logger.i('EmployeeDashboard disposed');
    _policiesSubscription?.cancel();
    _policyStatusSubscription?.cancel();
    super.dispose();
  }

  void _setupRoleListener() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      _logger.e('No authenticated user found');
      if (mounted) setState(() => _isCheckingRole = false);
      return;
    }
    try {
      _logger.i('Setting up role listener for user: ${currentUser.uid}');
      final userQuery = await _firestore
          .collection('Users')
          .where('uid', isEqualTo: currentUser.uid)
          .limit(1)
          .get();
      if (userQuery.docs.isEmpty) {
        _logger.w('User not found in Users collection');
        if (mounted) setState(() => _isCheckingRole = false);
        return;
      }
      final userDocId = userQuery.docs.first.id;
      _roleListener = _firestore
          .collection('Users')
          .doc(userDocId)
          .snapshots()
          .listen(
            (docSnapshot) {
              if (!mounted) return;
              if (!docSnapshot.exists) return;
              final userData = docSnapshot.data() as Map<String, dynamic>;
              final newRole = userData['role'] as String?;
              if (_currentUserRole != null && _currentUserRole != newRole) {
                _handleRoleChange(newRole);
              }
              if (mounted) {
                setState(() {
                  _currentUserRole = newRole;
                  _isCheckingRole = false;
                });
              }
            },
            onError: (error) {
              _logger.e('Error in role listener', error: error);
              if (mounted) setState(() => _isCheckingRole = false);
            },
          );
    } catch (e, stackTrace) {
      _logger.e(
        'Error setting up role listener',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) setState(() => _isCheckingRole = false);
    }
  }

  void _handleRoleChange(String? newRole) {
    if (newRole == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Your role has been updated to: $newRole'),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
    if (newRole == UserRoles.admin) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
          );
        }
      });
    } else if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadEmployeeData() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      if (mounted) setState(() => _isLoadingEmployee = false);
      return;
    }
    try {
      final detailsSnap = await _firestore
          .collection('EmployeeDetails')
          .where('uid', isEqualTo: currentUser.uid)
          .limit(1)
          .get();
      if (detailsSnap.docs.isNotEmpty) {
        final data = detailsSnap.docs.first.data();
        if (mounted) {
          setState(() {
            _employeeData = EmployeeOnboarding.fromMap(data);
            _isLoadingEmployee = false;
          });
        }
        return;
      }
      final draftSnap = await _firestore
          .collection('Draft')
          .where('uid', isEqualTo: currentUser.uid)
          .limit(1)
          .get();
      if (draftSnap.docs.isNotEmpty) {
        final data = draftSnap.docs.first.data();
        if (mounted) {
          setState(() {
            _employeeData = EmployeeOnboarding.fromMap(data);
            _isLoadingEmployee = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingEmployee = false);
      }
    } catch (e) {
      _logger.e('Failed to load employee data', error: e);
      if (mounted) setState(() => _isLoadingEmployee = false);
    }
  }

  Future<void> _loadLeaveData() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      if (mounted) setState(() => _isLoadingLeave = false);
      return;
    }
    try {
      final balanceDoc = await _firestore
          .collection('LeaveData')
          .doc(currentUser.uid)
          .get();
      if (balanceDoc.exists && mounted) {
        setState(() => _leaveBalance = balanceDoc.data());
      }
      final historySnap = await _firestore
          .collection('LeaveData')
          .doc(currentUser.uid)
          .collection('Applications')
          .orderBy('startDate', descending: true)
          .limit(10)
          .get();
      if (mounted) {
        setState(() {
          _leaveHistory = historySnap.docs;
          _isLoadingLeave = false;
        });
      }
    } catch (e) {
      _logger.e('Failed to load leave data', error: e);
      if (mounted) setState(() => _isLoadingLeave = false);
    }
  }

  Future<void> _loadProfilePhoto() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    try {
      final userDoc = await _firestore
          .collection('Users')
          .doc(currentUser.uid)
          .get();
      if (userDoc.exists && mounted) {
        final data = userDoc.data();
        if (data != null && data['profilePhotoUrl'] != null) {
          setState(() => _profilePhotoUrl = data['profilePhotoUrl'] as String);
        }
      }
    } catch (e) {
      _logger.e('Failed to load profile photo', error: e);
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Update Profile Photo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF54046C).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.camera_alt, color: Color(0xFF54046C)),
                ),
                title: const Text(
                  'Take Photo',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Capture with camera',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library, color: Colors.green),
                ),
                title: const Text(
                  'Choose from Gallery',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Select existing photo',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              if (_profilePhotoUrl != null)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.delete_outline, color: Colors.red),
                  ),
                  title: const Text(
                    'Remove Photo',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.red,
                    ),
                  ),
                  subtitle: const Text(
                    'Delete current profile photo',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _removeProfilePhoto();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (pickedFile == null) return;
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _profileImageBytes = bytes;
        _profileImageFile = kIsWeb ? null : File(pickedFile.path);
      });
      await _uploadProfileImage();
    } catch (e) {
      _logger.e('Failed to pick image', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to select image: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadProfileImage() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    if (_profileImageFile == null && _profileImageBytes == null) return;

    setState(() => _isUploadingPhoto = true);

    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_photos')
          .child('${currentUser.uid}.jpg');
      final metadata = SettableMetadata(contentType: 'image/jpeg');

      late TaskSnapshot snapshot;
      if (kIsWeb && _profileImageBytes != null) {
        snapshot = await storageRef.putData(_profileImageBytes!, metadata);
      } else if (_profileImageFile != null) {
        snapshot = await storageRef.putFile(_profileImageFile!, metadata);
      } else {
        throw Exception('No image data available for upload');
      }

      final downloadUrl = await snapshot.ref.getDownloadURL();
      await _firestore.collection('Users').doc(currentUser.uid).update({
        'profilePhotoUrl': downloadUrl,
      });

      if (mounted) {
        setState(() {
          _profilePhotoUrl = downloadUrl;
          _profileImageFile = null;
          _profileImageBytes = null;
          _isUploadingPhoto = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _logger.e('Failed to upload profile photo', error: e);
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload profile photo: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeProfilePhoto() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    setState(() => _isUploadingPhoto = true);

    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_photos')
          .child('${currentUser.uid}.jpg');
      await storageRef.delete();
    } catch (e) {
      _logger.w('No existing photo to delete or deletion failed', error: e);
    }

    try {
      await _firestore.collection('Users').doc(currentUser.uid).update({
        'profilePhotoUrl': FieldValue.delete(),
      });
      if (mounted) {
        setState(() {
          _profilePhotoUrl = null;
          _profileImageFile = null;
          _profileImageBytes = null;
          _isUploadingPhoto = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo removed'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      _logger.e('Failed to remove profile photo', error: e);
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _submitLeaveApplication(Map<String, dynamic> application) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    try {
      await _firestore
          .collection('LeaveData')
          .doc(currentUser.uid)
          .collection('Applications')
          .add({
            ...application,
            'status': 'pending',
            'appliedAt': FieldValue.serverTimestamp(),
            'employeeName': _employeeData?.personalInfo.fullName ?? 'Unknown',
          });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Leave application submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() => _showLeaveForm = false);
      }
      _loadLeaveData();
    } catch (e) {
      _logger.e('Failed to submit leave', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit leave request'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingRole) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F5FA),
        appBar: _buildModernAppBar(false),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF54046C)),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;
        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: const Color(0xFFF5F5FA),
          appBar: _buildModernAppBar(isDesktop),
          drawer: isDesktop ? null : _buildMobileDrawer(),
          body: isDesktop
              ? _buildDesktopBody(constraints)
              : _buildMobileBody(),
        );
      },
    );
  }

  Widget _buildDesktopBody(BoxConstraints constraints) {
    // Reserve the sidebar's own top (16) + bottom (20) margin so the
    // ConstrainedBox below reflects the height that's actually available to
    // it. On a tall monitor the menu fits comfortably inside this and no
    // scrolling is needed; on a shorter screen (smaller laptop, low-res
    // external monitor, etc.) the menu now scrolls inside the white card
    // instead of overflowing past its rounded-corner background.
    final sidebarMaxHeight = (constraints.maxHeight - 36).clamp(
      0.0,
      double.infinity,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 280,
          constraints: BoxConstraints(maxHeight: sidebarMaxHeight),
          margin: const EdgeInsets.fromLTRB(20, 16, 0, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: _buildSidebarContent(),
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await _loadEmployeeData();
              await _loadLeaveData();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(0, 16, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_currentUserRole != null &&
                      _currentUserRole != UserRoles.employee)
                    _buildRoleBadge(),
                  const SizedBox(height: 16),
                  _buildProfileHeaderCard(),
                  const SizedBox(height: 24),
                  _buildMainContentArea(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileBody() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadEmployeeData();
        await _loadLeaveData();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_currentUserRole != null &&
                _currentUserRole != UserRoles.employee)
              _buildRoleBadge(),
            const SizedBox(height: 16),
            _buildProfileHeaderCard(),
            const SizedBox(height: 24),
            _buildMainContentArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContentArea() {
    final emp = _employeeData;
    if (emp == null) return const SizedBox.shrink();

    if (_activeMenuItem == 'Leave Application') {
      return _buildLeaveApplicationSection();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: _buildSectionContent(_activeMenuItem, emp),
      ),
    );
  }

  PreferredSizeWidget _buildModernAppBar(bool isDesktop) {
    return AppBar(
      elevation: 0,
      backgroundColor: const Color(0xFF54046C),
      toolbarHeight: 70,
      automaticallyImplyLeading: false,
      leading: isDesktop
          ? null
          : IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.person_outline,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'My Profile',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  _currentUserRole != null
                      ? 'Role: $_currentUserRole'
                      : 'Employee Portal',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        _buildRolePanelButton(),
        if (_currentUserRole != null && _currentUserRole != UserRoles.admin)
          IconButton(
            icon: const Icon(Icons.access_time, color: Colors.white),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EmployeeHoursView()),
            ),
            tooltip: 'My Work Hours',
          ),
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: Colors.white),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined, color: Colors.white),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
          tooltip: 'Settings',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildRoleBadge() {
    Color badgeColor = Colors.blue;
    IconData badgeIcon = Icons.business_center;
    switch (_currentUserRole) {
      case 'Admin':
        badgeColor = Colors.amber;
        badgeIcon = Icons.admin_panel_settings;
        break;
      case 'HR':
        badgeColor = Colors.blue;
        badgeIcon = Icons.business_center;
        break;
      case 'Supervisor':
        badgeColor = Colors.green;
        badgeIcon = Icons.supervisor_account;
        break;
      case 'Accountant':
        badgeColor = Colors.orange;
        badgeIcon = Icons.account_balance_wallet;
        break;
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            badgeColor.withValues(alpha: 0.1),
            badgeColor.withValues(alpha: 0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor, width: 2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(badgeIcon, color: badgeColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_currentUserRole Access',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
                const Text(
                  'Extended system privileges enabled',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeaderCard() {
    if (_isLoadingEmployee) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final emp = _employeeData;
    if (emp == null) return _buildEmptyProfileCard();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Card(
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  GestureDetector(
                    onTap: _isUploadingPhoto ? null : _showImagePickerOptions,
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: const Color(
                        0xFF54046C,
                      ).withValues(alpha: 0.1),
                      backgroundImage: _profilePhotoUrl != null
                          ? NetworkImage(_profilePhotoUrl!)
                          : null,
                      child: _profilePhotoUrl == null
                          ? const Icon(
                              Icons.person,
                              size: 50,
                              color: Color(0xFF54046C),
                            )
                          : null,
                    ),
                  ),
                  if (_isUploadingPhoto)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF54046C),
                          ),
                        ),
                      ),
                    )
                  else
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _showImagePickerOptions,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF54046C),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                emp.personalInfo.fullName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                emp.employmentDetails.jobTitle,
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: emp.status == 'approved'
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Status: ${emp.status.toUpperCase()}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: emp.status == 'approved'
                        ? Colors.green
                        : Colors.orange,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'MENU',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[500],
              letterSpacing: 1.5,
            ),
          ),
        ),
        ..._menuItems.map((item) => _buildNavItem(item, isDrawer: false)),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildMobileDrawer() {
    return Drawer(
      child: Container(
        color: const Color(0xFFF5F5FA),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.only(
                top: 50,
                bottom: 20,
                left: 20,
                right: 20,
              ),
              color: const Color(0xFF54046C),
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.person_outline,
                    color: Colors.white,
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _employeeData?.personalInfo.fullName ?? 'Employee',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Select a section to view',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: _menuItems
                    .map((item) => _buildNavItem(item, isDrawer: true))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(_MenuItem item, {required bool isDrawer}) {
    final isSelected = _activeMenuItem == item.title;
    final Color activeColor = item.color;
    return InkWell(
      onTap: () {
        setState(() {
          _activeMenuItem = item.title;
          if (item.title != 'Leave Application') _showLeaveForm = false;
        });
        if (isDrawer) Navigator.pop(context);
      },
      child: Container(
        margin: isDrawer
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 4)
            : const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(isDrawer ? 12 : 10),
          border: isSelected && !isDrawer
              ? Border(left: BorderSide(color: activeColor, width: 3))
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? activeColor.withValues(alpha: 0.15)
                    : Colors.grey.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                item.icon,
                size: 20,
                color: isSelected ? activeColor : Colors.grey[600],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? activeColor : Colors.grey[800],
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, size: 18, color: activeColor),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionContent(String sectionId, EmployeeOnboarding emp) {
    switch (sectionId) {
      case 'Personal Information':
        return _buildPersonalInfoSection(emp);
      case 'Employment Details':
        return _buildEmploymentDetailsSection(emp);
      case 'Statutory & Remuneration':
        return _buildStatutoryRemunerationSection(emp);
      case 'Academic & File Documents':
        return _buildAcademicDocumentsSection(emp);
      case 'Contracts & Internal Compliance':
        return _buildContractsComplianceSection(emp);
      case 'Work Tools & System Benefits':
        return _buildWorkToolsBenefitsSection(emp);
      default:
        return _buildPersonalInfoSection(emp);
    }
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        border: Border(bottom: BorderSide(color: color.withValues(alpha: 0.1))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Last updated: ${DateFormat("dd MMM yyyy").format(DateTime.now())}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    Color? color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (color ?? const Color(0xFF54046C)).withValues(
                    alpha: 0.1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: color ?? const Color(0xFF54046C),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value.isEmpty ? 'Not Disclosed' : value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponsiveGrid(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width > 600 ? 2 : 1;
        final itemWidth = (width - (crossAxisCount - 1) * 16) / crossAxisCount;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: children
              .map((child) => SizedBox(width: itemWidth, child: child))
              .toList(),
        );
      },
    );
  }

  Widget _buildSubsectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey[700],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildStatusCard({
    required IconData icon,
    required String label,
    required bool status,
    required Color activeColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: status
            ? activeColor.withValues(alpha: 0.05)
            : Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: status
              ? activeColor.withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: status
                  ? activeColor.withValues(alpha: 0.15)
                  : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: status ? activeColor : Colors.grey,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  status
                      ? 'Confirmed & Verified'
                      : 'Pending Administrative Review',
                  style: TextStyle(
                    fontSize: 12,
                    color: status ? activeColor : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            status ? Icons.check_circle : Icons.pending_outlined,
            color: status ? activeColor : Colors.grey,
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(DocumentInfo doc) {
    // Infer the file type from the document name so the icon and viewer
    // routing both reflect the actual format (PDF, DOCX, XLSX, etc.).
    final fileExtension = doc.name.contains('.')
        ? doc.name.split('.').last.toLowerCase()
        : 'pdf';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              // Icon colour now matches file type (red=PDF, blue=DOCX, etc.)
              color: _getFileTypeColor(fileExtension).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _getFileTypeIcon(fileExtension),
              color: _getFileTypeColor(fileExtension),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Uploaded ${DateFormat("dd MMM yyyy").format(doc.uploadedAt)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.open_in_new, size: 18, color: Colors.grey[600]),
            tooltip: 'Open document',
            // ⚠️  Verify the URL field name on DocumentInfo.
            //     Replace `doc.url` with the actual field if it differs
            //     (common alternatives: doc.fileUrl, doc.downloadUrl).
            onPressed: () => _openDocument(doc.url, fileExtension, doc.name),
          ),
        ],
      ),
    );
  }

  Widget _buildEquipmentCard(IssuedEquipment equipment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF54046C).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.laptop_mac_rounded,
                  color: Color(0xFF54046C),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  equipment.itemName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          _buildMiniInfoRow('Serial Number', equipment.serialNumber),
          _buildMiniInfoRow(
            'Issued Date',
            equipment.issuedDate != null
                ? DateFormat("dd MMM yyyy").format(equipment.issuedDate!)
                : 'N/A',
          ),
        ],
      ),
    );
  }

  Widget _buildMiniInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoSection(EmployeeOnboarding emp) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Personal Information',
          Icons.person_outline_rounded,
          Colors.blue,
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildResponsiveGrid([
                _buildInfoCard(
                  icon: Icons.badge_outlined,
                  label: 'Full Official Name',
                  value: emp.personalInfo.fullName,
                  color: Colors.blue,
                ),
                _buildInfoCard(
                  icon: Icons.fingerprint_outlined,
                  label: 'National ID / Passport',
                  value: emp.personalInfo.nationalIdOrPassport,
                  color: Colors.blue,
                ),
                _buildInfoCard(
                  icon: Icons.cake_outlined,
                  label: 'Date of Birth',
                  value: emp.personalInfo.dateOfBirth != null
                      ? DateFormat(
                          "dd MMMM yyyy",
                        ).format(emp.personalInfo.dateOfBirth!)
                      : 'N/A',
                  color: Colors.blue,
                ),
                _buildInfoCard(
                  icon: Icons.wc_outlined,
                  label: 'Gender',
                  value: emp.personalInfo.gender,
                  color: Colors.blue,
                ),
                _buildInfoCard(
                  icon: Icons.phone_outlined,
                  label: 'Primary Phone',
                  value: emp.personalInfo.phoneNumber,
                  color: Colors.blue,
                ),
                _buildInfoCard(
                  icon: Icons.alternate_email_outlined,
                  label: 'Personal Email',
                  value: emp.personalInfo.email,
                  color: Colors.blue,
                ),
                _buildInfoCard(
                  icon: Icons.mark_as_unread_outlined,
                  label: 'Postal Address',
                  value: emp.personalInfo.postalAddress,
                  color: Colors.blue,
                ),
                _buildInfoCard(
                  icon: Icons.home_outlined,
                  label: 'Physical Address',
                  value: emp.personalInfo.physicalAddress,
                  color: Colors.blue,
                ),
              ]),
              const SizedBox(height: 24),
              _buildSubsectionTitle('Next of Kin / Emergency Contact'),
              _buildResponsiveGrid([
                _buildInfoCard(
                  icon: Icons.person_pin_outlined,
                  label: 'Kin Name',
                  value: emp.personalInfo.nextOfKin.name,
                  color: Colors.red,
                ),
                _buildInfoCard(
                  icon: Icons.family_restroom_outlined,
                  label: 'Relationship',
                  value: emp.personalInfo.nextOfKin.relationship,
                  color: Colors.red,
                ),
                _buildInfoCard(
                  icon: Icons.phone_callback_outlined,
                  label: 'Emergency Phone',
                  value: emp.personalInfo.nextOfKin.contact,
                  color: Colors.red,
                ),
              ]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmploymentDetailsSection(EmployeeOnboarding emp) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Employment Details',
          Icons.work_outline_rounded,
          Colors.teal,
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: _buildResponsiveGrid([
            _buildInfoCard(
              icon: Icons.assignment_ind_outlined,
              label: 'Official Job Title',
              value: emp.employmentDetails.jobTitle,
              color: Colors.teal,
            ),
            _buildInfoCard(
              icon: Icons.lan_outlined,
              label: 'Business Department',
              value: emp.employmentDetails.department,
              color: Colors.teal,
            ),
            _buildInfoCard(
              icon: Icons.layers_outlined,
              label: 'Employment Category',
              value: emp.employmentDetails.employmentType,
              color: Colors.teal,
            ),
            _buildInfoCard(
              icon: Icons.calendar_month_outlined,
              label: 'Commencement Date',
              value: emp.employmentDetails.startDate != null
                  ? DateFormat(
                      "dd MMM yyyy",
                    ).format(emp.employmentDetails.startDate!)
                  : 'N/A',
              color: Colors.teal,
            ),
            _buildInfoCard(
              icon: Icons.more_time_rounded,
              label: 'Working Hours Structure',
              value: emp.employmentDetails.workingHours,
              color: Colors.teal,
            ),
            _buildInfoCard(
              icon: Icons.location_on_outlined,
              label: 'Assigned Office Location',
              value: emp.employmentDetails.workLocation,
              color: Colors.teal,
            ),
            _buildInfoCard(
              icon: Icons.supervisor_account_outlined,
              label: 'Reporting Supervisor',
              value: emp.employmentDetails.supervisorName,
              color: Colors.teal,
            ),
          ]),
        ),
      ],
    );
  }

  Widget _buildStatutoryRemunerationSection(EmployeeOnboarding emp) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Statutory & Remuneration Structure',
          Icons.account_balance_wallet_outlined,
          Colors.purple,
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSubsectionTitle('Statutory Registration Numbers'),
              _buildResponsiveGrid([
                _buildInfoCard(
                  icon: Icons.article_outlined,
                  label: 'KRA PIN Registration',
                  value: emp.statutoryDocs.kraPinNumber,
                  color: Colors.purple,
                ),
                _buildInfoCard(
                  icon: Icons.shield_outlined,
                  label: 'NSSF Identification',
                  value: emp.statutoryDocs.nssfNumber,
                  color: Colors.purple,
                ),
                _buildInfoCard(
                  icon: Icons.local_hospital_outlined,
                  label: 'NHIF Identification',
                  value: emp.statutoryDocs.nhifNumber,
                  color: Colors.purple,
                ),
              ]),
              const SizedBox(height: 24),
              _buildSubsectionTitle('Remuneration & Bank Channels'),
              _buildResponsiveGrid([
                _buildInfoCard(
                  icon: Icons.payments_outlined,
                  label: 'Basic Base Gross Salary',
                  value:
                      'KES ${emp.payrollDetails.basicSalary.toStringAsFixed(2)}',
                  color: Colors.green,
                ),
                _buildInfoCard(
                  icon: Icons.account_balance_rounded,
                  label: 'Bank Entity Affiliation',
                  value: emp.payrollDetails.bankDetails?.bankName ?? 'N/A',
                  color: Colors.green,
                ),
                _buildInfoCard(
                  icon: Icons.credit_card_outlined,
                  label: 'Account Destination Number',
                  value: emp.payrollDetails.bankDetails?.accountNumber ?? 'N/A',
                  color: Colors.green,
                ),
                if (emp.payrollDetails.mpesaDetails != null) ...[
                  _buildInfoCard(
                    icon: Icons.phone_iphone_outlined,
                    label: 'Mobile Money Phone',
                    value: emp.payrollDetails.mpesaDetails!.phoneNumber,
                    color: Colors.green,
                  ),
                  _buildInfoCard(
                    icon: Icons.person_pin_rounded,
                    label: 'Mobile Money Registered Name',
                    value: emp.payrollDetails.mpesaDetails!.name,
                    color: Colors.green,
                  ),
                ],
              ]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAcademicDocumentsSection(EmployeeOnboarding emp) {
    final hasDocs =
        emp.academicDocs.academicCertificates.isNotEmpty ||
        emp.academicDocs.professionalCertificates.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Academic & File Documents',
          Icons.school_outlined,
          Colors.orange,
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!hasDocs)
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.folder_open_outlined,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No file registries uploaded',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Contact HR to upload your academic and professional documents',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (emp.academicDocs.academicCertificates.isNotEmpty) ...[
                _buildSubsectionTitle('Academic Degrees & Credentials'),
                ...emp.academicDocs.academicCertificates.map(
                  (doc) => _buildDocumentCard(doc),
                ),
              ],
              if (emp.academicDocs.professionalCertificates.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildSubsectionTitle(
                  'Professional Affiliations / Body Credentials',
                ),
                ...emp.academicDocs.professionalCertificates.map(
                  (doc) => _buildDocumentCard(doc),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContractsComplianceSection(EmployeeOnboarding emp) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Contracts & Internal Compliance', Icons.gavel_outlined, Colors.indigo),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Existing compliance cards
              _buildResponsiveGrid([
                _buildStatusCard(
                  icon: Icons.fact_check_outlined,
                  label: 'Company Code of Conduct Signed',
                  status: emp.contractsForms.codeOfConductAcknowledged,
                  activeColor: Colors.indigo,
                ),
                _buildStatusCard(
                  icon: Icons.security_outlined,
                  label: 'Data Protection Consent Signed',
                  status: emp.contractsForms.dataProtectionConsentGiven,
                  activeColor: Colors.indigo,
                ),
              ]),
              const SizedBox(height: 20),
              _buildInfoCard(
                icon: Icons.history_toggle_off_rounded,
                label: 'Compliance Timeline Clock',
                value: emp.contractsForms.consentDate != null
                    ? DateFormat("dd MMM yyyy HH:mm").format(emp.contractsForms.consentDate!)
                    : 'N/A',
                color: Colors.indigo,
              ),

              // ═══════════════════════════════════════════════════════════════
              //  NEW: Company Policies Section
              // ═══════════════════════════════════════════════════════════════
              const SizedBox(height: 32),
              _buildSubsectionTitle('Company Policies & HR Documents'),
              const SizedBox(height: 4),
              Text(
                'Please read and acknowledge the following policies. Tap on a policy to view it.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              _buildPoliciesList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPoliciesList() {
    if (_isLoadingPolicies) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: Color(0xFF54046C)),
        ),
      );
    }

    if (_policies.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha:0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.policy_outlined, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                'No company policies available',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                'Policies will appear here once HR uploads them.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: _policies.map((policy) => _buildPolicyCard(policy)).toList(),
    );
  }

  Widget _buildPolicyCard(CompanyPolicy policy) {
    final status = _policyStatuses[policy.id];
    final isAccepted = status?.isAccepted ?? false;
    final isOpened = status?.isOpened ?? false;
    final isUnread = status?.isUnread ?? true;

    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (isAccepted) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = 'Accepted';
    } else if (isOpened) {
      statusColor = Colors.orange;
      statusIcon = Icons.visibility;
      statusText = 'Opened - Awaiting Confirmation';
    } else {
      statusColor = Colors.grey;
      statusIcon = Icons.circle_outlined;
      statusText = 'Not Read';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAccepted ? Colors.green.withValues(alpha:0.3) : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _getFileTypeColor(policy.fileType).withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _getFileTypeIcon(policy.fileType),
                color: _getFileTypeColor(policy.fileType),
                size: 22,
              ),
            ),
            title: Text(
              policy.title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  policy.fileName,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha:0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 12, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (status?.lastOpenedAt != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        'Last opened: ${DateFormat("dd MMM yyyy").format(status!.lastOpenedAt!)}',
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => _openPolicy(policy),
          ),
          // Action buttons
          if (isOpened || isUnread)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openPolicy(policy),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('Read Policy'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF54046C),
                        side: const BorderSide(color: Color(0xFF54046C)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  if (isOpened) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _markPolicyAccepted(policy),
                        icon: const Icon(Icons.check_circle, size: 16),
                        label: const Text('Mark as Read & Accepted'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _openPolicy(CompanyPolicy policy) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    // Mark the policy as "opened" so the status badge updates in real-time
    // via the existing Firestore stream. recordPolicyOpened() handles both
    // first-open (sets openedAt, transitions 'unread' → 'opened') and
    // subsequent reopens (updates lastOpenedAt only).
    try {
      await _policyService.recordPolicyOpened(currentUser.uid, policy.id);
    } catch (e) {
      _logger.w('Could not update policy opened status: $e');
    }

    // Open with the cross-platform viewer (Microsoft Office Online on web for
    // Office files; direct URL for PDF/images; cache + OS app on native).
    await _openDocument(
      policy.fileUrl,   // confirmed: CompanyPolicy.fileUrl (Firebase Storage URL)
      policy.fileType,
      policy.fileName,
    );

    _logger.i('Policy opened: ${policy.title}');
  }

  Future<void> _markPolicyAccepted(CompanyPolicy policy) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.verified_user, color: Colors.green),
            SizedBox(width: 10),
            Expanded(child: Text('Confirm Policy Acceptance')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'By confirming, you acknowledge that you have read and understood:',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF54046C).withValues(alpha:0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.policy, color: Color(0xFF54046C), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      policy.title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha:0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha:0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action is recorded and visible to HR. Ensure you have fully read the document before confirming.',
                      style: TextStyle(color: Colors.blue, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.check, size: 18),
            label: const Text('I Have Read & Accept'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await _policyService.markPolicyAccepted(
      currentUser.uid,
      policy.id,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${policy.title} marked as read and accepted.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // ── Cross-platform document opener ────────────────────────────────────
  //
  // The actual open/viewer/fallback strategy now lives in
  // PolicyDocumentActions (Policy Management/policy_document_actions.dart)
  // so it is shared — and stays in sync — with the HR Policy Management
  // screen. See that file's class doc comment for the root-cause
  // explanation of why Word/Excel/PowerPoint policies previously failed
  // to open while PDFs worked fine, and how the fix + automatic browser
  // fallback resolves it on every platform.
  Future<void> _openDocument(
    String url,
    String fileType,
    String fileName,
  ) {
    return PolicyDocumentActions.openDocument(
      context: context,
      url: url,
      fileType: fileType,
      fileName: fileName,
    );
  }

  // Helper methods for file type icons/colors
  Color _getFileTypeColor(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf': return Colors.red;
      case 'doc':
      case 'docx': return Colors.blue;
      case 'xls':
      case 'xlsx': return Colors.green;
      case 'ppt':
      case 'pptx': return Colors.orange;
      case 'txt': return Colors.grey;
      default: return const Color(0xFF54046C);
    }
  }

  IconData _getFileTypeIcon(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf': return Icons.picture_as_pdf;
      case 'doc':
      case 'docx': return Icons.description;
      case 'xls':
      case 'xlsx': return Icons.table_chart;
      case 'ppt':
      case 'pptx': return Icons.slideshow;
      case 'txt': return Icons.text_snippet;
      default: return Icons.insert_drive_file;
    }
  }

  Widget _buildWorkToolsBenefitsSection(EmployeeOnboarding emp) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Work Tools & System Benefits',
          Icons.card_membership_outlined,
          Colors.green,
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildResponsiveGrid([
                _buildInfoCard(
                  icon: Icons.mark_as_unread_outlined,
                  label: 'Assigned Enterprise Work Email',
                  value: emp.workTools.workEmail ?? 'Pending Provisioning',
                  color: Colors.green,
                ),
              ]),
              const SizedBox(height: 16),
              _buildResponsiveGrid([
                _buildStatusCard(
                  icon: Icons.assignment_turned_in_outlined,
                  label: 'HRIS Cloud Profile Maintained',
                  status: emp.workTools.hrisProfileCreated,
                  activeColor: Colors.green,
                ),
                _buildStatusCard(
                  icon: Icons.vpn_key_outlined,
                  label: 'Workspace Core Master System Access',
                  status: emp.workTools.systemAccessGranted,
                  activeColor: Colors.green,
                ),
              ]),
              if (emp.workTools.issuedEquipment.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildSubsectionTitle('Assigned Hardware Device Inventories'),
                ...emp.workTools.issuedEquipment.map(
                  (equipment) => _buildEquipmentCard(equipment),
                ),
              ],
              if (emp.benefitsInsurance.beneficiaries.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildSubsectionTitle(
                  'Listed Insurance Policy Premium Beneficiaries',
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: emp.benefitsInsurance.beneficiaries.map((b) {
                    return Chip(
                      avatar: const Icon(Icons.person_pin_rounded, size: 18),
                      label: Text('${b.name} (${b.relationship})'),
                      backgroundColor: Colors.green.withValues(alpha: 0.1),
                      side: BorderSide(
                        color: Colors.green.withValues(alpha: 0.3),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLeaveApplicationSection() {
    final balance = _leaveBalance ?? {};
    final annualUsed = (balance['annualUsed'] as num?)?.toInt() ?? 0;
    final annualRemaining = 21 - annualUsed;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLeaveBalanceCards(),
          const SizedBox(height: 24),
          if (!_showLeaveForm)
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FloatingActionButton.extended(
                onPressed: () => setState(() => _showLeaveForm = true),
                icon: const Icon(Icons.add_circle_outline, size: 28),
                label: const Text(
                  'Apply Leave',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                backgroundColor: const Color(0xFF54046C),
                foregroundColor: Colors.white,
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          if (_showLeaveForm) ...[
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(
                      'Leave Application',
                      Icons.edit_calendar_outlined,
                      Colors.redAccent,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: LeaveApplicationForm(
                        showDragHandle: false,
                        remainingAnnualDays: annualRemaining,
                        onCancel: () => setState(() => _showLeaveForm = false),
                        onSubmit: (application) async {
                          await _submitLeaveApplication(application);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          _buildLeaveHistorySection(),
        ],
      ),
    );
  }

  Widget _buildLeaveBalanceCards() {
    final balance = _leaveBalance ?? {};
    return Row(
      children: [
        Expanded(
          child: _buildLeaveStatCard(
            title: "Annual Leave",
            used: (balance['annualUsed'] as num?)?.toInt() ?? 0,
            total: 21,
            color: Colors.teal,
            icon: Icons.beach_access,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildLeaveStatCard(
            title: "Sick Leave",
            used: (balance['sickUsed'] as num?)?.toInt() ?? 0,
            total: 7,
            color: Colors.orange,
            icon: Icons.medical_services,
          ),
        ),
      ],
    );
  }

  Widget _buildLeaveStatCard({
    required String title,
    required int used,
    required int total,
    required Color color,
    required IconData icon,
  }) {
    final remaining = total - used;
    final percentage = total > 0 ? (used / total).clamp(0.0, 1.0) : 0.0;
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              '$used / $total used',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$remaining days left',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: remaining > 3 ? color : Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: percentage,
              backgroundColor: Colors.grey[200],
              color: color,
              minHeight: 6,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Recent Leave Applications',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        if (_isLoadingLeave) const Center(child: CircularProgressIndicator()),
        if (!_isLoadingLeave && _leaveHistory.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'No leave applications yet',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
        if (_leaveHistory.isNotEmpty)
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _leaveHistory.length,
            itemBuilder: (context, index) {
              final data = _leaveHistory[index].data() as Map<String, dynamic>;
              return _buildLeaveHistoryCard(data);
            },
          ),
      ],
    );
  }

  Widget _buildLeaveHistoryCard(Map<String, dynamic> data) {
    final type = data['leaveType'] ?? '';
    final start = (data['startDate'] as Timestamp?)?.toDate();
    final end = (data['endDate'] as Timestamp?)?.toDate();
    final status = data['status'] ?? 'pending';
    Color statusColor = Colors.orange;
    if (status == 'approved') statusColor = Colors.green;
    if (status == 'rejected') statusColor = Colors.red;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: statusColor.withValues(alpha: 0.1),
            child: Icon(
              type.toLowerCase().contains('annual')
                  ? Icons.beach_access
                  : Icons.medical_services,
              color: statusColor,
            ),
          ),
          title: Text(
            type,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            start != null && end != null
                ? '${DateFormat("dd MMM").format(start)} - ${DateFormat("dd MMM yyyy").format(end)}'
                : 'No dates',
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyProfileCard() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: const [
              Icon(Icons.person_off, size: 80, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Profile Not Found',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                'Contact HR to complete your onboarding',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRolePanelButton() {
    if (_currentUserRole == null || _currentUserRole == UserRoles.employee) {
      return const SizedBox.shrink();
    }
    IconData icon;
    Color iconColor;
    String tooltip;
    VoidCallback onPressed;
    switch (_currentUserRole) {
      case UserRoles.admin:
        icon = Icons.admin_panel_settings;
        iconColor = Colors.amber;
        tooltip = 'Admin Panel';
        onPressed = () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
        );
        break;
      case UserRoles.hr:
        icon = Icons.business_center;
        iconColor = Colors.blue;
        tooltip = 'HR Dashboard';
        onPressed = () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HRDashboard()),
        );
        break;
      case UserRoles.accountant:
        icon = Icons.account_balance_wallet;
        iconColor = Colors.orange;
        tooltip = 'Accountant Dashboard';
        onPressed = () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Accountant Dashboard coming soon!'),
            backgroundColor: Colors.orange,
          ),
        );
        break;
      case UserRoles.supervisor:
        icon = Icons.supervisor_account;
        iconColor = Colors.green;
        tooltip = 'Supervisor Dashboard';
        onPressed = () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SupervisorDashboard()),
        );
        break;
      default:
        return const SizedBox.shrink();
    }
    return IconButton(
      icon: Icon(icon, color: iconColor),
      onPressed: onPressed,
      tooltip: tooltip,
    );
  }
}

class _MenuItem {
  final String title;
  final IconData icon;
  final Color color;
  _MenuItem(this.title, this.icon, this.color);
}

class LeaveApplicationForm extends StatefulWidget {
  final Function(Map<String, dynamic>) onSubmit;
  final VoidCallback? onCancel;
  final bool showDragHandle;
  final int remainingAnnualDays;

  const LeaveApplicationForm({
    super.key,
    required this.onSubmit,
    this.onCancel,
    this.showDragHandle = true,
    this.remainingAnnualDays = 21,
  });

  @override
  State<LeaveApplicationForm> createState() => _LeaveApplicationFormState();
}

class _LeaveApplicationFormState extends State<LeaveApplicationForm> {
  final List<String> _leaveTypes = [
    'Annual Leave',
    'Sick Leave (Medical/Maternity)',
    'Compassionate & Bereavement',
    'Maternity Leave',
    'Paternity Leave',
  ];

  late FormGroup form;

  @override
  void initState() {
    super.initState();
    form = fb.group(
      {
        'leaveType': FormControl<String>(
          value: 'Annual Leave',
          validators: [Validators.required],
        ),
        'startDate': FormControl<DateTime>(validators: [Validators.required]),
        'endDate': FormControl<DateTime>(validators: [Validators.required]),
        'isPaid': FormControl<bool>(
          value: true,
          validators: [Validators.required],
        ),
        'coverageEmployee': FormControl<String>(
          validators: [Validators.required, Validators.email],
        ),
        'reason': FormControl<String>(
          validators: [Validators.required, Validators.minLength(10)],
        ),
        'notes': FormControl<String>(value: ''),
      },
      [
        Validators.delegate((control) => _validateDatesSequence(control)),
        Validators.delegate((control) => _validateAnnualLeaveCap(control)),
      ],
    );
  }

  Map<String, dynamic>? _validateDatesSequence(
    AbstractControl<dynamic> control,
  ) {
    final formGroup = control as FormGroup;
    final startCtrl = formGroup.control('startDate');
    final endCtrl = formGroup.control('endDate');
    if (startCtrl.value != null && endCtrl.value != null) {
      final DateTime startDate = startCtrl.value as DateTime;
      final DateTime endDate = endCtrl.value as DateTime;
      if (endDate.isBefore(startDate)) {
        endCtrl.setErrors({'dateOrderInvalid': true});
        return {'dateOrderInvalid': true};
      } else {
        endCtrl.removeError('dateOrderInvalid');
      }
    }
    return null;
  }

  Map<String, dynamic>? _validateAnnualLeaveCap(
    AbstractControl<dynamic> control,
  ) {
    final formGroup = control as FormGroup;
    final leaveType = formGroup.control('leaveType').value as String?;
    final startCtrl = formGroup.control('startDate');
    final endCtrl = formGroup.control('endDate');
    if (leaveType == 'Annual Leave' &&
        startCtrl.value != null &&
        endCtrl.value != null) {
      final days = _calculateBusinessDays(
        startCtrl.value as DateTime,
        endCtrl.value as DateTime,
      );
      if (days > widget.remainingAnnualDays) {
        return {
          'annualLeaveExceeded': {
            'requested': days,
            'remaining': widget.remainingAnnualDays,
          },
        };
      }
    }
    return null;
  }

  int _calculateBusinessDays(DateTime start, DateTime end) {
    if (end.isBefore(start)) return 0;
    int count = 0;
    DateTime current = DateTime(start.year, start.month, start.day);
    DateTime endDate = DateTime(end.year, end.month, end.day);
    while (!current.isAfter(endDate)) {
      final weekday = current.weekday;
      if (weekday != DateTime.saturday && weekday != DateTime.sunday) {
        count++;
      }
      current = current.add(const Duration(days: 1));
    }
    return count;
  }

  int get _calculatedDurationDays {
    final start = form.control('startDate').value as DateTime?;
    final end = form.control('endDate').value as DateTime?;
    if (start == null || end == null) return 0;
    if (end.isBefore(start)) return 0;
    return _calculateBusinessDays(start, end);
  }

  @override
  Widget build(BuildContext context) {
    return ReactiveForm(
      formGroup: form,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showDragHandle)
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            if (widget.showDragHandle) ...[
              const Text(
                'Corporate Leave Request',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF54046C),
                ),
              ),
              const Text(
                'Ensure compliance with internal HR policy guidelines before submission.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const Divider(height: 24, thickness: 1),
            ],
            if (!widget.showDragHandle && widget.onCancel != null)
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: widget.onCancel,
                  tooltip: 'Close form',
                ),
              ),
            ReactiveDropdownField<String>(
              formControlName: 'leaveType',
              decoration: const InputDecoration(
                labelText: 'Leave Category *',
                prefixIcon: Icon(Icons.assignment_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
              items: _leaveTypes
                  .map(
                    (type) => DropdownMenuItem(value: type, child: Text(type)),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ReactiveDatePicker<DateTime>(
                    formControlName: 'startDate',
                    firstDate: DateTime.now().subtract(
                      const Duration(days: 30),
                    ),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    builder: (context, picker, child) {
                      final val = picker.value;
                      return InkWell(
                        onTap: () => picker.showPicker(),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Start Date *',
                            prefixIcon: Icon(Icons.calendar_today_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(12),
                              ),
                            ),
                          ),
                          child: Text(
                            val != null
                                ? DateFormat("dd MMM yyyy").format(val)
                                : 'Select Date',
                            style: TextStyle(
                              color: val != null ? Colors.black87 : Colors.grey,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ReactiveDatePicker<DateTime>(
                    formControlName: 'endDate',
                    firstDate: DateTime.now().subtract(
                      const Duration(days: 30),
                    ),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    builder: (context, picker, child) {
                      final val = picker.value;
                      return InkWell(
                        onTap: () => picker.showPicker(),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'End Date *',
                            prefixIcon: const Icon(
                              Icons.calendar_today_outlined,
                            ),
                            errorText:
                                picker.control.hasError('dateOrderInvalid') &&
                                    picker.control.touched
                                ? 'Invalid date range'
                                : null,
                            border: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(12),
                              ),
                            ),
                          ),
                          child: Text(
                            val != null
                                ? DateFormat("dd MMM yyyy").format(val)
                                : 'Select Date',
                            style: TextStyle(
                              color: val != null ? Colors.black87 : Colors.grey,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ReactiveValueListenableBuilder<DateTime>(
              formControlName: 'endDate',
              builder: (context, control, child) {
                final totalDays = _calculatedDurationDays;
                if (totalDays <= 0) return const SizedBox.shrink();
                final leaveType = form.control('leaveType').value as String?;
                final bool exceedsAnnual =
                    leaveType == 'Annual Leave' &&
                    totalDays > widget.remainingAnnualDays;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: exceedsAnnual
                        ? Colors.red.withValues(alpha: 0.08)
                        : const Color(0xFF54046C).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        exceedsAnnual
                            ? Icons.warning_amber_rounded
                            : Icons.timelapse,
                        size: 16,
                        color: exceedsAnnual
                            ? Colors.red
                            : const Color(0xFF54046C),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          exceedsAnnual
                              ? 'Business days requested: $totalDays. You only have ${widget.remainingAnnualDays} annual leave day(s) remaining. Please reduce the date range.'
                              : 'Total Business Days Requested: $totalDays Day(s)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: exceedsAnnual
                                ? Colors.red
                                : const Color(0xFF54046C),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Material(
                type: MaterialType.transparency,
                child: ReactiveCheckboxListTile(
                  formControlName: 'isPaid',
                  title: const Text(
                    'Request as Paid Leave',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Subject to your accrued active company balance accounts.',
                    style: TextStyle(fontSize: 12),
                  ),
                  activeColor: const Color(0xFF54046C),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ReactiveTextField<String>(
              formControlName: 'coverageEmployee',
              validationMessages: {
                'required': (error) =>
                    'Coverage hand-off assignment is required',
                'email': (error) =>
                    'Please enter a valid corporate email address',
              },
              decoration: const InputDecoration(
                labelText: 'Handover / Coverage Personnel Email *',
                prefixIcon: Icon(Icons.person_pin_outlined),
                hintText: 'colleague@firmcompany.com',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ReactiveTextField<String>(
              formControlName: 'reason',
              maxLines: 3,
              validationMessages: {
                'required': (error) =>
                    'An auditable reason is legally required',
                'minLength': (error) =>
                    'Provide a clearer description (min. 10 chars)',
              },
              decoration: const InputDecoration(
                labelText: 'Formal Reason for Application *',
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ReactiveTextField<String>(
              formControlName: 'notes',
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Internal Administrative Notes (Optional)',
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ReactiveFormConsumer(
              builder: (context, formGroup, child) {
                final bool isAnnualExceeded = formGroup.hasError(
                  'annualLeaveExceeded',
                );
                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: formGroup.valid && !isAnnualExceeded
                        ? () {
                            final startValue =
                                formGroup.control('startDate').value
                                    as DateTime;
                            final endValue =
                                formGroup.control('endDate').value as DateTime;
                            widget.onSubmit({
                              'leaveType': formGroup.control('leaveType').value,
                              'startDate': Timestamp.fromDate(startValue),
                              'endDate': Timestamp.fromDate(endValue),
                              'days': _calculatedDurationDays,
                              'isPaid': formGroup.control('isPaid').value,
                              'coverageEmployee': formGroup
                                  .control('coverageEmployee')
                                  .value,
                              'reason': formGroup.control('reason').value,
                              'notes': formGroup.control('notes').value,
                            });
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color(0xFF54046C),
                      disabledBackgroundColor: Colors.grey,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Submit Request',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                );
              },
            ),
            if (widget.showDragHandle) const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}