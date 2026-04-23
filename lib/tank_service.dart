import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'models.dart';

const _kWifiUrl   = 'wifi_url';
const _kMobileUrl = 'mobile_url';
const _kServerKey = 'server_url'; // legacy fallback
const _kAuthToken = 'auth_token';

const defaultWifiUrl   = 'http://192.168.0.102:1880';
const defaultMobileUrl = 'http://nperiannan-nas.freemyip.com:1880';

class TankService extends ChangeNotifier {
  // ── Auth ─────────────────────────────────────────────────────────────────
  String? authToken;
  bool unauthorized = false;
  // ── URL configuration ────────────────────────────────────────────────────
  String wifiUrl   = defaultWifiUrl;
  String mobileUrl = defaultMobileUrl;
  String _activeUrl = '';

  Status? status;
  bool connected = false;
  String? error;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  StreamSubscription? _netSub;
  bool _disposed = false;
  bool _reconnecting = false;

  String get serverUrl => _activeUrl;

  // ── Persistence ─────────────────────────────────────────────────────────

  Future<void> loadSavedUrls() async {
    final prefs = await SharedPreferences.getInstance();
    wifiUrl   = prefs.getString(_kWifiUrl)
              ?? prefs.getString(_kServerKey)  // legacy single-URL migration
              ?? defaultWifiUrl;
    mobileUrl = prefs.getString(_kMobileUrl) ?? defaultMobileUrl;
  }

  // Legacy compat used by old startup path
  Future<String?> loadSavedUrl() async {
    await loadSavedUrls();
    return wifiUrl.isNotEmpty ? wifiUrl : null;
  }

  Future<void> saveUrls({String? wifi, String? mobile}) async {
    if (wifi   != null) wifiUrl   = wifi.trimRight().replaceAll(RegExp(r'/$'), '');
    if (mobile != null) mobileUrl = mobile.trimRight().replaceAll(RegExp(r'/$'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kWifiUrl,   wifiUrl);
    await prefs.setString(_kMobileUrl, mobileUrl);
  }

  // ── Auth persistence ─────────────────────────────────────────────────────

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    authToken = prefs.getString(_kAuthToken);
  }

  Future<bool> login(String username, String password) async {
    error = null;
    try {
      final url = await _pickUrl();
      final res = await http.post(
        Uri.parse('$url/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        authToken = data['token'] as String?;
        if (authToken != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_kAuthToken, authToken!);
          unauthorized = false;
          notifyListeners();
          return true;
        }
      }
      error = res.statusCode == 401 ? 'Invalid username or password' : 'Login failed (${res.statusCode})';
      notifyListeners();
      return false;
    } catch (e) {
      error = 'Cannot reach server: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    authToken = null;
    unauthorized = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAuthToken);
    disconnect();
    notifyListeners();
  }

  // ── Network detection ────────────────────────────────────────────────────

  Future<String> _pickUrl() async {
    final result = await Connectivity().checkConnectivity();
    return result.contains(ConnectivityResult.wifi) ? wifiUrl : mobileUrl;
  }

  // ── Auto-connect (always picks URL based on current network) ─────────────

  Future<void> connectAuto() async {
    final url = await _pickUrl();
    connect(url);

    // React to network changes (WiFi ↔ mobile) while app is open
    _netSub?.cancel();
    _netSub = Connectivity().onConnectivityChanged.listen((results) async {
      if (_disposed) return;
      final newUrl = results.contains(ConnectivityResult.wifi) ? wifiUrl : mobileUrl;
      if (newUrl != _activeUrl) {
        connect(newUrl); // switch and reconnect with correct URL
      }
    });
  }

  // ── WebSocket ────────────────────────────────────────────────────────────

  void connect(String url) {
    _reconnecting = false;
    _closeChannel();
    _activeUrl = url.trimRight().replaceAll(RegExp(r'/$'), '');

    var wsUrl = _activeUrl
        .replaceFirst(RegExp(r'^http://'), 'ws://')
        .replaceFirst(RegExp(r'^https://'), 'wss://');

    if (authToken != null) {
      wsUrl = '$wsUrl/ws?token=${Uri.encodeComponent(authToken!)}';
    } else {
      wsUrl = '$wsUrl/ws';
    }

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _sub = _channel!.stream.listen(
        (data) {
          if (_disposed) return;
          try {
            status = Status.fromJson(jsonDecode(data as String) as Map<String, dynamic>);
            connected = true;
            error = null;
            notifyListeners();
          } catch (_) {}
        },
        onError: (e) {
          if (_disposed) return;
          // Detect 401 unauthorized from WS upgrade failure
          final msg = e.toString().toLowerCase();
          if (msg.contains('401') || msg.contains('unauthorized')) {
            unauthorized = true;
            authToken = null;
            SharedPreferences.getInstance().then((p) => p.remove(_kAuthToken));
            connected = false;
            notifyListeners();
            return;
          }
          connected = false;
          notifyListeners();
          _scheduleReconnect();
        },
        onDone: () {
          if (_disposed) return;
          connected = false;
          notifyListeners();
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
    } catch (e) {
      if (_disposed) return;
      connected = false;
      error = e.toString();
      notifyListeners();
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_disposed || _reconnecting) return;
    _reconnecting = true;
    Future.delayed(const Duration(seconds: 5), () {
      if (_disposed || !_reconnecting) return;
      _reconnecting = false;
      connectAuto(); // re-detect network on every reconnect attempt
    });
  }

  void _closeChannel() {
    _sub?.cancel();
    _channel?.sink.close();
    _sub = null;
    _channel = null;
  }

  void disconnect() {
    _reconnecting = false;
    _netSub?.cancel();
    _netSub = null;
    _closeChannel();
    connected = false;
    status = null;
    notifyListeners();
  }

  /// Call this when app comes back to foreground
  void reconnectIfNeeded() {
    if (!_disposed && !connected && !_reconnecting) {
      connectAuto();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    disconnect();
    super.dispose();
  }

  // ── Control API ──────────────────────────────────────────────────────────

  Future<void> sendControl(Map<String, dynamic> cmd) async {
    try {
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (authToken != null) headers['Authorization'] = 'Bearer $authToken';
      final res = await http.post(
        Uri.parse('$_activeUrl/api/control'),
        headers: headers,
        body: jsonEncode(cmd),
      ).timeout(const Duration(seconds: 8));
      if (res.statusCode == 401) {
        unauthorized = true;
        authToken = null;
        SharedPreferences.getInstance().then((p) => p.remove(_kAuthToken));
        notifyListeners();
        return;
      }
      if (res.statusCode != 200) {
        error = 'Control failed (${res.statusCode}): ${res.body}';
        notifyListeners();
        Future.delayed(const Duration(seconds: 4), () { error = null; notifyListeners(); });
      }
    } catch (e) {
      error = e.toString();
      notifyListeners();
      Future.delayed(const Duration(seconds: 4), () { error = null; notifyListeners(); });
    }
  }
}
