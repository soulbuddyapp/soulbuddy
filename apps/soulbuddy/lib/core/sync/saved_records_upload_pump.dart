import 'dart:async';

import 'package:powersync/powersync.dart';

import 'laravel_backend_connector.dart';

/// Which direction of the sync boundary is available.
enum SyncMode {
  /// No boundary is configured, so every record stays on the device.
  localOnly,

  /// Saved records reach Laravel; reads stay unavailable.
  uploadOnly,

  /// A sync service runs both directions.
  download,
}

/// Decides who drives uploads.
///
/// Exactly one driver may own the queue: the PowerSync SDK when a service is
/// reachable, otherwise this app. Running both would drain the same queue
/// concurrently.
///
/// A sync service cannot stand on its own. PowerSync authenticates against
/// Laravel for a token, so without that boundary there is nothing to connect
/// with and nothing to upload to.
SyncMode resolveSyncMode({
  required bool uploadConfigured,
  required bool downloadConfigured,
}) {
  if (!uploadConfigured) return SyncMode.localOnly;
  if (downloadConfigured) return SyncMode.download;
  return SyncMode.uploadOnly;
}

/// Sends locally saved records to the Laravel boundary without a sync service.
///
/// PowerSync uploads as part of connecting to a sync service. That connection
/// also opens the download stream, so with no service configured the SDK ends
/// every pass by asking the service for a write checkpoint, reports an upload
/// failure, and retries forever — even for records Laravel already accepted.
/// Reads are unavailable in that state regardless, so this drives the write
/// half on its own rather than letting a download dependency decide whether
/// anyone's prayers reach the server.
///
/// Exactly one path owns uploads at a time: when a sync service is configured
/// the SDK runs both directions and this is never started.
class SavedRecordsUploadPump {
  SavedRecordsUploadPump({
    required this.database,
    required this.connector,
    this.idleInterval = const Duration(seconds: 2),
    this.retryDelay = const Duration(seconds: 5),
    this.onError,
  });

  final PowerSyncDatabase database;
  final LaravelBackendConnector connector;

  /// How long to wait before looking for newly saved records. Nothing signals
  /// a local write, so the queue is polled; the wait ends early on [stop].
  final Duration idleInterval;

  /// How long to wait after a failed pass before trying the same records again.
  final Duration retryDelay;

  final void Function(Object error, StackTrace stackTrace)? onError;

  Completer<void>? _idle;
  bool _stopping = false;
  Future<void>? _loop;

  bool get isRunning => _loop != null && !_stopping;

  /// Begins draining. Safe to call once; further calls do nothing.
  void start() {
    _loop ??= _run();
  }

  /// Stops after the current pass and wakes an idle wait so it returns.
  Future<void> stop() async {
    if (_stopping) return;
    _stopping = true;
    _wakeIdle();
    await _loop;
    _loop = null;
  }

  /// Uploads every waiting record once, oldest first.
  ///
  /// Returns how many transactions reached the boundary. Throws whatever the
  /// connector throws so a caller can tell an unsent record from a sent one.
  Future<int> drain() async {
    var uploaded = 0;
    while (true) {
      final transaction = await database.getNextCrudTransaction();
      if (transaction == null) return uploaded;
      // Completes the transaction on acceptance, which clears it from the
      // queue. A throw leaves it queued, so the retry resends the same
      // records under the same operation ids and the boundary ignores them.
      // A refusal also clears it, so the issue is noted or the record is lost.
      await connector.uploadTransaction(
        transaction,
        recordIssue: (issue) => connector.recordIssue(issue, database),
      );
      uploaded++;
    }
  }

  Future<void> _run() async {
    while (!_stopping) {
      var uploaded = 0;
      try {
        uploaded = await drain();
      } catch (error, stackTrace) {
        onError?.call(error, stackTrace);
        await _sleep(retryDelay);
        continue;
      }
      // A pass that sent something may have left more behind; go straight
      // back rather than waiting a full interval for an empty queue.
      if (uploaded > 0) continue;
      await _sleep(idleInterval);
    }
  }

  Future<void> _sleep(Duration duration) async {
    final completer = Completer<void>();
    _idle = completer;
    try {
      await completer.future.timeout(duration, onTimeout: () {});
    } on TimeoutException {
      // The ordinary case: nothing to do, so look again after the wait.
    } finally {
      _idle = null;
    }
  }

  void _wakeIdle() {
    final completer = _idle;
    if (completer != null && !completer.isCompleted) completer.complete();
  }
}
