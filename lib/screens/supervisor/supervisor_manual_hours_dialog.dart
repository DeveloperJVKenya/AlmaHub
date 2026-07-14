import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

import '../../services/hours_service.dart';

/// Manual hours entry for a supervisor to log on behalf of an employee who
/// can't submit their own (e.g. no app access). This is the exception path,
/// not the default one — the default is the employee submitting their own
/// hours for supervisor review. Every entry made here requires a
/// justification note, is immediately marked approved (the supervisor is
/// personally asserting it), and always renders with an "Entered by
/// Supervisor" badge wherever it's shown, so it's never mistaken for an
/// independently-checked, self-reported entry.
class SupervisorManualHoursDialog extends StatefulWidget {
  final String employeeId;
  final String employeeName;

  const SupervisorManualHoursDialog({
    super.key,
    required this.employeeId,
    required this.employeeName,
  });

  @override
  State<SupervisorManualHoursDialog> createState() => _SupervisorManualHoursDialogState();
}

class _SupervisorManualHoursDialogState extends State<SupervisorManualHoursDialog> {
  final HoursService _hoursService = HoursService();
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
  final TextEditingController _noteController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _entryTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _exitTime = const TimeOfDay(hour: 17, minute: 0);
  int _breakMinutes = 60;
  bool _isSaving = false;
  double _calculatedHours = 8.0;

  @override
  void initState() {
    super.initState();
    _calculateHours();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _calculateHours() {
    final entry = DateTime(
      _selectedDate.year, _selectedDate.month, _selectedDate.day,
      _entryTime.hour, _entryTime.minute,
    );
    final exit = DateTime(
      _selectedDate.year, _selectedDate.month, _selectedDate.day,
      _exitTime.hour, _exitTime.minute,
    );
    final workMinutes = exit.difference(entry).inMinutes - _breakMinutes;
    setState(() {
      _calculatedHours = (workMinutes / 60.0).clamp(0.0, 12.0);
    });
  }

  Future<void> _save() async {
    if (_calculatedHours <= 0) {
      _showSnackBar('Invalid hours. Exit time must be after entry time + break.', Colors.red);
      return;
    }
    if (_noteController.text.trim().isEmpty) {
      _showSnackBar('A justification note is required for a manual entry.', Colors.red);
      return;
    }

    final supervisorUid = FirebaseAuth.instance.currentUser?.uid;
    if (supervisorUid == null) {
      _showSnackBar('Not signed in.', Colors.red);
      return;
    }

    setState(() => _isSaving = true);

    final entryTimeStr =
        '${_entryTime.hour.toString().padLeft(2, '0')}:${_entryTime.minute.toString().padLeft(2, '0')}';
    final exitTimeStr =
        '${_exitTime.hour.toString().padLeft(2, '0')}:${_exitTime.minute.toString().padLeft(2, '0')}';

    try {
      await _hoursService.submitSupervisorEntry(
        uid: widget.employeeId,
        date: _selectedDate,
        entryTime: entryTimeStr,
        exitTime: exitTimeStr,
        breakMinutes: _breakMinutes,
        hours: _calculatedHours,
        note: _noteController.text.trim(),
        supervisorUid: supervisorUid,
      );

      _logger.i('Manual entry saved for ${widget.employeeName}');

      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Manual entry saved for ${widget.employeeName}: '
              '${_calculatedHours.toStringAsFixed(2)} hrs on ${DateFormat('MMM dd, yyyy').format(_selectedDate)}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e, stackTrace) {
      _logger.e('Error saving manual entry', error: e, stackTrace: stackTrace);
      if (!mounted) return;
      _showSnackBar('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 550,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildWarningBanner(),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 20),
              _buildDateSelector(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildTimeSelector('Entry Time', _entryTime, true)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTimeSelector('Exit Time', _exitTime, false)),
                ],
              ),
              const SizedBox(height: 16),
              _buildBreakSelector(),
              const SizedBox(height: 16),
              _buildNoteField(),
              const SizedBox(height: 20),
              _buildHoursSummary(),
              const SizedBox(height: 24),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 123, 31, 162).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.edit_calendar, color: Color.fromARGB(255, 123, 31, 162), size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Manual Hours Entry', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(widget.employeeName, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
            ],
          ),
        ),
        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
      ],
    );
  }

  Widget _buildWarningBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        border: Border.all(color: Colors.amber.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.amber.shade800, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'For employees who cannot submit their own hours. This entry will be tagged '
              '"Entered by Supervisor" and marked approved immediately — use it sparingly.',
              style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return InkWell(
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
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: Color.fromARGB(255, 123, 31, 162)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Work Date', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSelector(String label, TimeOfDay time, bool isEntry) {
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(time.format(context), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Icon(Icons.access_time, color: Color.fromARGB(255, 123, 31, 162), size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border.all(color: Colors.orange.shade200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
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
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.orange : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isSelected ? Colors.orange : Colors.grey.shade300),
                  ),
                  child: Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey.shade700,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNoteField() {
    return TextField(
      controller: _noteController,
      maxLines: 2,
      decoration: InputDecoration(
        labelText: 'Justification (required)',
        hintText: 'Why is this being entered manually instead of by the employee?',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildHoursSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 123, 31, 162).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Total Hours:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          Text(
            '${_calculatedHours.toStringAsFixed(2)} hrs',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 123, 31, 162)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isSaving ? null : () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _isSaving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 123, 31, 162),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                  )
                : const Text('Save Entry', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
