import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<Uint8List> readBlobAudio(String locator) async {
  final response = await web.window.fetch(locator.toJS).toDart;
  if (!response.ok) {
    throw StateError('The temporary recording could not be read.');
  }
  final buffer = await response.arrayBuffer().toDart;
  return Uint8List.fromList(buffer.toDart.asUint8List());
}

Future<void> releaseBlobAudio(String locator) async {
  web.URL.revokeObjectURL(locator);
}
