import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/hours_models.dart';
import '../../providers/hours_providers.dart';

const _kPurple = Color.fromARGB(255, 123, 31, 162);

/// Supervisor's queue of employee-submitted hours awaiting approval.
/// Individual approve/reject follow the same confirm-dialog + colored
/// SnackBar pattern used for HR's onboarding approval
/// (`hr_dashboard.dart`'s `_approveEmployee`/`_rejectEmployee`), plus a
/// multi-select bulk-approve for straightforward days.
class HoursReviewScreen extends ConsumerStatefulWidget {
  final String? department; // null = all departments (Admin/HR/Accountant)

  const HoursReviewScreen({super.key, this.department});

  @override
  ConsumerState<HoursReviewScreen> createState() => _HoursReviewScreenState();
}

class _HoursReviewScreenState extends ConsumerState<HoursReviewScreen> {
  final Set<String> _selected = {}; // "documentId|dateKey"
  bool _isBusy = false;

  String get _supervisorUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(pendingHoursEntriesProvider(widget.department));
    final rosterAsync = ref.watch(departmentRosterProvider(widget.department));

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 240, 235, 245),
      appBar: AppBar(
        backgroundColor: _kPurple,
        title: Text(
          widget.department == null ? 'Review Hours — All Departments' : 'Review Hours — ${widget.department}',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: _kPurple)),
        error: (e, st) => Center(child: Text('Error: $e')),
        data: (entries) {
          if (entries.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text('No pending submissions', style: TextStyle(fontSize: 16, color: Colors.grey)),
                ],
              ),
            );
          }

          final roster = rosterAsync.value ?? {};

          // Group entries by employee uid.
          final byUid = <String, List<DailyHoursEntry>>{};
          for (final entry in entries) {
            byUid.putIfAbsent(entry.uid, () => []).add(entry);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: byUid.entries.map((group) {
              final uid = group.key;
              final employeeEntries = group.value;
              final info = roster[uid];
              final name = info?['fullname'] ?? 'Unknown Employee';
              final department = info?['department'] ?? '-';

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person, color: _kPurple),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                Text(department, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                              ],
                            ),
                          ),
                          Text('${employeeEntries.length} pending', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        ],
                      ),
                      const Divider(),
                      ...employeeEntries.map((entry) => _buildEntryRow(uid, entry)),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
      bottomNavigationBar: _selected.isNotEmpty ? _buildBulkApproveBar() : null,
    );
  }

  Widget _buildEntryRow(String uid, DailyHoursEntry entry) {
    // documentId is resolved lazily on action, but bulk-select needs a key
    // now — use uid|dateKey and resolve documentId at commit time.
    final selectionKey = '$uid|${entry.dateKey}';
    final isSelected = _selected.contains(selectionKey);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: isSelected,
            activeColor: _kPurple,
            onChanged: (value) {
              setState(() {
                if (value == true) {
                  _selected.add(selectionKey);
                } else {
                  _selected.remove(selectionKey);
                }
              });
            },
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      DateFormat('EEE, MMM d, yyyy').format(entry.date),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${entry.entryTime} → ${entry.exitTime}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _kPurple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${entry.hours.toStringAsFixed(2)} hrs',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _kPurple),
                      ),
                    ),
                    if (entry.isSupervisorEntered) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Entered by Supervisor',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.amber.shade900),
                        ),
                      ),
                    ],
                  ],
                ),
                if (entry.note != null && entry.note!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Note: ${entry.note}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.check_circle, size: 20, color: Colors.green),
            tooltip: 'Approve',
            onPressed: _isBusy ? null : () => _approve(uid, entry),
          ),
          IconButton(
            icon: const Icon(Icons.cancel, size: 20, color: Colors.red),
            tooltip: 'Reject',
            onPressed: _isBusy ? null : () => _reject(uid, entry),
          ),
        ],
      ),
    );
  }

  Widget _buildBulkApproveBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Text('${_selected.length} selected', style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _isBusy ? null : _bulkApprove,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              icon: const Icon(Icons.check_circle),
              label: const Text('Bulk Approve'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approve(String uid, DailyHoursEntry entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Hours'),
        content: Text(
          'Approve ${entry.hours.toStringAsFixed(2)} hrs on ${DateFormat('MMM d, yyyy').format(entry.date)}?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isBusy = true);
    try {
      final documentId = await ref.read(hoursServiceProvider).findDocumentId(uid);
      if (documentId == null) throw Exception('Employee record not found');
      await ref.read(hoursServiceProvider).approveEntry(
            documentId: documentId,
            dateKey: entry.dateKey,
            reviewerUid: _supervisorUid,
          );
      _selected.remove('$uid|${entry.dateKey}');
      if (!mounted) return;
      _showSnackBar('Hours approved', Colors.green);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Error approving hours: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _reject(String uid, DailyHoursEntry entry) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Hours'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rejecting ${entry.hours.toStringAsFixed(2)} hrs on ${DateFormat('MMM d, yyyy').format(entry.date)}.'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              autofocus: true,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Reason (required)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) return;
              Navigator.pop(context, reasonController.text.trim());
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty) return;

    setState(() => _isBusy = true);
    try {
      final documentId = await ref.read(hoursServiceProvider).findDocumentId(uid);
      if (documentId == null) throw Exception('Employee record not found');
      await ref.read(hoursServiceProvider).rejectEntry(
            documentId: documentId,
            dateKey: entry.dateKey,
            reviewerUid: _supervisorUid,
            reason: reason,
          );
      _selected.remove('$uid|${entry.dateKey}');
      if (!mounted) return;
      _showSnackBar('Hours rejected', Colors.orange);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Error rejecting hours: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _bulkApprove() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bulk Approve'),
        content: Text('Approve ${_selected.length} selected entries?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve All'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isBusy = true);
    try {
      // Group selection by uid -> dateKeys so each employee's doc is
      // batch-updated together.
      final byUid = <String, List<String>>{};
      for (final key in _selected) {
        final parts = key.split('|');
        byUid.putIfAbsent(parts[0], () => []).add(parts[1]);
      }

      for (final entry in byUid.entries) {
        final documentId = await ref.read(hoursServiceProvider).findDocumentId(entry.key);
        if (documentId == null) continue;
        await ref.read(hoursServiceProvider).bulkApprove(
              documentId: documentId,
              dateKeys: entry.value,
              reviewerUid: _supervisorUid,
            );
      }

      setState(() => _selected.clear());
      if (!mounted) return;
      _showSnackBar('Selected entries approved', Colors.green);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Error during bulk approval: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }
}
