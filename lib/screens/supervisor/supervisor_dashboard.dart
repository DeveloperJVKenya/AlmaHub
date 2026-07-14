import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import '../../models/hours_models.dart';
import '../../providers/hours_providers.dart';
import '../../services/hours_service.dart';
import 'hours_review_screen.dart';
import 'supervisor_manual_hours_dialog.dart';
import 'dart:async';

class SupervisorDashboard extends ConsumerStatefulWidget {
  const SupervisorDashboard({super.key});

  @override
  ConsumerState<SupervisorDashboard> createState() => _SupervisorDashboardState();
}

class _SupervisorDashboardState extends ConsumerState<SupervisorDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  
  String? _supervisorDepartment;
  String? _supervisorName;
  String? _currentUserRole;
  bool _isLoadingSupervisorInfo = true;
  String _searchQuery = '';
  
  // Selected month and year for hours tracking
  DateTime _selectedMonth = DateTime.now();

  // ============================================================================
  // ANTI-FLICKERING MECHANISM: Cache previous data to maintain display stability
  // ============================================================================
  List<Map<String, dynamic>> _cachedEmployees = [];
  bool _hasInitialData = false;

  // Logger for debugging
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

  // ============================================================================
  // PERFORMANCE CALCULATION CONSTANTS
  // ============================================================================
static const double standardWorkHoursPerDay = 8.0;
static const double maxOvertimeHoursPerDay = 4.0;
static const double maxHoursPerDay = standardWorkHoursPerDay + maxOvertimeHoursPerDay;
static const double hoursWeight = 0.45;
static const double qualityWeight = 0.55;
static const double maxOvertimeBonus = 20.0;

  @override
  void initState() {
    super.initState();
    _logger.i('=== SUPERVISOR DASHBOARD INITIALIZED ===');
    _loadCurrentUserRoleAndInfo();
  }

  /// Load current user's role and information
  Future<void> _loadCurrentUserRoleAndInfo() async {
    if (_currentUser == null) {
      _logger.e('No current user found');
      setState(() => _isLoadingSupervisorInfo = false);
      return;
    }

    _logger.i('Loading user info for: ${_currentUser.email}');

    try {
      // Find user document by UID in Users collection
      final userQuery = await _firestore
          .collection('Users')
          .where('uid', isEqualTo: _currentUser.uid)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        _logger.w('User not found in Users collection');
        setState(() => _isLoadingSupervisorInfo = false);
        return;
      }

      final userDoc = userQuery.docs.first;
      final userData = userDoc.data();
      
      _currentUserRole = userData['role'] ?? 'Employee';

      _logger.i('Current user role: $_currentUserRole');

      // If user is Supervisor, load their department
      if (_currentUserRole == 'Supervisor') {
        await _loadSupervisorDepartment();
      } else {
        // For Admin/HR/Accountant, set name from user data
        _supervisorName = userData['fullname'] ?? userData['fullName'] ?? 'Unknown';
      }

      setState(() => _isLoadingSupervisorInfo = false);

    } catch (e, stackTrace) {
      _logger.e('Error loading user info', error: e, stackTrace: stackTrace);
      setState(() => _isLoadingSupervisorInfo = false);
    }
  }

  /// Load supervisor's department from Supervisors collection
  Future<void> _loadSupervisorDepartment() async {
    try {
      _logger.i('Loading supervisor department for UID: ${_currentUser!.uid}');

      // Query Supervisors collection by UID
      final supervisorQuery = await _firestore
          .collection('Supervisors')
          .where('uid', isEqualTo: _currentUser.uid)
          .limit(1)
          .get();

      if (supervisorQuery.docs.isEmpty) {
        _logger.w('Supervisor document not found');
        return;
      }

      final supervisorData = supervisorQuery.docs.first.data();
      
      setState(() {
        _supervisorDepartment = supervisorData['department'];
        _supervisorName = supervisorData['fullname'];
      });

      _logger.i('Supervisor loaded: $_supervisorName, Department: $_supervisorDepartment');

    } catch (e, stackTrace) {
      _logger.e('Error loading supervisor department', error: e, stackTrace: stackTrace);
    }
  }

  /// Check if current user can access this dashboard
  bool _canAccessDashboard() {
    return _currentUserRole != null && 
           (_currentUserRole == 'Supervisor' || 
            _currentUserRole == 'Admin' || 
            _currentUserRole == 'HR' || 
            _currentUserRole == 'Accountant');
  }

  /// Check if current user should see all departments
  bool _shouldShowAllDepartments() {
    return _currentUserRole == 'Admin' || 
           _currentUserRole == 'HR' || 
           _currentUserRole == 'Accountant';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingSupervisorInfo) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Color.fromARGB(255, 123, 31, 162),
          ),
        ),
      );
    }

    if (!_canAccessDashboard()) {
      return _buildAccessDeniedScreen();
    }

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 240, 235, 245),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildDepartmentHeader(),
                  _buildStatsCards(),
                  _buildEmployeeTable(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color.fromARGB(255, 123, 31, 162),
      elevation: 2,
      title: Text(
        _shouldShowAllDepartments() 
            ? '$_currentUserRole Dashboard - All Departments'
            : 'Supervisor Dashboard',
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
      actions: [
        _buildReviewHoursAction(),
        IconButton(
          icon: const Icon(Icons.search, color: Colors.white),
          onPressed: _showSearchDialog,
          tooltip: 'Search Employees',
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: () {
            _logger.i('Refreshing dashboard');
            setState(() {
              // Keep cached data during refresh to prevent flickering
            });
          },
          tooltip: 'Refresh',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  /// AppBar action pushing the pending-hours review queue, badged with a
  /// live count via Riverpod (`department == null` means "all departments,"
  /// matching `_shouldShowAllDepartments()`).
  Widget _buildReviewHoursAction() {
    final department = _shouldShowAllDepartments() ? null : _supervisorDepartment;
    final countAsync = ref.watch(pendingHoursCountProvider(department));
    final count = countAsync.value ?? 0;

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            icon: const Icon(Icons.fact_check, color: Colors.white),
            tooltip: 'Review Hours',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => HoursReviewScreen(department: department)),
              );
            },
          ),
          if (count > 0)
            Positioned(
              right: 4,
              top: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDepartmentHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color.fromARGB(255, 123, 31, 162),
            Color.fromARGB(255, 156, 39, 176),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _shouldShowAllDepartments() ? Icons.admin_panel_settings : Icons.supervisor_account,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _shouldShowAllDepartments() ? '$_currentUserRole View' : 'Department Supervisor',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _supervisorName ?? 'Unknown',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                if (!_shouldShowAllDepartments() && _supervisorDepartment != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.business,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _supervisorDepartment!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_shouldShowAllDepartments())
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.domain,
                          size: 14,
                          color: Colors.white,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'All Departments',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelectorCard(double cardWidth) {
    return GestureDetector(
      onTap: _showMonthPickerDialog,
      child: Container(
        width: cardWidth,
        padding: EdgeInsets.symmetric(
          horizontal: cardWidth * 0.05,
          vertical: 8.0,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(cardWidth * 0.04),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 156, 39, 176).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.calendar_month,
                color: const Color.fromARGB(255, 156, 39, 176),
                size: (cardWidth * 0.08).clamp(16.0, 22.0),
              ),
            ),
            SizedBox(width: cardWidth * 0.05),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('MMM yyyy').format(_selectedMonth),
                    style: TextStyle(
                      fontSize: (cardWidth * 0.055).clamp(12.0, 16.0),
                      fontWeight: FontWeight.bold,
                      color: const Color.fromARGB(255, 123, 31, 162),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Viewing Period',
                    style: TextStyle(
                      fontSize: (cardWidth * 0.045).clamp(10.0, 12.0),
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              color: const Color.fromARGB(255, 123, 31, 162),
              size: (cardWidth * 0.08).clamp(18.0, 24.0),
            ),
          ],
        ),
      ),
    );
  }

  void _showMonthPickerDialog() {
    final List<DateTime> months = [];
    final now = DateTime.now();
    
    for (int i = 0; i < 12; i++) {
      months.add(DateTime(now.year, now.month - i, 1));
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(
              Icons.calendar_month,
              color: Color.fromARGB(255, 123, 31, 162),
            ),
            SizedBox(width: 12),
            Text('Select Viewing Period'),
          ],
        ),
        content: SizedBox(
          width: double.minPositive,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: months.length,
            itemBuilder: (context, index) {
              final month = months[index];
              final isSelected = month.month == _selectedMonth.month &&
                  month.year == _selectedMonth.year;
              
              return ListTile(
                selected: isSelected,
                selectedTileColor: const Color.fromARGB(255, 123, 31, 162).withValues(alpha: 0.1),
                leading: Icon(
                  isSelected ? Icons.check_circle : Icons.calendar_today,
                  color: isSelected
                      ? const Color.fromARGB(255, 123, 31, 162)
                      : Colors.grey,
                ),
                title: Text(
                  DateFormat('MMMM yyyy').format(month),
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected
                        ? const Color.fromARGB(255, 123, 31, 162)
                        : Colors.black87,
                  ),
                ),
                onTap: () {
                  _logger.i('Month changed to: ${DateFormat('MMMM yyyy').format(month)}');
                  setState(() {
                    _selectedMonth = month;
                    // Clear cache when month changes to force fresh data
                    _hasInitialData = false;
                  });
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    _logger.d('Building stats cards for month: ${DateFormat('MMM yyyy').format(_selectedMonth)}');
    
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _getEmployeesDataStream(),
      builder: (context, snapshot) {
        // ============================================================================
        // ANTI-FLICKERING: Use cached data while loading new data
        // ============================================================================
        List<Map<String, dynamic>> employees;
        
        if (snapshot.hasData) {
          employees = snapshot.data!;
          // Update cache only when we have valid data
          if (employees.isNotEmpty) {
            _cachedEmployees = List.from(employees);
            _hasInitialData = true;
          }
        } else if (_hasInitialData && _cachedEmployees.isNotEmpty) {
          // Use cached data while waiting for new data
          employees = _cachedEmployees;
          _logger.d('📦 Using cached data for stats (${_cachedEmployees.length} employees)');
        } else {
          // No data available at all
          if (snapshot.hasError) {
            _logger.e('Error in stats stream', error: snapshot.error);
          }
          return const SizedBox.shrink();
        }

        final totalEmployees = employees.length;
        
        // Calculate total hours and overtime for selected month
        double totalHours = 0;
        double totalOvertime = 0;
        int employeesWithOvertime = 0;
        double totalPerformance = 0;
        int employeesWithPerformance = 0;
        
        for (var employee in employees) {
          final monthlyData = _getMonthlyData(employee);
          final hoursWorked = monthlyData['hours'] as double;
          final daysWorked = monthlyData['daysWorked'] as int;
          
          if (hoursWorked > 0) {
            totalHours += hoursWorked;

            // True per-day overtime, computed from approved DailyHours by
            // _getEmployeeDetails (see HoursService.computeOvertimeHours).
            final overtime = employee['overtimeHours'] as double? ?? 0.0;
            if (overtime > 0) {
              totalOvertime += overtime;
              employeesWithOvertime++;
            }

            // Calculate performance
            final performanceMetrics = _calculateRealisticPerformance(
              hoursWorked: hoursWorked,
              workQuality: monthlyData['quality'] as double,
              employmentType: employee['employmentType'] ?? 'Full-Time',
              daysWorked: daysWorked,
            );

            if (daysWorked > 0) {
              totalPerformance += performanceMetrics['monthlyPerformance'] as double;
              employeesWithPerformance++;
            }
          }
        }

        final avgHours = totalEmployees > 0 ? totalHours / totalEmployees : 0;
        final avgPerformance = employeesWithPerformance > 0 
            ? totalPerformance / employeesWithPerformance 
            : 0;

        _logger.d('Stats: Total=$totalEmployees, TotalHours=$totalHours, Overtime=$totalOvertime, AvgHours=$avgHours, AvgPerf=$avgPerformance');

        return LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            final cardWidth = (screenWidth - (screenWidth * 0.04 * 2) - (screenWidth * 0.015 * 6)) / 7;
            final spacing = screenWidth * 0.015;
            
            return Container(
              margin: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.02,
                vertical: 12,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildMonthSelectorCard(cardWidth),
                    SizedBox(width: spacing),
                    _buildStatCard(
                      'Team Members',
                      totalEmployees.toString(),
                      const Color.fromARGB(255, 123, 31, 162),
                      Icons.people,
                      cardWidth,
                    ),
                    SizedBox(width: spacing),
                    _buildStatCard(
                      'Total Hours',
                      NumberFormat('#,##0.0').format(totalHours),
                      const Color.fromARGB(255, 2, 136, 209),
                      Icons.access_time,
                      cardWidth,
                    ),
                    SizedBox(width: spacing),
                    _buildStatCard(
                      'Overtime Hours',
                      NumberFormat('#,##0.0').format(totalOvertime),
                      const Color.fromARGB(255, 255, 152, 0),
                      Icons.schedule,
                      cardWidth,
                    ),
                    SizedBox(width: spacing),
                    _buildStatCard(
                      'Avg Hours/Employee',
                      NumberFormat('#,##0.0').format(avgHours),
                      const Color.fromARGB(255, 46, 125, 50),
                      Icons.timeline,
                      cardWidth,
                    ),
                    SizedBox(width: spacing),
                    _buildStatCard(
                      'Avg Performance',
                      '${avgPerformance.toStringAsFixed(1)}%',
                      const Color.fromARGB(255, 156, 39, 176),
                      Icons.star,
                      cardWidth,
                    ),
                    SizedBox(width: spacing),
                    _buildStatCard(
                      'Employees w/ OT',
                      employeesWithOvertime.toString(),
                      const Color.fromARGB(255, 255, 87, 34),
                      Icons.trending_up,
                      cardWidth,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon, double cardWidth) {
    final iconSize = (cardWidth * 0.08).clamp(16.0, 22.0);
    final valueSize = (cardWidth * 0.055).clamp(12.0, 16.0);
    final titleSize = (cardWidth * 0.045).clamp(10.0, 12.0);
    final horizontalPadding = cardWidth * 0.05;
    final verticalPadding = 8.0;
    
    return Container(
      width: cardWidth,
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(cardWidth * 0.04),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              color: color,
              size: iconSize,
            ),
          ),
          SizedBox(width: cardWidth * 0.05),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: valueSize,
                    fontWeight: FontWeight.bold,
                    color: const Color.fromARGB(255, 123, 31, 162),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: titleSize,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeTable() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        
        return Container(
          margin: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.02,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTableHeader(screenWidth),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: _getEmployeesDataStream(),
                builder: (context, snapshot) {
                  // ============================================================================
                  // ANTI-FLICKERING: Use cached data during updates
                  // ============================================================================
                  List<Map<String, dynamic>> allEmployees;
                  bool isLoadingNewData = false;
                  
                  if (snapshot.hasData) {
                    allEmployees = snapshot.data!;
                    // Update cache when we get new data
                    if (allEmployees.isNotEmpty) {
                      _cachedEmployees = List.from(allEmployees);
                      _hasInitialData = true;
                    }
                  } else if (_hasInitialData && _cachedEmployees.isNotEmpty) {
                    // Use cached data while waiting for updates
                    allEmployees = _cachedEmployees;
                    isLoadingNewData = snapshot.connectionState == ConnectionState.waiting;
                    _logger.d('📦 Using cached data for table (${_cachedEmployees.length} employees)');
                  } else {
                    // First time loading - show progress indicator
                    if (snapshot.hasError) {
                      _logger.e('Error in employee stream', error: snapshot.error);
                      return Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text('Error: ${snapshot.error}'),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(
                          color: Color.fromARGB(255, 123, 31, 162),
                        ),
                      );
                    }

                    // No data available
                    allEmployees = [];
                  }

                  _logger.i('Displaying ${allEmployees.length} employees${isLoadingNewData ? " (updating...)" : ""}');

                  // Apply search filter
                  final employees = _searchQuery.isEmpty
                      ? allEmployees
                      : allEmployees.where((employee) {
                          final fullName = (employee['fullName'] ?? '').toString().toLowerCase();
                          final email = (employee['email'] ?? '').toString().toLowerCase();
                          final jobTitle = (employee['jobTitle'] ?? '').toString().toLowerCase();
                          final department = (employee['department'] ?? '').toString().toLowerCase();
                          
                          return fullName.contains(_searchQuery) ||
                                 email.contains(_searchQuery) ||
                                 jobTitle.contains(_searchQuery) ||
                                 department.contains(_searchQuery);
                        }).toList();

                  if (employees.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _searchQuery.isNotEmpty
                                ? Icons.search_off
                                : Icons.people_outline,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No results found for "$_searchQuery"'
                                : _shouldShowAllDepartments()
                                    ? 'No employees found in any department'
                                    : 'No employees in your department',
                            style: const TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                          if (_searchQuery.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: () {
                                setState(() => _searchQuery = '');
                              },
                              icon: const Icon(Icons.clear),
                              label: const Text('Clear Search'),
                            ),
                          ],
                        ],
                      ),
                    );
                  }

                  // ============================================================================
                  // SMOOTH TRANSITION: Wrap table in Stack for overlay loading indicator
                  // ============================================================================
                  return Stack(
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          key: ValueKey('table_${employees.length}_${_selectedMonth.month}'),
                          headingRowHeight: 50,
                          dataRowMinHeight: 52,
                          dataRowMaxHeight: 52,
                          headingRowColor: WidgetStateProperty.all(
                            Colors.grey.shade100,
                          ),
                          columnSpacing: 24,
                          headingTextStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color.fromARGB(255, 123, 31, 162),
                          ),
                          dataTextStyle: const TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                          columns: [
                            const DataColumn(label: Text('No.')),
                            const DataColumn(label: Text('Full Name')),
                            const DataColumn(label: Text('Email')),
                            const DataColumn(label: Text('Job Title')),
                            if (_shouldShowAllDepartments())
                              const DataColumn(label: Text('Department')),
                            const DataColumn(label: Text('Employment Type')),
                            const DataColumn(label: Text('Hours Worked')),
                            const DataColumn(label: Text('Overtime')),
                            const DataColumn(label: Text('Performance')),
                            const DataColumn(label: Text('Status')),
                            const DataColumn(label: Text('Actions')),
                          ],
                          rows: employees.asMap().entries.map((entry) {
                            final index = entry.key;
                            final employee = entry.value;
                            
                            final uid = employee['uid'] ?? '';
                            final fullName = employee['fullName'] ?? '-';
                            final email = employee['email'] ?? '-';
                            final jobTitle = employee['jobTitle'] ?? '-';
                            final department = employee['department'] ?? '-';
                            final employmentType = employee['employmentType'] ?? '-';
                            final status = employee['status'] ?? 'draft';
                            
                            // Get monthly data (hours, quality, days)
                            final monthlyData = _getMonthlyData(employee);
                            final hoursWorked = monthlyData['hours'] as double;
                            final workQuality = monthlyData['quality'] as double;
                            final daysWorked = monthlyData['daysWorked'] as int;
                            final documentId = employee['documentId'] as String?;
                            final pendingCount = employee['pendingCount'] as int? ?? 0;

                            // True per-day overtime, computed from approved
                            // DailyHours entries by _getEmployeeDetails.
                            final overtimeHours = employee['overtimeHours'] as double? ?? 0.0;

                            // Calculate REALISTIC performance metrics (45% hours + 55% quality + 20% OT bonus)
                            final performanceMetrics = _calculateRealisticPerformance(
                              hoursWorked: hoursWorked,
                              workQuality: workQuality,
                              employmentType: employmentType,
                              daysWorked: daysWorked,
                            );

                            return DataRow(
                              key: ValueKey(uid), // Stable key for smooth updates
                              cells: [
                                DataCell(Text('${index + 1}')),
                                DataCell(
                                  SizedBox(
                                    width: 150,
                                    child: Text(
                                      fullName,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 180,
                                    child: Text(
                                      email,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: 140,
                                    child: Text(
                                      jobTitle,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                if (_shouldShowAllDepartments())
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color.fromARGB(255, 123, 31, 162).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        department,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                          color: Color.fromARGB(255, 123, 31, 162),
                                        ),
                                      ),
                                    ),
                                  ),
                                DataCell(_buildEmploymentTypeBadge(employmentType)),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: hoursWorked > 0
                                          ? const Color.fromARGB(255, 123, 31, 162).withValues(alpha: 0.1)
                                          : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      hoursWorked > 0
                                          ? '${NumberFormat('#,##0.0').format(hoursWorked)} hrs'
                                          : 'Not logged',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: hoursWorked > 0
                                            ? const Color.fromARGB(255, 123, 31, 162)
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(_buildOvertimeBadge(overtimeHours)),
                                DataCell(_buildRealisticPerformanceBadge(performanceMetrics)),
                                DataCell(_buildStatusBadge(status, pendingCount)),
                                DataCell(
                                  PopupMenuButton<String>(
                                    icon: const Icon(
                                      Icons.more_vert,
                                      size: 20,
                                      color: Color.fromARGB(255, 123, 31, 162),
                                    ),
                                    onSelected: (value) {
                                      if (value == 'history') {
                                        if (documentId != null) {
                                          _showEmployeeHistoryDialog(documentId, fullName);
                                        }
                                      } else if (value == 'manual') {
                                        _showManualHoursDialog(uid, fullName);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'history',
                                        child: Row(
                                          children: [
                                            Icon(Icons.history, size: 18),
                                            SizedBox(width: 8),
                                            Text('View History'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'manual',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit_calendar, size: 18),
                                            SizedBox(width: 8),
                                            Text('Manual Entry'),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                      // Optional: Show subtle loading indicator in corner when updating
                      if (isLoadingNewData)
                        Positioned(
                          right: 16,
                          top: 16,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color.fromARGB(255, 123, 31, 162),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Updating...',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color.fromARGB(255, 123, 31, 162),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTableHeader(double screenWidth) {
    final logoSize = (screenWidth * 0.025).clamp(35.0, 50.0);
    final titleSize = (screenWidth * 0.014).clamp(16.0, 22.0);
    final subtitleSize = (screenWidth * 0.010).clamp(12.0, 15.0);
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.025,
        vertical: 16,
      ),
      decoration: const BoxDecoration(
        color: Color.fromARGB(255, 123, 31, 162),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: logoSize,
            height: logoSize,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Icon(
                Icons.people,
                size: logoSize * 0.6,
                color: const Color.fromARGB(255, 123, 31, 162),
              ),
            ),
          ),
          SizedBox(width: screenWidth * 0.015),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _shouldShowAllDepartments() 
                      ? 'All Department Employees'
                      : 'Department Employees',
                  style: TextStyle(
                    fontSize: titleSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _shouldShowAllDepartments()
                      ? 'Manage hours and employee information across all departments'
                      : 'Manage hours and employee information for $_supervisorDepartment',
                  style: TextStyle(
                    fontSize: subtitleSize,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmploymentTypeBadge(String type) {
    Color color;
    IconData icon;
    
    switch (type.toLowerCase()) {
      case 'permanent':
      case 'full-time':
        color = const Color.fromARGB(255, 46, 125, 50);
        icon = Icons.work;
        break;
      case 'part-time':
        color = const Color.fromARGB(255, 2, 136, 209);
        icon = Icons.access_time;
        break;
      case 'contract':
        color = const Color.fromARGB(255, 255, 152, 0);
        icon = Icons.description;
        break;
      case 'casual':
      case 'intern':
        color = const Color.fromARGB(255, 123, 31, 162);
        icon = Icons.school;
        break;
      default:
        color = Colors.grey;
        icon = Icons.help_outline;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            type,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOvertimeBadge(double overtimeHours) {
    if (overtimeHours <= 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'No OT',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      );
    }
    
    // Determine overtime severity
    Color color;
    IconData icon;
    
    if (overtimeHours >= 40) {
      // Excessive overtime (≥40 hours)
      color = Colors.red;
      icon = Icons.warning_amber;
    } else if (overtimeHours >= 20) {
      // High overtime (20-39 hours)
      color = const Color.fromARGB(255, 255, 152, 0);
      icon = Icons.access_time_filled;
    } else {
      // Moderate overtime (<20 hours)
      color = const Color.fromARGB(255, 2, 136, 209);
      icon = Icons.schedule;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            '${NumberFormat('#,##0.0').format(overtimeHours)} hrs',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // REALISTIC PERFORMANCE BADGE
  // Formula: (Hours × 45%) + (Quality × 55%) + Overtime Bonus (max 20%)
  // ============================================================================
  Widget _buildRealisticPerformanceBadge(Map<String, dynamic> metrics) {
    final currentPercent = metrics['currentPerformance'] as double;
    final monthlyPercent = metrics['monthlyPerformance'] as double;
    final daysWorked = metrics['daysWorked'] as int;
    final overtimeBonus = metrics['overtimeBonus'] as double;
    
    // Use current performance for color determination if days < 22, otherwise use monthly
    final displayPercent = daysWorked < 22 ? currentPercent : monthlyPercent;
    
    Color color;
    IconData icon;
    String grade;
    
    // Performance grading based on realistic expectations
    if (displayPercent >= 115) {
      // 115%+ = Exceptional (with significant OT)
      color = const Color.fromARGB(255, 156, 39, 176); // Purple
      icon = Icons.emoji_events; // Trophy
      grade = 'S+';
    } else if (displayPercent >= 105) {
      // 105-114% = Excellent (with some OT)
      color = const Color.fromARGB(255, 46, 125, 50); // Green
      icon = Icons.star;
      grade = 'S';
    } else if (displayPercent >= 95) {
      // 95-104% = Very Good (near perfect or with slight OT)
      color = const Color.fromARGB(255, 76, 175, 80); // Light Green
      icon = Icons.trending_up;
      grade = 'A+';
    } else if (displayPercent >= 85) {
      // 85-94% = Good (above average)
      color = const Color.fromARGB(255, 2, 136, 209); // Blue
      icon = Icons.check_circle;
      grade = 'A';
    } else if (displayPercent >= 75) {
      // 75-84% = Satisfactory (acceptable)
      color = const Color.fromARGB(255, 3, 169, 244); // Light Blue
      icon = Icons.thumbs_up_down;
      grade = 'B';
    } else if (displayPercent >= 65) {
      // 65-74% = Below Average (needs improvement)
      color = const Color.fromARGB(255, 255, 193, 7); // Yellow
      icon = Icons.trending_flat;
      grade = 'C';
    } else if (displayPercent >= 50) {
      // 50-64% = Poor (significant issues)
      color = const Color.fromARGB(255, 255, 152, 0); // Orange
      icon = Icons.trending_down;
      grade = 'D';
    } else {
      // <50% = Critical (very poor)
      color = Colors.red;
      icon = Icons.warning;
      grade = 'F';
    }
    
    return Container(
      constraints: const BoxConstraints(
        minWidth: 110,
        maxWidth: 135,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (daysWorked > 0) ...[
                  // Top row: Current Performance
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Now: ',
                        style: TextStyle(
                          color: color.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w500,
                          fontSize: 10,
                          height: 1.2,
                        ),
                      ),
                      Text(
                        '${currentPercent.toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          height: 1.2,
                        ),
                      ),
                      if (overtimeBonus > 0) ...[
                        const SizedBox(width: 2),
                        Icon(
                          Icons.add_circle,
                          size: 8,
                          color: color.withValues(alpha: 0.6),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 1),
                  // Bottom row: Monthly Performance with Grade
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Month: ',
                        style: TextStyle(
                          color: color.withValues(alpha: 0.65),
                          fontWeight: FontWeight.w500,
                          fontSize: 9,
                          height: 1.2,
                        ),
                      ),
                      Text(
                        '${monthlyPercent.toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: color.withValues(alpha: 0.8),
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          grade,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 8,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Text(
                    'No data',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                      fontSize: 10,
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

  Widget _buildStatusBadge(String status, [int pendingHoursCount = 0]) {
    Color color;
    String text;

    switch (status) {
      case 'approved':
        color = Colors.green;
        text = 'Approved';
        break;
      case 'submitted':
        color = Colors.orange;
        text = 'Pending';
        break;
      case 'rejected':
        color = Colors.red;
        text = 'Rejected';
        break;
      default:
        color = Colors.grey;
        text = 'Draft';
    }

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
        if (pendingHoursCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$pendingHoursCount hrs pending',
              style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w600, fontSize: 11),
            ),
          ),
      ],
    );
  }

  /// Get employees data stream - fetches from Departments collection
  Stream<List<Map<String, dynamic>>> _getEmployeesDataStream() async* {
    _logger.i('=== Getting Employees Data Stream ===');
    _logger.i('Selected month: ${DateFormat('MMM yyyy').format(_selectedMonth)}');
    
    try {
      if (_shouldShowAllDepartments()) {
        // Admin/HR/Accountant: Get all departments
        _logger.i('Fetching all departments for $_currentUserRole');
        
        await for (final deptSnapshot in _firestore.collection('Departments').snapshots()) {
          final List<Map<String, dynamic>> allEmployees = [];
          
          for (final deptDoc in deptSnapshot.docs) {
            final deptData = deptDoc.data();
            final deptName = deptDoc.id;
            final members = deptData['members'] as Map<String, dynamic>? ?? {};
            
            _logger.d('Processing department: $deptName with ${members.length} members');
            
            for (final memberEntry in members.entries) {
              final uid = memberEntry.key;
              final memberData = memberEntry.value as Map<String, dynamic>?;
              
              if (memberData == null) continue;
              
              // Fetch additional employee details from EmployeeDetails
              final employeeDetails = await _getEmployeeDetails(uid, DateFormat('yyyy-MM').format(_selectedMonth));
              
              allEmployees.add({
                'uid': uid,
                'fullName': memberData['fullname'] ?? memberData['fullName'] ?? 'Unknown',
                'email': memberData['email'] ?? 'Unknown',
                'department': deptName,
                ...employeeDetails,
              });
            }
          }
          
          _logger.i('Total employees across all departments: ${allEmployees.length}');
          yield allEmployees;
        }
      } else {
        // Supervisor: Get only their department
        if (_supervisorDepartment == null) {
          _logger.w('Supervisor department is null');
          yield [];
          return;
        }
        
        _logger.i('Fetching department: $_supervisorDepartment');
        
        await for (final deptSnapshot in _firestore
            .collection('Departments')
            .doc(_supervisorDepartment)
            .snapshots()) {
          
          if (!deptSnapshot.exists) {
            _logger.w('Department document does not exist: $_supervisorDepartment');
            yield [];
            continue;
          }
          
          final deptData = deptSnapshot.data()!;
          final members = deptData['members'] as Map<String, dynamic>? ?? {};
          
          _logger.d('Department $_supervisorDepartment has ${members.length} members');
          
          final List<Map<String, dynamic>> employees = [];
          
          for (final memberEntry in members.entries) {
            final uid = memberEntry.key;
            final memberData = memberEntry.value as Map<String, dynamic>?;
            
            if (memberData == null) continue;
            
            // Fetch additional employee details
            final employeeDetails = await _getEmployeeDetails(uid, DateFormat('yyyy-MM').format(_selectedMonth));
            
            employees.add({
              'uid': uid,
              'fullName': memberData['fullname'] ?? memberData['fullName'] ?? 'Unknown',
              'email': memberData['email'] ?? 'Unknown',
              'department': _supervisorDepartment!,
              ...employeeDetails,
            });
          }
          
          _logger.i('Loaded ${employees.length} employees for department: $_supervisorDepartment');
          yield employees;
        }
      }
    } catch (e, stackTrace) {
      _logger.e('Error in getEmployeesDataStream', error: e, stackTrace: stackTrace);
      yield [];
    }
  }

  Future<Map<String, dynamic>> _getEmployeeDetails(String uid, String monthKey) async {
    try {
      // Draft and submitted onboarding records both live in EmployeeDetails
      // now — `status` distinguishes them, not the collection.
      final employeeQuery = await _firestore
          .collection('EmployeeDetails')
          .where('uid', isEqualTo: uid)
          .limit(1)
          .get();

      String? documentId;
      Map<String, dynamic>? data;

      if (employeeQuery.docs.isNotEmpty) {
        documentId = employeeQuery.docs.first.id;
        data = employeeQuery.docs.first.data();
      }

      if (data == null) {
        return {
          'jobTitle': '-',
          'employmentType': '-',
          'status': 'draft',
          'hoursWorked': {},
          'workQuality': {},
          'daysWorked': {},
          'overtimeHours': 0.0,
          'pendingCount': 0,
        };
      }

      // Extract hours worked with proper type handling
      Map<String, dynamic> hoursWorked = {};
      final hoursWorkedRaw = data['hoursWorked'];
      
      if (hoursWorkedRaw != null) {
        if (hoursWorkedRaw is Map<String, dynamic>) {
          hoursWorked = hoursWorkedRaw;
        } else if (hoursWorkedRaw is Map) {
          hoursWorked = Map<String, dynamic>.from(hoursWorkedRaw);
        }
      }

      // Extract work quality
      Map<String, dynamic> workQuality = {};
      final workQualityRaw = data['workQuality'];
      if (workQualityRaw != null) {
        if (workQualityRaw is Map<String, dynamic>) {
          workQuality = workQualityRaw;
        } else if (workQualityRaw is Map) {
          workQuality = Map<String, dynamic>.from(workQualityRaw);
        }
      }

      // Extract days worked
      Map<String, dynamic> daysWorked = {};
      final daysWorkedRaw = data['daysWorked'];
      if (daysWorkedRaw != null) {
        if (daysWorkedRaw is Map<String, dynamic>) {
          daysWorked = daysWorkedRaw;
        } else if (daysWorkedRaw is Map) {
          daysWorked = Map<String, dynamic>.from(daysWorkedRaw);
        }
      }

      // True per-day overtime + pending count from this month's DailyHours
      // entries — approved-only, matching what payroll will actually see.
      double overtimeHours = 0.0;
      int pendingCount = 0;
      if (documentId != null) {
        final dailySnapshot = await _firestore
            .collection('EmployeeDetails')
            .doc(documentId)
            .collection('DailyHours')
            .where('monthKey', isEqualTo: monthKey)
            .get();

        final approvedEntries = <DailyHoursEntry>[];
        for (final doc in dailySnapshot.docs) {
          final entryData = doc.data();
          if (entryData['status'] == HoursEntryStatus.pending) {
            pendingCount++;
          } else if (entryData['status'] == HoursEntryStatus.approved) {
            approvedEntries.add(DailyHoursEntry.fromMap(entryData, doc.id));
          }
        }
        overtimeHours = HoursService.computeOvertimeHours(
          approvedEntries: approvedEntries,
          standardHoursPerDay: standardWorkHoursPerDay,
          maxHoursPerDay: maxHoursPerDay,
        );
      }

      final details = {
        'jobTitle': data['employmentDetails']?['jobTitle'] ??
                  data['employmentInfo']?['jobTitle'] ?? '-',
        'employmentType': data['employmentDetails']?['employmentType'] ??
                        data['employmentInfo']?['employmentType'] ?? '-',
        'status': data['status'] ?? 'draft',
        'hoursWorked': hoursWorked,
        'workQuality': workQuality,
        'daysWorked': daysWorked,
        'documentId': documentId,
        'overtimeHours': overtimeHours,
        'pendingCount': pendingCount,
      };

      return details;

    } catch (e, stackTrace) {
      _logger.e('❌ Error fetching employee details for UID: $uid', error: e, stackTrace: stackTrace);
      return {
        'jobTitle': '-',
        'employmentType': '-',
        'status': 'unknown',
        'hoursWorked': {},
        'workQuality': {},
        'daysWorked': {},
        'overtimeHours': 0.0,
        'pendingCount': 0,
      };
    }
  }

  Map<String, dynamic> _getMonthlyData(Map<String, dynamic> employeeData) {
    final monthKey = DateFormat('yyyy-MM').format(_selectedMonth);
    
    // Get hours
    final hoursData = employeeData['hoursWorked'];
    final double hours = _extractMonthlyValue(hoursData, monthKey);
    
    // Get quality
    final qualityData = employeeData['workQuality'];
    final double quality = _extractMonthlyValue(qualityData, monthKey);
    
    // Get days worked
    final daysData = employeeData['daysWorked'];
    final int days = _extractMonthlyValue(daysData, monthKey).toInt();
    
    return {
      'hours': hours,
      'quality': quality > 0 ? quality : 80.0, // Default 80% if not set
      'daysWorked': days,
    };
  }

  /// Helper to extract monthly value from map
  double _extractMonthlyValue(dynamic data, String monthKey) {
    if (data == null) return 0.0;
    
    Map<String, dynamic> dataMap;
    if (data is Map<String, dynamic>) {
      dataMap = data;
    } else if (data is Map) {
      dataMap = Map<String, dynamic>.from(data);
    } else {
      return 0.0;
    }
    
    if (!dataMap.containsKey(monthKey)) return 0.0;
    
    final value = dataMap[monthKey];
    return value is num ? value.toDouble() : 0.0;
  }

  /// ============================================================================
  /// REALISTIC PERFORMANCE CALCULATION
  /// Formula: (Hours Score × 45%) + (Quality Score × 55%) + Overtime Bonus (max 20%)
  /// 
  /// BREAKDOWN:
  /// - Hours Component (45%): Based on 8-hour standard workday
  /// - Quality Component (55%): Work quality rating (0-100%)
  /// - Overtime Bonus (+20% max): Additional percentage for overtime hours
  ///   • 1 OT hour = +5% bonus
  ///   • 2 OT hours = +10% bonus
  ///   • 3 OT hours = +15% bonus
  ///   • 4 OT hours = +20% bonus (maximum)
  /// 
  /// EXAMPLES:
  /// 1. Perfect performance without OT: 100% (45% + 55%)
  /// 2. Perfect with 4 hrs OT: 120% (45% + 55% + 20%)
  /// 3. Half hours, full quality: 77.5% (22.5% + 55%)
  /// ============================================================================
  Map<String, dynamic> _calculateRealisticPerformance({
    required double hoursWorked,
    required double workQuality,
    required String employmentType,
    required int daysWorked,
  }) {
    _logger.d('📊 Calculating realistic performance: hours=$hoursWorked, quality=$workQuality, type=$employmentType, days=$daysWorked');
    
    const standardWorkingDaysPerMonth = 22;
    
    // Determine standard hours based on employment type
    double dailyStandardHours;
    double dailyMaxHours;
    double standardMonthlyHours;
    double maxMonthlyHours;
    
    switch (employmentType.toLowerCase()) {
      case 'full-time':
      case 'permanent':
      case 'contract':
        dailyStandardHours = standardWorkHoursPerDay;
        dailyMaxHours = maxHoursPerDay;
        standardMonthlyHours = standardWorkHoursPerDay * standardWorkingDaysPerMonth;
        maxMonthlyHours = maxHoursPerDay * standardWorkingDaysPerMonth;
        break;
        
      case 'part-time':
        dailyStandardHours = 4.0;
        dailyMaxHours = 6.0;
        standardMonthlyHours = 4.0 * standardWorkingDaysPerMonth;
        maxMonthlyHours = 6.0 * standardWorkingDaysPerMonth;
        break;
        
      case 'casual':
      case 'intern':
          dailyStandardHours = standardWorkHoursPerDay;
          dailyMaxHours = maxHoursPerDay;
          standardMonthlyHours = standardWorkHoursPerDay * standardWorkingDaysPerMonth;
          maxMonthlyHours = maxHoursPerDay * standardWorkingDaysPerMonth;
        break;
        
      default:
        dailyStandardHours = standardWorkHoursPerDay;
        dailyMaxHours = maxHoursPerDay;
        standardMonthlyHours = standardWorkHoursPerDay * standardWorkingDaysPerMonth;
        maxMonthlyHours = maxHoursPerDay * standardWorkingDaysPerMonth;
    }
    
    // ============================================================================
    // CURRENT PERFORMANCE (based on days worked so far)
    // ============================================================================
    
    final expectedStandardHoursForDays = daysWorked * dailyStandardHours;
    final expectedMaxHoursForDays = daysWorked * dailyMaxHours;
    
    // Calculate hours score (0-100%)
    double hoursScore = 0.0;
    double overtimeHoursForBonus = 0.0;
    
    if (hoursWorked <= 0) {
      hoursScore = 0.0;
    } else if (hoursWorked <= expectedStandardHoursForDays) {
      // Below or at standard hours
      hoursScore = (hoursWorked / expectedStandardHoursForDays) * 100.0;
    } else {
      // Has overtime
      hoursScore = 100.0; // Full score for hours
      overtimeHoursForBonus = hoursWorked - expectedStandardHoursForDays;
    }
    
    // Calculate overtime bonus (0-20%)
    // Formula: (OT hours / max possible OT hours) × 20%
    final maxPossibleOT = expectedMaxHoursForDays - expectedStandardHoursForDays;
    double overtimeBonus = 0.0;
    
    if (maxPossibleOT > 0 && overtimeHoursForBonus > 0) {
      overtimeBonus = (overtimeHoursForBonus / maxPossibleOT) * maxOvertimeBonus;
      overtimeBonus = overtimeBonus.clamp(0.0, maxOvertimeBonus);
    }
    
    // Quality score (0-100%)
    final qualityScore = workQuality.clamp(0.0, 100.0);
    
    // CURRENT PERFORMANCE = (Hours × 45%) + (Quality × 55%) + OT Bonus
    final currentPerformance = (hoursScore * hoursWeight) + (qualityScore * qualityWeight) + overtimeBonus;

    
    _logger.d('  Current: hours_score=$hoursScore, quality_score=$qualityScore, ot_bonus=$overtimeBonus => $currentPerformance%');
    
    // ============================================================================
    // MONTHLY PERFORMANCE (based on full month expectation)
    // ============================================================================
    
    // Calculate hours score for monthly
    double monthlyHoursScore = 0.0;
    double monthlyOvertimeHours = 0.0;
    
    if (hoursWorked <= 0) {
      monthlyHoursScore = 0.0;
    } else if (hoursWorked <= standardMonthlyHours) {
      monthlyHoursScore = (hoursWorked / standardMonthlyHours) * 100.0;
    } else {
      monthlyHoursScore = 100.0;
      monthlyOvertimeHours = hoursWorked - standardMonthlyHours;
    }
    
    // Calculate monthly overtime bonus
    final maxMonthlyOT = maxMonthlyHours - standardMonthlyHours;
    double monthlyOvertimeBonus = 0.0;
    
    if (maxMonthlyOT > 0 && monthlyOvertimeHours > 0) {
      monthlyOvertimeBonus = (monthlyOvertimeHours / maxMonthlyOT) * maxOvertimeBonus;
      monthlyOvertimeBonus = monthlyOvertimeBonus.clamp(0.0, maxOvertimeBonus);
    }
    
    // MONTHLY PERFORMANCE = (Hours × 45%) + (Quality × 55%) + OT Bonus
    final monthlyPerformance = (monthlyHoursScore * hoursWeight) + (qualityScore * qualityWeight) + monthlyOvertimeBonus;
    
    _logger.d('  Monthly: hours_score=$monthlyHoursScore, quality_score=$qualityScore, ot_bonus=$monthlyOvertimeBonus => $monthlyPerformance%');
    
    return {
      'currentPerformance': currentPerformance.clamp(0.0, 120.0),
      'monthlyPerformance': monthlyPerformance.clamp(0.0, 120.0),
      'daysWorked': daysWorked,
      'hoursScore': hoursScore,
      'qualityScore': qualityScore,
      'overtimeBonus': overtimeBonus,
      'monthlyHoursScore': monthlyHoursScore,
      'monthlyOvertimeBonus': monthlyOvertimeBonus,
    };
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Employees'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter name, email, job title, or department...',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            setState(() => _searchQuery = value.trim().toLowerCase());
          },
          onSubmitted: (value) {
            setState(() => _searchQuery = value.trim().toLowerCase());
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _searchQuery = '');
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 123, 31, 162),
            ),
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  void _showManualHoursDialog(String uid, String employeeName) {
    _logger.i('Opening manual hours dialog for: $employeeName (UID: $uid)');

    showDialog(
      context: context,
      builder: (context) => SupervisorManualHoursDialog(
        employeeId: uid,
        employeeName: employeeName,
      ),
    ).then((saved) {
      if (saved == true) {
        _logger.i('Manual entry saved, refreshing dashboard');
        setState(() {});
      }
    });
  }

  /// Read-only day-by-day history (approved/pending/rejected) for one
  /// employee/month — the closest equivalent of the old direct-entry
  /// dialog, now purely informational since actual submission happens on
  /// the employee side and approval happens via the Review Hours screen.
  void _showEmployeeHistoryDialog(String documentId, String employeeName) {
    final monthKey = DateFormat('yyyy-MM').format(_selectedMonth);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: 520,
          height: 520,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(employeeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(
                            DateFormat('MMMM yyyy').format(_selectedMonth),
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: StreamBuilder<List<DailyHoursEntry>>(
                  stream: HoursService().dailyEntriesStream(documentId, monthKey),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator(color: Color.fromARGB(255, 123, 31, 162)));
                    }
                    final entries = snapshot.data!;
                    if (entries.isEmpty) {
                      return const Center(child: Text('No entries this month', style: TextStyle(color: Colors.grey)));
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: entries.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        return ListTile(
                          title: Text(
                            '${DateFormat('MMM d, yyyy').format(entry.date)} — ${entry.hours.toStringAsFixed(2)} hrs',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          subtitle: Text(
                            '${entry.entryTime} → ${entry.exitTime}'
                            '${entry.isSupervisorEntered ? ' · Entered by Supervisor' : ''}'
                            '${entry.rejectionReason != null ? ' · Rejected: ${entry.rejectionReason}' : ''}',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                          trailing: _buildHoursStatusChip(entry.status),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHoursStatusChip(String status) {
    Color color;
    switch (status) {
      case HoursEntryStatus.approved:
        color = Colors.green;
        break;
      case HoursEntryStatus.rejected:
        color = Colors.red;
        break;
      default:
        color = Colors.orange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 11),
      ),
    );
  }

  Widget _buildAccessDeniedScreen() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.fromARGB(255, 123, 31, 162),
              Color.fromARGB(255, 156, 39, 176),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.lock_outline,
                      size: 80,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Access Restricted',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Only Supervisors, Admins, HR, and Accountants can access this dashboard.\n\nYour current role: ${_currentUserRole ?? 'Unknown'}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Go Back'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color.fromARGB(255, 123, 31, 162),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}