import 'meditation_session.dart';

/// What the Prayer of attention needs to know about a background bed.
///
/// [MeditationSoundBed] implements this, and so does [WorshipSoundBed]. The two
/// stay separate enums on purpose: the shared `MeditationSoundPicker` renders
/// `MeditationSoundBed` values only, so worship music is not merely hidden from
/// the seven surfaces that use that picker, it is unreachable from them.
abstract interface class PrayerSoundBed {
  /// The persisted identifier. It is the enum's own name, so renaming a value
  /// discards anyone's saved choice of it rather than silently reassigning it.
  String get key;

  /// The plain name shown on the chip.
  String get label;

  /// The bundled asset, relative to `assets/`.
  String get assetPath;

  /// The level this bed is meant to sit at under a spoken prayer.
  double get preferredVolume;
}

/// Instrumental worship arrangements, offered only in the Prayer of attention.
///
/// These are complete songs rather than the short seamless loops the ambient
/// beds use. They are never repeated: an arrangement that has finished simply
/// ends, and the practice continues in quiet.
enum WorshipSoundBed implements PrayerSoundBed {
  tenThousandReasons(
    label: '10,000 Reasons',
    assetPath: 'audio/worship/10000_reasons_instrumental.mp3',
    preferredVolume: .20,
    duration: Duration(milliseconds: 261168),
  ),
  animaChristi(
    label: 'Anima Christi',
    assetPath: 'audio/worship/anima_christi_instrumental.mp3',
    preferredVolume: .10,
    duration: Duration(milliseconds: 160574),
  );

  const WorshipSoundBed({
    required this.label,
    required this.assetPath,
    required this.preferredVolume,
    required this.duration,
  });

  /// The enum's own name, which is what a saved preference stores.
  @override
  String get key => name;

  @override
  final String label;
  @override
  final String assetPath;

  /// Chosen against the file's own measured loudness, not against the other
  /// beds. `10000_reasons_instrumental.mp3` is -19.9 LUFS and
  /// `anima_christi_instrumental.mp3` is -15.6 LUFS, a 4.3 dB spread. These two
  /// gains put both at about -34 LUFS in the ear, which is ~15 dB below the
  /// spoken guide at -19 LUFS and ~1 dB below the loudest existing bed. A
  /// single shared number would have left one of them either too prominent or
  /// too far back to hear.
  @override
  final double preferredVolume;

  /// The decoded length of the bundled file: every MP3 frame in it.
  ///
  /// The fade begins this far back from the end rather than after it, which is
  /// what keeps the ending from being a cut. A rounded-up figure would put the
  /// last steps of the fade past the audio, and a rounded-down one would fade
  /// the music out while it was still meant to play, so
  /// `worship_sound_asset_test.dart` reads each file's frames back and fails
  /// if these no longer match.
  final Duration duration;
}
