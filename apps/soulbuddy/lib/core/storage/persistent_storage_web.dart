import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<bool> requestBrowserPersistence() async {
  final granted = await web.window.navigator.storage.persist().toDart;
  return granted.toDart;
}
