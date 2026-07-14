import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'payroll_models.dart';
import 'payroll_providers.dart';

const _brandPurple = Color.fromARGB(255, 86, 10, 119);

/// Dialog for recording payment of a single [PayrollRecord]: payment method
/// + transaction reference.
class PayrollMarkPaidDialog extends ConsumerStatefulWidget {
  final PayrollRecord record;

  const PayrollMarkPaidDialog({super.key, required this.record});

  @override
  ConsumerState<PayrollMarkPaidDialog> createState() => _PayrollMarkPaidDialogState();
}

class _PayrollMarkPaidDialogState extends ConsumerState<PayrollMarkPaidDialog> {
  String _method = 'bank';
  final _refController = TextEditingController();
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Mark Paid — ${widget.record.employeeName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Net Pay: KES ${widget.record.netPay.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _method,
            decoration: const InputDecoration(labelText: 'Payment Method'),
            items: const [
              DropdownMenuItem(value: 'bank', child: Text('Bank Transfer')),
              DropdownMenuItem(value: 'mpesa', child: Text('M-Pesa')),
              DropdownMenuItem(value: 'airtel_money', child: Text('Airtel Money')),
            ],
            onChanged: (v) => setState(() => _method = v ?? 'bank'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _refController,
            decoration: const InputDecoration(labelText: 'Transaction Reference'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _confirm,
          style: ElevatedButton.styleFrom(backgroundColor: _brandPurple, foregroundColor: Colors.white),
          child: _saving
              ? const SizedBox(
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Confirm Paid'),
        ),
      ],
    );
  }

  Future<void> _confirm() async {
    if (_refController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a transaction reference.')),
      );
      return;
    }

    setState(() => _saving = true);
    final success = await ref.read(payrollServiceProvider).markRecordPaid(
          widget.record.id,
          paymentMethod: _method,
          transactionRef: _refController.text.trim(),
        );

    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Marked as paid.' : 'Could not update payment status.'),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }
}
