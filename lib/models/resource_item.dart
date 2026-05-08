class ResourceItem {
  final String id;
  final ResourceType type;
  final String title;
  final String? subtitle;
  final String url;
  final String? cachedPath;
  final String? category;
  final int durationSeconds;

  const ResourceItem({
    required this.id,
    required this.type,
    required this.title,
    this.subtitle,
    required this.url,
    this.cachedPath,
    this.category,
    this.durationSeconds = 0,
  });

  bool get isCached => cachedPath != null;

  // Works with any file extension: .mp3 .wav .ogg .aac .flac .m4a
  bool get isAsset => url.startsWith('assets/');

  String get formattedDuration {
    if (durationSeconds == 0) return '';
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

enum ResourceType { affirmation, sound, guidedMeditation }

// ── Audio tracks ──────────────────────────────
// Supports any format just_audio handles: mp3, wav, ogg, aac, flac, m4a.
// Add the file to assets/audio/ then add an entry here.
// The url field accepts:
//   - 'assets/audio/filename.mp3'  (bundled asset)
//   - 'assets/audio/filename.wav'  (bundled asset, any format)
//   - 'https://...'                (remote URL)
class AudioTracks {
  AudioTracks._();

  static const List<ResourceItem> tracks = [

    // ── Currently available files ─────────────
    ResourceItem(
      id: 'ocean',
      type: ResourceType.sound,
      title: 'Ocean Waves',
      subtitle: 'Peaceful coastal sounds 1',
      url: 'assets/audio/toiletplungerstudios-ocean-vibes-391210.mp3',
      category: 'Nature',
    ),
    ResourceItem(
      id: 'rain',
      type: ResourceType.sound,
      title: 'Gentle Rain',
      subtitle: 'Calming rainfall sounds',
      url: 'assets/audio/milagrosgomez-dark-atmosphere-with-rain-352570.mp3',
      category: 'Nature',
    ),
    ResourceItem(
      id: 'tibetan_bowl',
      type: ResourceType.sound,
      title: 'Tibetan Singing Bowl Test',
      subtitle: 'Meditative tones',
      url: 'assets/audio/singing_bowl.mp3',
      category: 'Meditation',
    ),
    ResourceItem(
      id: 'test', 
      type: ResourceType.sound, 
      title: 'Test Sound', 
      subtitle: 'For testing purposes',
      url: 'assets/audio/test.mp3',
      category: 'Test',
    ),
     ResourceItem(
       id: 'forest',
       type: ResourceType.sound,
       title: 'Forest Birds',
       subtitle: 'Morning bird chorus Test',
       url: 'assets/audio/surprising_media-guitar-in-the-forest-439961.mp3',
       category: 'Nature',
     ),
     ResourceItem(
       id: 'white_noise',
       type: ResourceType.sound,
       title: 'White Noise',
       subtitle: 'Soft background noise test',
       url: 'assets/audio/white-noise.mp3',
       category: 'Focus',
     ),
     ResourceItem(
       id: 'binaural',
       type: ResourceType.sound,
       title: 'Binaural Beats',
       subtitle: 'Deep focus frequency test',
       url: 'assets/audio/siarhei_korbut-binaural-beat-5-hz-390077.mp3',
       category: 'Focus',
     ),
  ];
}
