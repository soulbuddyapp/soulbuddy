import 'package:flutter/material.dart';

import '../domain/encounter.dart';
import 'record_screen.dart';

/// The same private recording flow can be opened without leaving its source.
/// Returning an entry means its audio and metadata are already saved locally.
Future<Encounter?> showVoiceMemoryCapture(
  BuildContext context, {
  required String title,
  bool privateReflection = true,
  List<String> personIds = const [],
  DateTime? occurredOn,
}) => showModalBottomSheet<Encounter>(
  context: context,
  isScrollControlled: true,
  isDismissible: false,
  enableDrag: false,
  useSafeArea: true,
  builder: (sheetContext) => SizedBox(
    height: MediaQuery.sizeOf(sheetContext).height * .94,
    child: RecordScreen(
      startMode: personIds.isEmpty
          ? RecordStartMode.reflection
          : RecordStartMode.person,
      initialTitle: title,
      initialDate: occurredOn,
      initialPersonIds: personIds,
      privateReflection: privateReflection,
      onMemorySaved: (memory) => Navigator.pop(sheetContext, memory),
      onCancel: () => Navigator.pop(sheetContext),
    ),
  ),
);
