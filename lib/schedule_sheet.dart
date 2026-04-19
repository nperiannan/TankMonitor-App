import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'tank_service.dart';

const _cardBg = Color(0xFF1f1f1f);
const _blue   = Color(0xFF1890ff);
const _label  = Color(0xFF8c8c8c);
const _cardBd = Color(0xFF303030);

class ScheduleSheet extends StatefulWidget {
  final TankService svc;
  const ScheduleSheet({super.key, required this.svc});

  @override
  State<ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends State<ScheduleSheet> {
  int    _motor    = 0;         // 0 = OH, 1 = UG
  TimeOfDay _time  = TimeOfDay.now();
  final _durCtrl   = TextEditingController(text: '30');
  bool _submitting = false;

  @override
  void dispose() {
    _durCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: _blue),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _submit() async {
    final dur = int.tryParse(_durCtrl.text) ?? 0;
    if (dur < 1 || dur > 480) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Duration must be 1–480 minutes')));
      return;
    }
    setState(() => _submitting = true);
    final hh = _time.hour.toString().padLeft(2, '0');
    final mm = _time.minute.toString().padLeft(2, '0');
    await widget.svc.sendControl({
      'cmd': 'sched_add',
      'motor': _motor,
      'time': '$hh:$mm',
      'duration': dur,
    });
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(child: Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF434343),
              borderRadius: BorderRadius.circular(2)),
          )),
          const SizedBox(height: 16),
          const Text('Add Schedule',
            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),

          // Motor selector
          const Text('Motor', style: TextStyle(color: _label, fontSize: 12)),
          const SizedBox(height: 6),
          Row(children: [
            _MotorChip(label: 'OH — Overhead',   value: 0, group: _motor, onTap: () => setState(() => _motor = 0)),
            const SizedBox(width: 10),
            _MotorChip(label: 'UG — Underground', value: 1, group: _motor, onTap: () => setState(() => _motor = 1)),
          ]),
          const SizedBox(height: 16),

          // Time picker
          const Text('Start Time', style: TextStyle(color: _label, fontSize: 12)),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: _pickTime,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF141414),
                border: Border.all(color: _cardBd),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Duration
          const Text('Duration (minutes)', style: TextStyle(color: _label, fontSize: 12)),
          const SizedBox(height: 6),
          TextField(
            controller: _durCtrl,
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF141414),
              suffixText: 'min',
              suffixStyle: const TextStyle(color: _label),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _cardBd),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _cardBd),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _blue),
              ),
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _submitting
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Add Schedule', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _MotorChip extends StatelessWidget {
  final String label;
  final int value;
  final int group;
  final VoidCallback onTap;
  const _MotorChip({required this.label, required this.value, required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final selected = value == group;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? _blue.withOpacity(0.15) : const Color(0xFF141414),
            border: Border.all(color: selected ? _blue : _cardBd),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(child: Text(label,
            style: TextStyle(
              color: selected ? _blue : _label,
              fontSize: 12, fontWeight: FontWeight.w600))),
        ),
      ),
    );
  }
}
