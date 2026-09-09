enum MemorySoundscape {
  quiet(label: 'Quiet', assetPath: null),
  stillness(label: 'Stillness', assetPath: 'audio/meditation/stillness.mp3'),
  flowingWater(
    label: 'Flowing water',
    assetPath: 'audio/meditation/flowing_water.mp3',
  );

  const MemorySoundscape({required this.label, required this.assetPath});

  final String label;
  final String? assetPath;
}

class MemorySoundscapeSettings {
  const MemorySoundscapeSettings({
    required this.soundscape,
    required this.volume,
  });

  static const defaults = MemorySoundscapeSettings(
    soundscape: MemorySoundscape.quiet,
    volume: 0.15,
  );

  final MemorySoundscape soundscape;
  final double volume;

  MemorySoundscapeSettings get validated => MemorySoundscapeSettings(
    soundscape: soundscape,
    volume: volume.isFinite ? volume.clamp(0.0, 0.35) : defaults.volume,
  );

  MemorySoundscapeSettings copyWith({
    MemorySoundscape? soundscape,
    double? volume,
  }) => MemorySoundscapeSettings(
    soundscape: soundscape ?? this.soundscape,
    volume: volume ?? this.volume,
  ).validated;

  @override
  bool operator ==(Object other) =>
      other is MemorySoundscapeSettings &&
      other.soundscape == soundscape &&
      other.volume == volume;

  @override
  int get hashCode => Object.hash(soundscape, volume);
}
