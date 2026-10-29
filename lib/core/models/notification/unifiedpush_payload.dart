import 'package:intl/intl.dart';

enum MediaServiceSource { radarr, sonarr, sabnzbd, unknown }

/// Encapsulates parsed event details from Radarr, Sonarr, or SABnzbd
class LunaSeaNotificationEvent {
  final MediaServiceSource source;
  final String eventType;
  final String title;
  final String? subtitle;
  final String? quality;
  final String? releaseGroup;
  final String? indexer;
  final int? sizeBytes;
  final String? downloadClient;
  final DateTime timestamp;
  final Map<String, dynamic> rawJson;

  LunaSeaNotificationEvent({
    required this.source,
    required this.eventType,
    required this.title,
    this.subtitle,
    this.quality,
    this.releaseGroup,
    this.indexer,
    this.sizeBytes,
    this.downloadClient,
    DateTime? timestamp,
    required this.rawJson,
  }) : timestamp = timestamp ?? DateTime.now();

  factory LunaSeaNotificationEvent.fromJson(Map<String, dynamic> json) {
    // 1. Radarr Detection
    if (json.containsKey('movie') || json.containsKey('remoteMovie')) {
      final movie = json['movie'] ?? json['remoteMovie'] ?? {};
      final release = json['release'] ?? {};
      final movieTitle = movie['title'] ?? 'Unknown Movie';
      final year = movie['year'] != null ? ' (${movie['year']})' : '';

      return LunaSeaNotificationEvent(
        source: MediaServiceSource.radarr,
        eventType: json['eventType'] ?? json['event'] ?? 'Grab',
        title: '$movieTitle$year',
        subtitle: release['releaseTitle'] ?? movie['overview'],
        quality: release['quality'] is Map
            ? release['quality']['name']
            : release['quality']?.toString(),
        releaseGroup: release['releaseGroup'],
        indexer: release['indexer'],
        sizeBytes: release['size'] is int
            ? release['size']
            : int.tryParse(release['size']?.toString() ?? ''),
        downloadClient: json['downloadClient'],
        rawJson: json,
      );
    }

    // 2. Sonarr Detection
    if (json.containsKey('series') || json.containsKey('episodes')) {
      final series = json['series'] ?? {};
      final release = json['release'] ?? {};
      final episodes = (json['episodes'] as List?) ?? [];
      final seriesTitle = series['title'] ?? 'Unknown Series';

      String epInfo = '';
      if (episodes.isNotEmpty) {
        final ep = episodes.first;
        final s = ep['seasonNumber']?.toString().padLeft(2, '0') ?? '00';
        final e = ep['episodeNumber']?.toString().padLeft(2, '0') ?? '00';
        final epTitle = ep['title'] != null ? ' - ${ep['title']}' : '';
        epInfo = ' [S${s}E${e}$epTitle]';
      }

      return LunaSeaNotificationEvent(
        source: MediaServiceSource.sonarr,
        eventType: json['eventType'] ?? json['event'] ?? 'Grab',
        title: '$seriesTitle$epInfo',
        subtitle: release['releaseTitle'],
        quality: release['quality'] is Map
            ? release['quality']['name']
            : release['quality']?.toString(),
        releaseGroup: release['releaseGroup'],
        indexer: release['indexer'],
        sizeBytes: release['size'] is int
            ? release['size']
            : int.tryParse(release['size']?.toString() ?? ''),
        downloadClient: json['downloadClient'],
        rawJson: json,
      );
    }

    // 3. SABnzbd Detection
    if (json.containsKey('status') && (json.containsKey('nzb_name') || json.containsKey('storage'))) {
      return LunaSeaNotificationEvent(
        source: MediaServiceSource.sabnzbd,
        eventType: json['status'] ?? 'Complete',
        title: json['nzb_name'] ?? 'SABnzbd Task',
        subtitle: json['category'] ?? 'Media',
        sizeBytes: json['bytes'] is int ? json['bytes'] : null,
        rawJson: json,
      );
    }

    // 4. Generic / Test Fallback
    return LunaSeaNotificationEvent(
      source: MediaServiceSource.unknown,
      eventType: json['eventType'] ?? 'Alert',
      title: json['title'] ?? json['message'] ?? 'Media Server Alert',
      subtitle: json['body'] ?? json['description'],
      rawJson: json,
    );
  }

  /// Clean notification headline
  String get formattedTitle {
    final prefix = switch (source) {
      MediaServiceSource.radarr => 'Radarr',
      MediaServiceSource.sonarr => 'Sonarr',
      MediaServiceSource.sabnzbd => 'SABnzbd',
      MediaServiceSource.unknown => 'LunaSea',
    };

    final verb = switch (eventType.toLowerCase()) {
      'grab' => 'Grabbed',
      'download' => 'Downloaded',
      'upgrade' => 'Upgraded',
      'rename' => 'Renamed',
      'health' => 'Health Warning',
      'test' => 'Connection Test',
      _ => eventType,
    };

    return '[$prefix] $verb: $title';
  }

  /// Clean, readable body breakdown
  String get formattedBody {
    final buffer = StringBuffer();
    if (quality != null && quality!.isNotEmpty) {
      buffer.write(quality);
    }
    if (releaseGroup != null && releaseGroup!.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.write(' · ');
      buffer.write(releaseGroup);
    }
    if (sizeBytes != null && sizeBytes! > 0) {
      if (buffer.isNotEmpty) buffer.write(' · ');
      buffer.write(_formatBytes(sizeBytes!));
    }
    if (indexer != null && indexer!.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.write(' · ');
      buffer.write(indexer);
    }

    if (buffer.isEmpty && subtitle != null) {
      return subtitle!;
    }
    return buffer.toString();
  }

  String get sourceTag => source.toString().split('.').last;

  Map<String, dynamic> toMap() {
    return {
      'source': sourceTag,
      'eventType': eventType,
      'title': title,
      'formattedTitle': formattedTitle,
      'formattedBody': formattedBody,
      'timestamp': timestamp.toIso8601String(),
      'rawJson': rawJson,
    };
  }

  static String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double count = bytes.toDouble();
    while (count >= 1024 && i < suffixes.length - 1) {
      count /= 1024;
      i++;
    }
    final formatter = NumberFormat('#,##0.#');
    return '${formatter.format(count)} ${suffixes[i]}';
  }
}

