import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'tank_service.dart';
import 'dashboard_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _wifiCtrl   = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _form       = GlobalKey<FormState>();
  bool  _connecting = false;

  @override
  void initState() {
    super.initState();
    final svc = context.read<TankService>();
    _wifiCtrl.text   = svc.wifiUrl.isNotEmpty   ? svc.wifiUrl   : defaultWifiUrl;
    _mobileCtrl.text = svc.mobileUrl.isNotEmpty ? svc.mobileUrl : defaultMobileUrl;
  }

  @override
  void dispose() {
    _wifiCtrl.dispose();
    _mobileCtrl.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _connecting = true);

    final svc = context.read<TankService>();
    await svc.saveUrls(
      wifi:   _wifiCtrl.text.trim(),
      mobile: _mobileCtrl.text.trim(),
    );
    await svc.connectAuto(); // auto-picks based on current network

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _connecting = false);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 28),
              const Text(
                '💧 Tank Monitor',
                style: TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w700,
                  color: Color(0xFF1890ff),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Configure server addresses.\nThe app auto-selects based on your current network.',
                style: TextStyle(color: Color(0xFF8c8c8c), fontSize: 13),
              ),
              const SizedBox(height: 36),

              // ── WiFi URL ─────────────────────────────────────────────────
              const _FieldLabel(icon: Icons.wifi, color: Color(0xFF1890ff),
                text: 'WiFi / Home Network URL'),
              const SizedBox(height: 6),
              Form(
                key: _form,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _UrlField(
                    controller: _wifiCtrl,
                    hint: 'http://192.168.0.102:1880',
                    label: 'WiFi URL',
                  ),
                  const SizedBox(height: 6),
                  _DefaultChip(
                    label: 'Use default  192.168.0.102:1880',
                    onTap: () => setState(() => _wifiCtrl.text = defaultWifiUrl),
                  ),
                  const SizedBox(height: 24),

                  // ── Mobile URL ──────────────────────────────────────────
                  const _FieldLabel(icon: Icons.signal_cellular_alt,
                    color: Color(0xFFfa8c16), text: 'Mobile Data / Internet URL'),
                  const SizedBox(height: 6),
                  _UrlField(
                    controller: _mobileCtrl,
                    hint: 'http://nperiannan-nas.freemyip.com:1880',
                    label: 'Mobile URL',
                  ),
                  const SizedBox(height: 6),
                  _DefaultChip(
                    label: 'Use default  nperiannan-nas.freemyip.com:1880',
                    onTap: () => setState(() => _mobileCtrl.text = defaultMobileUrl),
                  ),
                ]),
              ),

              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF111b2e),
                  border: Border.all(color: const Color(0xFF1890ff).withOpacity(0.35)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(children: [
                  Icon(Icons.info_outline, color: Color(0xFF1890ff), size: 16),
                  SizedBox(width: 8),
                  Expanded(child: Text(
                    'On WiFi → uses WiFi URL automatically.\n'
                    'On mobile data → uses Mobile URL automatically.\n'
                    'Switches instantly if you change networks.',
                    style: TextStyle(color: Color(0xFF8c8c8c), fontSize: 12),
                  )),
                ]),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _connecting ? null : _connect,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1890ff),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _connecting
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                      : const Text('Save & Connect',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _FieldLabel({required this.icon, required this.color, required this.text});
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, color: color, size: 15),
    const SizedBox(width: 6),
    Text(text, style: const TextStyle(color: Color(0xFF8c8c8c), fontSize: 12)),
  ]);
}

class _UrlField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String label;
  const _UrlField({required this.controller, required this.hint, required this.label});

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    style: const TextStyle(color: Colors.white),
    keyboardType: TextInputType.url,
    autocorrect: false,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: Color(0xFF8c8c8c)),
      hintStyle: const TextStyle(color: Color(0xFF434343)),
      filled: true,
      fillColor: const Color(0xFF1f1f1f),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF303030))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF303030))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF1890ff))),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFff4d4f))),
    ),
    validator: (v) {
      if (v == null || v.trim().isEmpty) return 'Required';
      final uri = Uri.tryParse(v.trim());
      if (uri == null || !uri.scheme.startsWith('http')) {
        return 'Must start with http:// or https://';
      }
      return null;
    },
  );
}

class _DefaultChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _DefaultChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF1890ff).withOpacity(0.08),
        border: Border.all(color: const Color(0xFF1890ff).withOpacity(0.4)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text('↩ $label',
        style: const TextStyle(color: Color(0xFF1890ff), fontSize: 11)),
    ),
  );
}


