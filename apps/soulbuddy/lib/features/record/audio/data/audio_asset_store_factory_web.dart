import 'package:idb_shim/idb_browser.dart';

import 'audio_asset_store.dart';
import 'audio_asset_store_web.dart';
import 'web_blob_audio.dart';

Future<AudioAssetStore> createAudioAssetStore() async => WebAudioAssetStore(
  idbFactory: idbFactoryBrowser,
  readTemporary: readBlobAudio,
  releaseTemporary: releaseBlobAudio,
);
