import 'package:path_provider/path_provider.dart';

import 'audio_asset_store.dart';
import 'audio_asset_store_io.dart';

Future<AudioAssetStore> createAudioAssetStore() async => IoAudioAssetStore(
  applicationSupportDirectory: await getApplicationSupportDirectory(),
  temporaryDirectory: await getTemporaryDirectory(),
);
