import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'payroll_models.dart';
import 'payroll_providers.dart';

const _brandPurple = Color.fromARGB(255, 86, 10, 119);
const _brandPurpleLight = Color.fromARGB(255, 156, 39, 176);

/// Dialog exposing the configurable payroll knobs (overtime multiplier,
/// standard/max hours per day, standard monthly hours used to derive an
/// hourly rate from basic salary). Animates in with a scale+fade pop,
/// grouped into labeled sections with live per-field validation.
class PayrollSettingsDialog extends ConsumerStatefulWidget {
  final PayrollSettingsModel settings;

  const PayrollSettingsDialog({super.key, required this.settings});

  @override
  ConsumerState<PayrollSettingsDialog> createState() => _PayrollSettingsDialogState();
}

class _PayrollSettingsDialogState extends ConsumerState<PayrollSettingsDialog>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _overtimeMultiplier;
  late final TextEditingController _standardMonthlyHours;
  late final TextEditingController _standardHoursPerDay;
  late final TextEditingController _maxHoursPerDay;
  late final AnimationController _animController;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  bool _saving = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _overtimeMultiplier = TextEditingController(text: widget.settings.overtimeMultiplier.toString());
    _standardMonthlyHours = TextEditingController(text: widget.settings.standardMonthlyHours.toString());
    _standardHoursPerDay = TextEditingController(text: widget.settings.standardHoursPerDay.toString());
    _maxHoursPerDay = TextEditingController(text: widget.settings.maxHoursPerDay.toString());

    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
    _scaleAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOutBack);
    _fadeAnim = CurvedAnimation(parent: _animController, curve: const Interval(0, 0.6, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _overtimeMultiplier.dispose();
    _standardMonthlyHours.dispose();
    _standardHoursPerDay.dispose();
    _maxHoursPerDay.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth < 480 ? screenWidth * 0.92 : 440.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Container(
            width: dialogWidth,
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 30, offset: const Offset(0, 12)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionLabel('Overtime Rules', Icons.schedule),
                        const SizedBox(height: 12),
                        _field(
                          controller: _overtimeMultiplier,
                          label: 'Overtime Multiplier',
                          helper: 'e.g. 1.5 for time-and-a-half',
                          icon: Icons.trending_up,
                        ),
                        _field(
                          controller: _standardHoursPerDay,
                          label: 'Standard Hours / Day',
                          helper: 'Threshold above which hours count as overtime',
                          icon: Icons.wb_sunny_outlined,
                        ),
                        _field(
                          controller: _maxHoursPerDay,
                          label: 'Max Hours / Day',
                          helper: 'Cap applied when computing overtime',
                          icon: Icons.speed,
                        ),
                        const SizedBox(height: 8),
                        _sectionLabel('Salary Basis', Icons.payments_outlined),
                        const SizedBox(height: 12),
                        _field(
                          controller: _standardMonthlyHours,
                          label: 'Standard Monthly Hours',
                          helper: 'Used to derive hourly rate from basic salary',
                          icon: Icons.calendar_view_month,
                        ),
                      ],
                    ),
                  ),
                ),
                _buildActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 22, 20, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_brandPurple, _brandPurpleLight],
        ),
        borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.tune, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Payroll Settings', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 2),
                Text('Tune overtime & hours assumptions', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white, size: 20),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _brandPurple),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brandPurple, letterSpacing: 0.8),
        ),
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String helper,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          helperMaxLines: 2,
          prefixIcon: Icon(icon, size: 20, color: _brandPurple.withValues(alpha: 0.7)),
          filled: true,
          fillColor: const Color.fromARGB(255, 247, 244, 249),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _brandPurple, width: 1.6),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.redAccent, width: 1.4),
          ),
          errorText: controller.text.trim().isNotEmpty && double.tryParse(controller.text.trim()) == null
              ? 'Enter a valid number'
              : null,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _saved ? Colors.green : _brandPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _saving
                      ? const SizedBox(
                          key: ValueKey('saving'),
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : _saved
                          ? const Icon(Icons.check, key: ValueKey('saved'))
                          : const Text('Save Settings', key: ValueKey('save')),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final overtimeMultiplier = double.tryParse(_overtimeMultiplier.text.trim());
    final standardMonthlyHours = double.tryParse(_standardMonthlyHours.text.trim());
    final standardHoursPerDay = double.tryParse(_standardHoursPerDay.text.trim());
    final maxHoursPerDay = double.tryParse(_maxHoursPerDay.text.trim());

    if (overtimeMultiplier == null ||
        standardMonthlyHours == null ||
        standardHoursPerDay == null ||
        maxHoursPerDay == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid numbers in every field.'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _saving = true);
    final updated = widget.settings.copyWith(
      overtimeMultiplier: overtimeMultiplier,
      standardMonthlyHours: standardMonthlyHours,
      standardHoursPerDay: standardHoursPerDay,
      maxHoursPerDay: maxHoursPerDay,
    );
    final success = await ref.read(payrollServiceProvider).updateSettings(updated);

    if (!mounted) return;

    if (success) {
      setState(() {
        _saving = false;
        _saved = true;
      });
      await Future.delayed(const Duration(milliseconds: 450));
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved.'), backgroundColor: Colors.green),
      );
    } else {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save settings.'), backgroundColor: Colors.red),
      );
    }
  }
}
