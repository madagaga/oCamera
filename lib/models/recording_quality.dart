/// Bitrate of the clips recorded on the viewer. The plugin re-encodes the
/// decoded frames, so the bitrate is chosen here rather than inherited from
/// the stream. Sizes are for a one hour clip.
enum RecordingQuality {
  economy('Economy', 120000), // ~55 MB / hour
  normal('Normal', 250000), // ~110 MB / hour
  high('High', 500000); // ~225 MB / hour

  const RecordingQuality(this.label, this.bitrate);

  final String label;

  /// Bits per second.
  final int bitrate;

  String get approxSize => switch (this) {
        RecordingQuality.economy => '≈ 55 MB per hour',
        RecordingQuality.normal => '≈ 110 MB per hour',
        RecordingQuality.high => '≈ 225 MB per hour',
      };

  static const storageKey = 'recordingQuality';

  static RecordingQuality fromName(String? name) =>
      values.firstWhere((q) => q.name == name, orElse: () => normal);
}
