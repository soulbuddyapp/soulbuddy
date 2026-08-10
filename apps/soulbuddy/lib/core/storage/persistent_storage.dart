import 'persistent_storage_stub.dart'
    if (dart.library.js_interop) 'persistent_storage_web.dart'
    as platform;

enum PersistentStorageOutcome { granted, denied, unavailable }

Future<PersistentStorageOutcome> requestPersistentStorage({
  Future<bool> Function()? request,
}) async {
  try {
    final granted = await (request ?? platform.requestBrowserPersistence)();
    return granted
        ? PersistentStorageOutcome.granted
        : PersistentStorageOutcome.denied;
  } on Object {
    return PersistentStorageOutcome.unavailable;
  }
}
