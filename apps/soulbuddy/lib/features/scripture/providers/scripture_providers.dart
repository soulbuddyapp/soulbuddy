import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/bundled_scripture_source.dart';
import '../data/scripture_repository.dart';

final scriptureRepositoryProvider = Provider<ScriptureRepository>(
  (ref) => const BundledScriptureRepository(),
);
