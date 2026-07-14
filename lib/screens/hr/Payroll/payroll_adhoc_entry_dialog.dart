import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'payroll_models.dart';
import 'payroll_providers.dart';

const _brandPurple = Color.fromARGB(255, 86, 10, 119);

/// Dialog letting HR add/edit run-specific (one-off) allowances and
/// deductions for a single [PayrollRecord] — e.g. a bonus or an advance
/// recovery that only applies to this pay run.
class PayrollAdhocEntryDialog extends ConsumerStatefulWidget {
  final PayrollRecord record;

  const PayrollAdhocEntryDialog({super.key, required this.record});

  @override
  ConsumerState<PayrollAdhocEntryDialog> createState() => _PayrollAdhocEntryDialogState();
}

class _PayrollAdhocEntryDialogState extends ConsumerState<PayrollAdhocEntryDialog> {
  late List<_Entry> _allowances;
  late List<_Entry> _deductions;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _allowances = widget.record.adhocAllowances.entries
        .map((e) => _Entry(TextEditingController(text: e.key), TextEditingController(text: e.value.toString())))
        .toList();
    _deductions = widget.record.adhocDeductions.entries
        .map((e) => _Entry(TextEditingController(text: e.key), TextEditingController(text: e.value.toString())))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Ad-hoc Entries — ${widget.record.employeeName}'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSection('One-off Allowances (e.g. bonus)', _allowances, Colors.green),
              const SizedBox(height: 16),
              _buildSection('One-off Deductions (e.g. advance recovery)', _deductions, Colors.red),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(backgroundColor: _brandPurple, foregroundColor: Colors.white),
          child: _saving
              ? const SizedBox(
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildSection(String title, List<_Entry> entries, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: accent)),
        const SizedBox(height: 8),
        for (int i = 0; i < entries.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: entries[i].label,
                    decoration: const InputDecoration(labelText: 'Label', isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: entries[i].amount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Amount (KES)', isDense: true),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                  onPressed: () => setState(() => entries.removeAt(i)),
                ),
              ],
            ),
          ),
        TextButton.icon(
          onPressed: () => setState(
            () => entries.add(_Entry(TextEditingController(), TextEditingController())),
          ),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add entry'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    final allowancesMap = <String, double>{
      for (final e in _allowances)
        if (e.label.text.trim().isNotEmpty && double.tryParse(e.amount.text.trim()) != null)
          e.label.text.trim(): double.parse(e.amount.text.trim()),
    };
    final deductionsMap = <String, double>{
      for (final e in _deductions)
        if (e.label.text.trim().isNotEmpty && double.tryParse(e.amount.text.trim()) != null)
          e.label.text.trim(): double.parse(e.amount.text.trim()),
    };

    final success = await ref.read(payrollServiceProvider).updateRecordAdhocEntries(
          widget.record.id,
          adhocAllowances: allowancesMap,
          adhocDeductions: deductionsMap,
        );

    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Record updated.' : 'Could not update record (run may be locked).'),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }
}

class _Entry {
  final TextEditingController label;
  final TextEditingController amount;
  _Entry(this.label, this.amount);
}
