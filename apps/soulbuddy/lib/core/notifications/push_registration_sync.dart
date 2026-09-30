import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

enum PushPermission { allowed, denied, undetermined }

enum PushSyncState { pending, registered, permissionDenied }

class PushRegistrationSync {
  PushRegistrationSync({
    required this.baseUri,
    required this.deviceId,
    required this.client,
    required this.readPushToken,
    required this.readSession,
    required this.refreshSession,
    required this.readPermission,
    required this.readTimeZone,
  });

  final Uri baseUri;
  final String deviceId;
  final http.Client client;
  final Future<String?> Function() readPushToken;
  final Future<String?> Function() readSession;
  final Future<void> Function() refreshSession;
  final Future<PushPermission> Function() readPermission;
  final Future<String> Function() readTimeZone;
  PushSyncState state = PushSyncState.pending;
  Timer? _retry;
  Completer<void>? _abortRequest;
  Future<void>? _inFlight;
  bool _dirty = false;
  bool _paused = false;
  bool _disposed = false;
  int _failures = 0;

  Future<void> synchronize() {
    if (_disposed || _paused) return Future.value();
    _retry?.cancel();
    if (_inFlight != null) {
      _dirty = true;
      return _inFlight!;
    }
    return _inFlight = _run().whenComplete(() => _inFlight = null);
  }

  Future<void> _run() async {
    do {
      _dirty = false;
      state = PushSyncState.pending;
      try {
        await _register();
      } on Exception {
        // No credentials or provider response bodies are logged. The next
        // foreground retry/resume repairs transient network and SDK failures.
      }
    } while (_dirty && !_disposed && !_paused);
    if (_disposed || _paused) return;
    if (state != PushSyncState.pending) {
      _failures = 0;
      return;
    }
    const delays = [5, 30, 120, 300];
    final seconds = delays[_failures.clamp(0, delays.length - 1)];
    _failures++;
    _retry = Timer(Duration(seconds: seconds), () => unawaited(synchronize()));
  }

  Future<void> _register() async {
    final permission = await readPermission();
    if (permission == PushPermission.undetermined || _disposed) return;
    final allowed = permission == PushPermission.allowed;
    final token = allowed ? await readPushToken() : null;
    if (_disposed) return;
    // A null token during SDK startup/offline recovery is NOT an opt-out.
    if (allowed && (token == null || token.isEmpty)) return;
    var session = await readSession();
    if (_disposed) return;
    if (session == null || session.isEmpty) {
      await refreshSession();
      session = await readSession();
    }
    if (session == null || session.isEmpty || _disposed) return;
    final zone = await readTimeZone();
    Future<http.Response> post(String session) async {
      final abort = Completer<void>();
      _abortRequest = abort;
      final request =
          http.AbortableRequest(
              'POST',
              baseUri.resolve('/api/installations/push'),
              abortTrigger: abort.future,
            )
            ..headers.addAll({
              'authorization': 'Bearer $session',
              'accept': 'application/json',
              'content-type': 'application/json',
            })
            ..body = jsonEncode({
              'device_id': deviceId,
              'push_token': token,
              'time_zone': zone,
            });
      try {
        return await client
            .send(request)
            .then(http.Response.fromStream)
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                if (!abort.isCompleted) abort.complete();
                throw TimeoutException('Push registration timed out.');
              },
            );
      } finally {
        if (identical(_abortRequest, abort)) _abortRequest = null;
      }
    }

    if (_disposed) return;
    var response = await post(session);
    if (response.statusCode == 401 && !_disposed) {
      await refreshSession();
      session = await readSession();
      if (session == null || session.isEmpty || _disposed) return;
      response = await post(session);
    }
    if (response.statusCode != 200 || _disposed) return;
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded['registered'] != allowed) {
      return;
    }
    state = allowed ? PushSyncState.registered : PushSyncState.permissionDenied;
  }

  void pause() {
    _paused = true;
    _retry?.cancel();
  }

  void resume() {
    _paused = false;
    _failures = 0;
    unawaited(synchronize());
  }

  void dispose() {
    _disposed = true;
    _retry?.cancel();
    final abort = _abortRequest;
    if (abort != null && !abort.isCompleted) abort.complete();
  }
}
