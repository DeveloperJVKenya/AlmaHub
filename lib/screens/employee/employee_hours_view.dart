import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

import '../../models/hours_models.dart';
import '../../providers/hours_providers.dart';

const _kPurple = Color.fromARGB(255, 84, 4, 108);

/// Employee's own work-hours screen: submit a day's hours for supervisor
/// review, track approval status, and see the running approved total for
/// the month (the same number Payroll will use). Submissions start
/// `pending`; while pending or rejected they can be edited and resubmitted,
/// but once approved they're locked — the supervisor is the only one who
/// can reopen an approved entry (from the Review Hours screen), and always
/// with a reason.
class EmployeeHoursView extends ConsumerStatefulWidget {
  const EmployeeHoursView({super.key});

  @override
  ConsumerState<EmployeeHoursView> createState() => _EmployeeHoursViewState();
}

class _EmployeeHoursViewState extends ConsumerState<EmployeeHoursView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;
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

  String? _employeeId; // EmployeeDetails doc id
  String? _employeeName;
  bool _isLoading = true;
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadEmployeeInfo();
  }

  Future<void> _loadEmployeeInfo() async {
    if (_currentUser == null) return;

    try {
      final query = await _firestore
          .collection('EmployeeDetails')
          .where('personalInfo.email', isEqualTo: _currentUser.email)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data();
        setState(() {
          _employeeId = query.docs.first.id;
          _employeeName = data['personalInfo']?['fullName'] ?? 'Unknown';
          _isLoading = false;
        });
        _logger.i('Loaded employee: $_employeeName (ID: $_employeeId)');
      } else {
        setState(() => _isLoading = false);
        _logger.w('Employee not found in EmployeeDetails');
      }
    } catch (e) {
      _logger.e('Error loading employee info', error: e);
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_employeeId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Work Hours'), backgroundColor: _kPurple),
        body: const Center(child: Text('Employee record not found')),
      );
    }

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 245, 245, 250),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildEmployeeHeader(),
          _buildMonthSelector(),
          _buildMonthlySummary(),
          Expanded(child: _buildDailyHoursList()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _kPurple,
        icon: const Icon(Icons.add),
        label: const Text('Log Today\'s Hours'),
        onPressed: () => _openSubmissionForm(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: _kPurple,
      title: const Text('My Work Hours', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildEmployeeHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_kPurple, Color.fromARGB(255, 120, 6, 152)]),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.person, size: 32, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Employee', style: TextStyle(fontSize: 12, color: Colors.white70)),
                const SizedBox(height: 4),
                Text(_employeeName ?? 'Unknown', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_month, color: _kPurple, size: 20),
          const SizedBox(width: 12),
          const Text('Viewing Month:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: _kPurple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('MMMM yyyy').format(_selectedMonth),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _kPurple),
                  ),
                  PopupMenuButton<DateTime>(
                    icon: const Icon(Icons.arrow_drop_down, color: _kPurple),
                    onSelected: (newMonth) => setState(() => _selectedMonth = newMonth),
                    itemBuilder: (context) {
                      final now = DateTime.now();
                      return List.generate(12, (i) => DateTime(now.year, now.month - i, 1))
                          .map((month) => PopupMenuItem(value: month, child: Text(DateFormat('MMMM yyyy').format(month))))
                          .toList();
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlySummary() {
    final monthKey = DateFormat('yyyy-MM').format(_selectedMonth);

    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('EmployeeDetails').doc(_employeeId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final hoursWorked = data?['hoursWorked'] as Map<String, dynamic>? ?? {};
        final monthlyTotal = (hoursWorked[monthKey] ?? 0).toDouble();

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Approved Hours This Month', style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500)),
                  SizedBox(height: 2),
                  Text('Only supervisor-approved days count toward payroll', style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: _kPurple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                child: Text(
                  '${monthlyTotal.toStringAsFixed(1)} hrs',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _kPurple),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDailyHoursList() {
    final monthKey = DateFormat('yyyy-MM').format(_selectedMonth);
    final entriesAsync = ref.watch(dailyHoursEntriesProvider((documentId: _employeeId!, monthKey: monthKey)));

    return entriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
      data: (entries) {
        if (entries.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.access_time_outlined, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text('No hours logged for ${DateFormat('MMMM').format(_selectedMonth)}', style: const TextStyle(fontSize: 16, color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
          itemCount: entries.length,
          itemBuilder: (context, index) => _buildEntryCard(entries[index]),
        );
      },
    );
  }

  Widget _buildEntryCard(DailyHoursEntry entry) {
    final canEdit = !entry.isSupervisorEntered && (entry.isPending || entry.isRejected);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(DateFormat('EEEE').format(entry.date), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(DateFormat('MMM dd, yyyy').format(entry.date), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                Row(
                  children: [
                    _buildStatusChip(entry.status),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(color: _kPurple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        '${entry.hours.toStringAsFixed(2)} hrs',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _kPurple),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildTimeDetail('Entry', entry.entryTime)),
                Container(width: 1, height: 40, color: Colors.grey.shade300),
                Expanded(child: _buildTimeDetail('Exit', entry.exitTime)),
              ],
            ),
            if (entry.isSupervisorEntered) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.supervisor_account, size: 14, color: Colors.amber.shade800),
                  const SizedBox(width: 6),
                  Text('Entered by Supervisor', style: TextStyle(fontSize: 12, color: Colors.amber.shade900, fontWeight: FontWeight.w600)),
                ],
              ),
              if (entry.note != null && entry.note!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Note: ${entry.note}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
                ),
            ],
            if (entry.isRejected && entry.rejectionReason != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Rejected: ${entry.rejectionReason}', style: TextStyle(fontSize: 12, color: Colors.red.shade900)),
                    ),
                  ],
                ),
              ),
            ],
            if (canEdit) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _openSubmissionForm(existing: entry),
                  icon: const Icon(Icons.edit, size: 16),
                  label: Text(entry.isRejected ? 'Edit & Resubmit' : 'Edit'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String text;
    switch (status) {
      case HoursEntryStatus.approved:
        color = Colors.green;
        text = 'Approved';
        break;
      case HoursEntryStatus.rejected:
        color = Colors.red;
        text = 'Rejected';
        break;
      default:
        color = Colors.orange;
        text = 'Pending';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _buildTimeDetail(String label, String time) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.access_time, size: 16, color: Colors.grey.shade700),
            const SizedBox(width: 6),
            Text(time, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  void _openSubmissionForm({DailyHoursEntry? existing}) {
    showDialog(
      context: context,
      builder: (context) => _EmployeeHoursSubmissionDialog(
        employeeUid: _currentUser!.uid,
        existing: existing,
      ),
    );
  }
}

/// Submission/resubmission form for an employee's own daily hours.
class _EmployeeHoursSubmissionDialog extends ConsumerStatefulWidget {
  final String employeeUid;
  final DailyHoursEntry? existing;

  const _EmployeeHoursSubmissionDialog({required this.employeeUid, this.existing});

  @override
  ConsumerState<_EmployeeHoursSubmissionDialog> createState() => _EmployeeHoursSubmissionDialogState();
}

class _EmployeeHoursSubmissionDialogState extends ConsumerState<_EmployeeHoursSubmissionDialog> {
  late DateTime _selectedDate;
  late TimeOfDay _entryTime;
  late TimeOfDay _exitTime;
  int _breakMinutes = 60;
  final TextEditingController _noteController = TextEditingController();
  bool _isSaving = false;
  double _calculatedHours = 8.0;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _selectedDate = existing?.date ?? DateTime.now();
    _entryTime = _parseTime(existing?.entryTime) ?? const TimeOfDay(hour: 8, minute: 0);
    _exitTime = _parseTime(existing?.exitTime) ?? const TimeOfDay(hour: 17, minute: 0);
    _breakMinutes = existing?.breakMinutes ?? 60;
    _noteController.text = existing?.note ?? '';
    _calculateHours();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  TimeOfDay? _parseTime(String? value) {
    if (value == null) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    return TimeOfDay(hour: int.tryParse(parts[0]) ?? 8, minute: int.tryParse(parts[1]) ?? 0);
  }

  void _calculateHours() {
    final entry = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _entryTime.hour, _entryTime.minute);
    final exit = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _exitTime.hour, _exitTime.minute);
    final workMinutes = exit.difference(entry).inMinutes - _breakMinutes;
    setState(() => _calculatedHours = (workMinutes / 60.0).clamp(0.0, 12.0));
  }

  Future<void> _save() async {
    if (_calculatedHours <= 0) {
      _showSnackBar('Invalid hours. Exit time must be after entry time + break.', Colors.red);
      return;
    }

    setState(() => _isSaving = true);

    final entryTimeStr = '${_entryTime.hour.toString().padLeft(2, '0')}:${_entryTime.minute.toString().padLeft(2, '0')}';
    final exitTimeStr = '${_exitTime.hour.toString().padLeft(2, '0')}:${_exitTime.minute.toString().padLeft(2, '0')}';

    try {
      await ref.read(hoursServiceProvider).submitEmployeeEntry(
            uid: widget.employeeUid,
            date: _selectedDate,
            entryTime: entryTimeStr,
            exitTime: exitTimeStr,
            breakMinutes: _breakMinutes,
            hours: _calculatedHours,
            note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
          );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hours submitted for supervisor review'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.existing == null ? 'Log Today\'s Hours' : 'Edit & Resubmit',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const Divider(),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 90)),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                    _calculateHours();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: _kPurple),
                      const SizedBox(width: 12),
                      Text(DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildTimeField('Entry Time', _entryTime, true)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTimeField('Exit Time', _exitTime, false)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [30, 60, 90].map((minutes) {
                  final label = minutes == 60 ? '1 hour' : (minutes == 90 ? '1.5 hours' : '30 min');
                  final isSelected = _breakMinutes == minutes;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: InkWell(
                        onTap: () {
                          setState(() => _breakMinutes = minutes);
                          _calculateHours();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? _kPurple : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isSelected ? _kPurple : Colors.grey.shade300),
                          ),
                          child: Center(
                            child: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey.shade700, fontSize: 12)),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _noteController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Note (optional)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: _kPurple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Hours:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    Text('${_calculatedHours.toStringAsFixed(2)} hrs', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _kPurple)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(backgroundColor: _kPurple, foregroundColor: Colors.white),
                      child: _isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                          : const Text('Submit for Review'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeField(String label, TimeOfDay time, bool isEntry) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(context: context, initialTime: time);
        if (picked != null) {
          setState(() {
            if (isEntry) {
              _entryTime = picked;
            } else {
              _exitTime = picked;
            }
          });
          _calculateHours();
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 6),
            Text(time.format(context), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
