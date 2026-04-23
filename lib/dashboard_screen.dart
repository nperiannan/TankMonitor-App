import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'models.dart';
import 'tank_service.dart';
import 'schedule_sheet.dart';
import 'setup_screen.dart';
import 'login_screen.dart';

// ─── Colours (mirrors Ant Design dark theme) ────────────────────────────────
const _bg      = Color(0xFF141414);
const _cardBg  = Color(0xFF1f1f1f);
const _cardBd  = Color(0xFF303030);
const _rowBd   = Color(0xFF303030);
const _label   = Color(0xFF8c8c8c);
const _blue    = Color(0xFF1890ff);
const _green   = Color(0xFF52c41a);
const _orange  = Color(0xFFfa8c16);
const _red     = Color(0xFFff4d4f);
// ─── Tank arc circle ─────────────────────────────────────────────────────────
class _TankCircle extends StatelessWidget {
  final String state;
  const _TankCircle(this.state);

  @override
  Widget build(BuildContext context) {
    double pct    = 0;
    Color  color  = _label;
    String label  = '--';
    bool   isUnknown = false;

    if (state == 'FULL')  { pct = 1.0; color = _green;  label = 'FULL'; }
    else if (state == 'LOW')  { pct = 0.3; color = _orange; label = 'LOW'; }
    else if (state == 'EMPTY'){ pct = 0.0; color = _red;    label = 'EMPTY'; }
    else if (state.isNotEmpty){ color = _orange; label = '?'; isUnknown = true; }

    return SizedBox(
      width: 100, height: 100,
      child: CustomPaint(
        painter: _ArcPainter(pct: pct, color: color),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: isUnknown ? 28 : 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double pct;
  final Color color;
  const _ArcPainter({required this.pct, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width / 2 - 6;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    // Track
    canvas.drawArc(rect, 0, 2 * pi, false,
      Paint()..color = const Color(0xFF303030)..style = PaintingStyle.stroke..strokeWidth = 8..strokeCap = StrokeCap.round);

    // Fill
    if (pct > 0) {
      canvas.drawArc(rect, -pi / 2, 2 * pi * pct, false,
        Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 8..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.pct != pct || old.color != color;
}

// ─── Motor status pill ────────────────────────────────────────────────────────
class _MotorPill extends StatelessWidget {
  final bool on;
  const _MotorPill(this.on);

  @override
  Widget build(BuildContext context) {
    final bg  = on ? const Color(0xFF162312) : const Color(0xFF2a1215);
    final clr = on ? _green : _red;
    final bd  = on ? const Color(0xFF274916) : const Color(0xFF58181c);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: bd),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('● ${on ? "ON" : "OFF"}',
        style: TextStyle(color: clr, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

// ─── Tank card ────────────────────────────────────────────────────────────────
class _TankCard extends StatelessWidget {
  final String title;
  final String tankState;
  final bool motorOn;
  final VoidCallback onOn;
  final VoidCallback onOff;

  const _TankCard({
    required this.title, required this.tankState, required this.motorOn,
    required this.onOn, required this.onOff,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        border: Border.all(color: _cardBd),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(title.toUpperCase(),
            style: const TextStyle(color: _label, fontSize: 10, letterSpacing: 1)),
          const SizedBox(height: 10),
          _TankCircle(tankState),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF262626), borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Motor', style: TextStyle(color: _label, fontSize: 11)),
                _MotorPill(motorOn),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: ElevatedButton(
              onPressed: onOn,
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              child: const Text('ON', style: TextStyle(fontSize: 13)),
            )),
            const SizedBox(width: 6),
            Expanded(child: ElevatedButton(
              onPressed: onOff,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2a1215), foregroundColor: _red,
                padding: const EdgeInsets.symmetric(vertical: 6),
                side: const BorderSide(color: _red),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              child: const Text('OFF', style: TextStyle(fontSize: 13)),
            )),
          ]),
        ],
      ),
    );
  }
}

// ─── Dashboard screen ─────────────────────────────────────────────────────────
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {

  double? _downloadProgress; // null = idle, 0.0–1.0 = downloading

  // OTA state
  bool _otaBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TankService>().checkForUpdate();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reconnect when app comes back from background
      context.read<TankService>().reconnectIfNeeded();
    }
  }

  Future<void> _downloadAndInstall() async {
    final svc = context.read<TankService>();
    final url = svc.latestApkUrl;
    if (url == null) return;
    setState(() => _downloadProgress = 0);
    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);
      final total = response.contentLength ?? 0;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/TankMonitor-update.apk');
      final sink = file.openWrite();
      int received = 0;
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (mounted) setState(() => _downloadProgress = total > 0 ? received / total : null);
      }
      await sink.flush();
      await sink.close();
      client.close();
      if (mounted) setState(() => _downloadProgress = null);
      await OpenFilex.open(file.path);
    } catch (e) {
      if (mounted) {
        setState(() => _downloadProgress = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    }
  }

  void _confirmFlash(BuildContext ctx, TankService svc) {
    showDialog(context: ctx, builder: (_) => AlertDialog(
      backgroundColor: _cardBg,
      title: const Text('Flash firmware to ESP32?', style: TextStyle(color: Colors.white)),
      content: const Text(
        'The ESP32 will download and install the staged firmware from the server, then reboot.',
        style: TextStyle(color: _label, fontSize: 13)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(
          onPressed: () async {
            Navigator.pop(ctx);
            setState(() => _otaBusy = true);
            await svc.triggerOta();
            if (mounted) setState(() => _otaBusy = false);
          },
          child: const Text('Flash', style: TextStyle(color: _blue)),
        ),
      ],
    ));
  }

  void _confirmRollback(BuildContext ctx, TankService svc) {
    showDialog(context: ctx, builder: (_) => AlertDialog(
      backgroundColor: _cardBg,
      title: const Text('Rollback firmware?', style: TextStyle(color: Colors.white)),
      content: const Text(
        'ESP32 will reboot into the previous OTA partition.',
        style: TextStyle(color: _label, fontSize: 13)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(
          onPressed: () async {
            Navigator.pop(ctx);
            setState(() => _otaBusy = true);
            await svc.triggerRollback();
            if (mounted) setState(() => _otaBusy = false);
          },
          child: const Text('Rollback', style: TextStyle(color: _red)),
        ),
      ],
    ));
  }

  void _logout() async {
    final svc = context.read<TankService>();
    await svc.logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<TankService>();
    final s   = svc.status;

    // All schedules shown; next-upcoming index per motor for highlight
    final enabledScheds = s?.schedules.toList() ?? [];
    final nextOHIdx = _nextScheduleIdx(
        enabledScheds.where((sc) => sc.m == 'OH').toList(), s?.time ?? '');
    final nextUGIdx = _nextScheduleIdx(
        enabledScheds.where((sc) => sc.m == 'UG').toList(), s?.time ?? '');
    // Navigate to login if token was invalidated
    if (svc.unauthorized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      });
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _cardBg,
        elevation: 0,
        title: const Text('💧 Tank Monitor',
          style: TextStyle(color: _blue, fontWeight: FontWeight.w700, fontSize: 18)),
        actions: [
          if (s?.time != null)
            Center(child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(_to12hr(s!.time), style: const TextStyle(color: _label, fontSize: 12)),
            )),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Row(children: [
              Icon(Icons.circle, size: 8,
                color: svc.connected ? _green : _red),
              const SizedBox(width: 4),
              Text(svc.connected ? 'Live' : 'Offline',
                style: const TextStyle(color: _label, fontSize: 12)),
            ]),
          ),
          IconButton(
            icon: const Icon(Icons.settings_ethernet, color: _label, size: 20),
            tooltip: 'Change server',
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const SetupScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: _label, size: 20),
            tooltip: 'Sign out',
            onPressed: _logout,
          ),
        ],
      ),
      body: svc.error != null
          ? _ErrorBanner(svc.error!)
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [

                if (svc.updateAvailable)
                  _UpdateBanner(
                    latestVersion: svc.latestAppVersion ?? '',
                    downloading: _downloadProgress != null,
                    progress: _downloadProgress,
                    onUpdate: _downloadAndInstall,
                  ),

                if (!svc.connected)
                  const _Banner('Disconnected — reconnecting…', isError: false),

                // ── Tank cards ──
                Row(children: [
                  Expanded(child: _TankCard(
                    title: 'Underground',
                    tankState: s?.ugState ?? '',
                    motorOn: s?.ugMotor ?? false,
                    onOn:  () => svc.sendControl({'cmd': 'ug_on'}),
                    onOff: () => svc.sendControl({'cmd': 'ug_off'}),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _TankCard(
                    title: 'Overhead',
                    tankState: s?.ohState ?? '',
                    motorOn: s?.ohMotor ?? false,
                    onOn:  () => svc.sendControl({'cmd': 'oh_on'}),
                    onOff: () => svc.sendControl({'cmd': 'oh_off'}),
                  )),
                ]),
                const SizedBox(height: 12),

                // ── Schedules ──
                _SectionCard(
                  title: 'MOTOR SCHEDULER',
                  trailing: Row(children: [
                    _SmallButton(
                      label: '+ Add',
                      onTap: () => showModalBottomSheet(
                        context: context, isScrollControlled: true,
                        backgroundColor: _cardBg,
                        builder: (_) => ScheduleSheet(svc: svc),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _SmallButton(
                      label: 'Clear All', danger: true,
                      onTap: () => _confirmClear(context, svc),
                    ),
                  ]),
                  child: s == null || s.schedules.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(child: Text('No schedules configured',
                            style: TextStyle(color: _label, fontSize: 13))),
                        )
                      : Column(
                          children: enabledScheds.map((sch) =>
                            _ScheduleRow(
                              sch: sch,
                              svc: svc,
                              isNext: sch.i == nextOHIdx || sch.i == nextUGIdx,
                            )).toList(),
                        ),
                ),
                const SizedBox(height: 10),

                // ── Settings ──
                _SectionCard(
                  title: 'SETTINGS',
                  child: Column(children: [
                    _SettingRow('OH Display Only',         s?.ohDispOnly,  (v) => svc.sendControl({'cmd': 'set_setting', 'key': 'oh_disp_only', 'value': v})),
                    _SettingRow('UG Display Only',         s?.ugDispOnly,  (v) => svc.sendControl({'cmd': 'set_setting', 'key': 'ug_disp_only', 'value': v})),
                    _SettingRow('Ignore UG for OH Motor',  s?.ugIgnore,    (v) => svc.sendControl({'cmd': 'set_setting', 'key': 'ug_ignore',    'value': v})),
                    _SettingRow('Buzzer Delay Before Start',s?.buzzerDelay,(v) => svc.sendControl({'cmd': 'set_setting', 'key': 'buzzer_delay', 'value': v}), last: true),
                  ]),
                ),
                const SizedBox(height: 10),

                // ── Actions ──
                _SectionCard(
                  title: 'ACTIONS',
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      _ActionButton(
                        label: 'Sync NTP',
                        icon: Icons.sync,
                        enabled: s != null,
                        onTap: () => svc.sendControl({'cmd': 'sync_ntp'}),
                      ),
                      const SizedBox(width: 10),
                      _ActionButton(
                        label: 'Reboot',
                        icon: Icons.power_settings_new,
                        danger: true,
                        enabled: s != null,
                        onTap: () => _confirmReboot(context, svc),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 10),

                // ── Firmware OTA ──
                _SectionCard(
                  title: 'FIRMWARE UPDATE (OTA)',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(child: Text(
                          'Current: ${s?.fw ?? '—'}',
                          style: const TextStyle(color: _label, fontSize: 12),
                        )),
                      ]),
                      const SizedBox(height: 4),
                      const Text(
                        'Upload a firmware.bin via the web app, then trigger flash here.',
                        style: TextStyle(color: _label, fontSize: 11),
                      ),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: _ActionButton(
                          label: _otaBusy ? 'Working…' : 'Flash Firmware',
                          icon: Icons.bolt,
                          enabled: s != null && !_otaBusy,
                          onTap: () => _confirmFlash(context, svc),
                        )),
                        const SizedBox(width: 10),
                        Expanded(child: _ActionButton(
                          label: 'Rollback',
                          icon: Icons.history,
                          danger: true,
                          enabled: s != null && !_otaBusy,
                          onTap: () => _confirmRollback(context, svc),
                        )),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // ── System info ──
                _SectionCard(
                  title: 'SYSTEM',
                  child: Column(children: [
                    _InfoRow('WiFi',        s != null ? '${s.wifiRssi} dBm' : '—'),
                    _InfoRow('LoRa',        null, loraOk: s?.loraOk),
                    _InfoRow('Uptime',      s != null ? _formatUptime(s.uptimeS) : '—'),
                    _InfoRow('Firmware',    s?.fw ?? '—'),
                    _InfoRow('Web App',     svc.webAppVersion ?? '—'),
                    _InfoRow('Mobile App',  mobileAppVersion),
                    _InfoRow('Last update', svc.connected ? 'Live' : '—', last: true),
                  ]),
                ),
                const SizedBox(height: 20),
              ],
            ),
    );
  }

  void _confirmClear(BuildContext ctx, TankService svc) {
    showDialog(context: ctx, builder: (_) => AlertDialog(
      backgroundColor: _cardBg,
      title: const Text('Clear all schedules?', style: TextStyle(color: Colors.white)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(
          onPressed: () { Navigator.pop(ctx); svc.sendControl({'cmd': 'sched_clear'}); },
          child: const Text('Clear', style: TextStyle(color: _red)),
        ),
      ],
    ));
  }

  void _confirmReboot(BuildContext ctx, TankService svc) {
    showDialog(context: ctx, builder: (_) => AlertDialog(
      backgroundColor: _cardBg,
      title: const Text('Reboot ESP32?', style: TextStyle(color: Colors.white)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(
          onPressed: () { Navigator.pop(ctx); svc.sendControl({'cmd': 'reboot'}); },
          child: const Text('Reboot', style: TextStyle(color: _red)),
        ),
      ],
    ));
  }
} // end _DashboardScreenState

// ─── Helpers ─────────────────────────────────────────────────────────────────

/// Converts "HH:MM" or "HH:MM:SS" (24hr) to "H:MM AM/PM"
String _to12hr(String t) {
  try {
    final parts = t.split(':');
    int h = int.parse(parts[0]);
    final m = parts[1].padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    h = h % 12;
    if (h == 0) h = 12;
    return '$h:$m $period';
  } catch (_) {
    return t;
  }
}

/// Returns the index (i) of the next upcoming schedule in [scheds] relative to [currentTime] (HH:MM[:SS]).
int? _nextScheduleIdx(List<Schedule> scheds, String currentTime) {
  if (scheds.isEmpty || currentTime.isEmpty) return null;
  try {
    final parts = currentTime.split(':');
    final nowMins = int.parse(parts[0]) * 60 + int.parse(parts[1]);
    int? nextIdx;
    int minDiff = 999999;
    for (final sch in scheds) {
      final tp = sch.t.split(':');
      final schedMins = int.parse(tp[0]) * 60 + int.parse(tp[1]);
      int diff = schedMins - nowMins;
      if (diff <= 0) diff += 24 * 60;
      if (diff < minDiff) { minDiff = diff; nextIdx = sch.i; }
    }
    return nextIdx;
  } catch (_) {
    return null;
  }
}

String _formatUptime(int s) {
  if (s < 60)   return '${s}s';
  if (s < 3600) return '${s ~/ 60}m ${s % 60}s';
  return '${s ~/ 3600}h ${(s % 3600) ~/ 60}m';
}

class _UpdateBanner extends StatelessWidget {
  final String latestVersion;
  final bool downloading;
  final double? progress;
  final VoidCallback onUpdate;

  const _UpdateBanner({
    required this.latestVersion,
    required this.downloading,
    required this.progress,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF162312),
        border: Border.all(color: _green),
        borderRadius: BorderRadius.circular(8),
      ),
      child: downloading
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Downloading v$latestVersion…',
                    style: const TextStyle(color: _green, fontSize: 13)),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: const Color(0xFF274916),
                  color: _green,
                ),
                if (progress != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('${(progress! * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(color: _label, fontSize: 11)),
                  ),
              ],
            )
          : Row(
              children: [
                const Icon(Icons.system_update, color: _green, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Update available: v$latestVersion  (current v$mobileAppVersion)',
                    style: const TextStyle(color: _green, fontSize: 13),
                  ),
                ),
                GestureDetector(
                  onTap: onUpdate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF274916),
                      border: Border.all(color: _green),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Update',
                        style: TextStyle(color: _green, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
    );
  }
}

class _Banner extends StatelessWidget {
  final String msg;
  final bool isError;
  const _Banner(this.msg, {this.isError = true});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: isError ? const Color(0xFF2a1215) : const Color(0xFF2b2111),
      border: Border.all(color: isError ? _red : _orange),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(msg, style: TextStyle(color: isError ? _red : _orange, fontSize: 13)),
  );
}

class _ErrorBanner extends StatelessWidget {
  final String msg;
  const _ErrorBanner(this.msg);

  @override
  Widget build(BuildContext context) =>
    Padding(padding: const EdgeInsets.all(16), child: _Banner(msg));
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const _SectionCard({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _cardBg, border: Border.all(color: _cardBd),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text(title,
          style: const TextStyle(color: _label, fontSize: 10, letterSpacing: 1))),
        if (trailing != null) trailing!,
      ]),
      const SizedBox(height: 10),
      child,
    ]),
  );
}

class _SmallButton extends StatelessWidget {
  final String label;
  final bool danger;
  final VoidCallback onTap;
  const _SmallButton({required this.label, required this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: danger ? const Color(0xFF2a1215) : _blue.withOpacity(0.15),
        border: Border.all(color: danger ? _red : _blue),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
        style: TextStyle(color: danger ? _red : _blue, fontSize: 12, fontWeight: FontWeight.w600)),
    ),
  );
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool danger;
  final bool enabled;
  final VoidCallback onTap;
  const _ActionButton({required this.label, required this.icon, required this.onTap,
    this.danger = false, this.enabled = true});

  @override
  Widget build(BuildContext context) => Expanded(
    child: OutlinedButton.icon(
      onPressed: enabled ? onTap : null,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: danger ? _red : Colors.white70,
        side: BorderSide(color: danger ? _red : _cardBd),
        padding: const EdgeInsets.symmetric(vertical: 10),
      ),
    ),
  );
}

class _ScheduleRow extends StatelessWidget {
  final Schedule sch;
  final TankService svc;
  final bool isNext;
  const _ScheduleRow({required this.sch, required this.svc, this.isNext = false});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 3),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: isNext
        ? BoxDecoration(
            color: const Color(0xFF162312),
            border: const Border(
              left: BorderSide(color: _green, width: 3),
            ),
            borderRadius: BorderRadius.circular(4),
          )
        : const BoxDecoration(),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: sch.m == 'OH' ? const Color(0xFF111b2e) : const Color(0xFF1a1135),
          border: Border.all(color: sch.m == 'OH' ? _blue : const Color(0xFF722ed1)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(sch.m,
          style: TextStyle(
            color: sch.m == 'OH' ? _blue : const Color(0xFFb37feb),
            fontSize: 11, fontWeight: FontWeight.w700)),
      ),
      const SizedBox(width: 8),
      Text(_to12hr(sch.t), style: const TextStyle(color: Colors.white, fontSize: 13)),
      const SizedBox(width: 6),
      Text('${sch.d} min', style: const TextStyle(color: _label, fontSize: 12)),
      if (isNext) ...[        
        const SizedBox(width: 6),
        const Text('Next', style: TextStyle(color: _green, fontSize: 11, fontWeight: FontWeight.w600)),
      ],
      const Spacer(),
      IconButton(
        icon: const Icon(Icons.edit_outlined, color: _blue, size: 18),
        padding: EdgeInsets.zero, constraints: const BoxConstraints(),
        tooltip: 'Edit',
        onPressed: () => showModalBottomSheet(
          context: context, isScrollControlled: true,
          backgroundColor: _cardBg,
          builder: (_) => ScheduleSheet(svc: svc, editSchedule: sch),
        ),
      ),
      const SizedBox(width: 4),
      IconButton(
        icon: const Icon(Icons.delete_outline, color: _red, size: 18),
        padding: EdgeInsets.zero, constraints: const BoxConstraints(),
        onPressed: () => svc.sendControl({'cmd': 'sched_remove', 'index': sch.i}),
      ),
    ]),
  );
}

class _SettingRow extends StatelessWidget {
  final String label;
  final bool? value;
  final void Function(bool) onChange;
  final bool last;
  const _SettingRow(this.label, this.value, this.onChange, {this.last = false});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(
      border: last ? null : const Border(bottom: BorderSide(color: _rowBd))),
    child: Row(children: [
      Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13))),
      Switch(
        value: value ?? false,
        onChanged: value == null ? null : onChange,
        activeColor: _blue,
      ),
    ]),
  );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String? value;
  final bool? loraOk;
  final bool last;
  const _InfoRow(this.label, this.value, {this.loraOk, this.last = false});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 7),
    decoration: BoxDecoration(
      border: last ? null : const Border(bottom: BorderSide(color: _rowBd))),
    child: Row(children: [
      Text(label, style: const TextStyle(color: _label, fontSize: 13)),
      const Spacer(),
      if (loraOk != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: loraOk! ? const Color(0xFF162312) : const Color(0xFF2a1215),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(loraOk! ? 'OK' : 'FAIL',
            style: TextStyle(color: loraOk! ? _green : _red, fontSize: 11, fontWeight: FontWeight.w700)),
        )
      else
        Text(value ?? '—', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 13)),
    ]),
  );
}
