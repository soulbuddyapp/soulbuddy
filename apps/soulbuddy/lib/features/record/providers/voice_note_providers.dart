import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database_provider.dart';
import '../../../core/identity/local_identity_providers.dart';
import '../data/voice_note_repository.dart';

final voiceNoteRepositoryProvider = FutureProvider<VoiceNoteRepository>((
  ref,
) async {
  final database = await ref.watch(appDatabaseProvider.future);
  final identity = await ref.watch(localIdentityProvider.future);
  return VoiceNoteRepository(
    database: database.powersync,
    ownerId: identity.ownerId,
  );
});

final voiceNotesProvider = StreamProvider.autoDispose
    .family<List<VoiceNoteLink>, VoiceNoteContext>((ref, context) async* {
      final repository = await ref.watch(voiceNoteRepositoryProvider.future);
      yield* repository.watch(context);
    });
