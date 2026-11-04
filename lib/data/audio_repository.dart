import 'dart:convert';
import 'package:flutter/services.dart';

/// Đại diện cho một bản ghi âm thanh đã chuẩn hóa theo audio_manifest.json
class AudioTrack {
  final String id;
  final String lessonKey;
  final String section;
  final String? subskill;
  final List<String> activityNumbers;
  final int? printedPage;
  final String assetPath;
  final double durationSeconds;
  final int bytes;
  final String sha256;
  final String? sourcePageUrl;
  final String? sourceAudioUrl;
  final String? sourceLocalPath;
  final String? verification;

  const AudioTrack({
    required this.id,
    required this.lessonKey,
    required this.section,
    this.subskill,
    required this.activityNumbers,
    this.printedPage,
    required this.assetPath,
    required this.durationSeconds,
    required this.bytes,
    required this.sha256,
    this.sourcePageUrl,
    this.sourceAudioUrl,
    this.sourceLocalPath,
    this.verification,
  });

  factory AudioTrack.fromJson(Map<String, dynamic> json) {
    return AudioTrack(
      id: json['id'] as String,
      lessonKey: json['lessonKey'] as String,
      section: json['section'] as String,
      subskill: json['subskill'] as String?,
      activityNumbers: (json['activityNumbers'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      printedPage: json['printedPage'] as int?,
      assetPath: json['assetPath'] as String,
      durationSeconds: (json['durationSeconds'] as num?)?.toDouble() ?? 0.0,
      bytes: json['bytes'] as int? ?? 0,
      sha256: json['sha256'] as String? ?? '',
      sourcePageUrl: json['sourcePageUrl'] as String?,
      sourceAudioUrl: json['sourceAudioUrl'] as String?,
      sourceLocalPath: json['sourceLocalPath'] as String?,
      verification: json['verification'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'lessonKey': lessonKey,
        'section': section,
        'subskill': subskill,
        'activityNumbers': activityNumbers,
        'printedPage': printedPage,
        'assetPath': assetPath,
        'durationSeconds': durationSeconds,
        'bytes': bytes,
        'sha256': sha256,
        'sourcePageUrl': sourcePageUrl,
        'sourceAudioUrl': sourceAudioUrl,
        'sourceLocalPath': sourceLocalPath,
        'verification': verification,
      };

  String get formattedDuration {
    final totalSec = durationSeconds.round();
    final mins = totalSec ~/ 60;
    final secs = totalSec % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}

/// Kho quản lý và tra cứu âm thanh chuẩn hóa từ assets/data/audio_manifest.json
class AudioRepository {
  static final AudioRepository instance = AudioRepository._internal();
  AudioRepository._internal();

  List<AudioTrack> _tracks = [];
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;
  List<AudioTrack> get allTracks => List.unmodifiable(_tracks);

  /// Nạp danh mục audio từ assets/data/audio_manifest.json
  Future<void> load({String manifestAsset = 'assets/data/audio_manifest.json'}) async {
    if (_isLoaded) return;
    try {
      final jsonString = await rootBundle.loadString(manifestAsset);
      final Map<String, dynamic> data = jsonDecode(jsonString) as Map<String, dynamic>;
      final rawList = data['tracks'] as List<dynamic>? ?? [];
      _tracks = rawList
          .map((item) => AudioTrack.fromJson(item as Map<String, dynamic>))
          .toList();
      _isLoaded = true;
    } catch (e) {
      // Giữ danh sách rỗng nếu không đọc được file
      _tracks = [];
      _isLoaded = false;
      rethrow;
    }
  }

  /// Tra cứu track Listening cho bài học và số hoạt động cụ thể.
  /// Ví dụ: lessonKey = 'unit-01', activityNumber = '2'
  AudioTrack? getListeningTrack({
    required String lessonKey,
    required String activityNumber,
  }) {
    final normalizedKey = _normalizeLessonKey(lessonKey);
    final targetAct = activityNumber.trim();

    for (final track in _tracks) {
      if (track.section == 'listening' &&
          _normalizeLessonKey(track.lessonKey) == normalizedKey) {
        if (track.activityNumbers.contains(targetAct)) {
          return track;
        }
      }
    }
    return null;
  }

  /// Tra cứu tất cả track Listening của một bài học
  List<AudioTrack> getListeningTracksForLesson(String lessonKey) {
    final normalizedKey = _normalizeLessonKey(lessonKey);
    return _tracks
        .where((t) =>
            t.section == 'listening' &&
            _normalizeLessonKey(t.lessonKey) == normalizedKey)
        .toList();
  }

  /// Tra cứu track Reading của một bài học (Unit hoặc Review)
  AudioTrack? getReadingTrack({required String lessonKey}) {
    final normalizedKey = _normalizeLessonKey(lessonKey);
    for (final track in _tracks) {
      if (track.section == 'reading' &&
          _normalizeLessonKey(track.lessonKey) == normalizedKey) {
        return track;
      }
    }
    return null;
  }

  /// Tra cứu track Vocabulary Activity 1 của một bài học
  AudioTrack? getVocabularyTrack({required String lessonKey}) {
    final normalizedKey = _normalizeLessonKey(lessonKey);
    for (final track in _tracks) {
      if (track.section == 'language' &&
          track.subskill == 'vocabulary' &&
          _normalizeLessonKey(track.lessonKey) == normalizedKey) {
        return track;
      }
    }
    return null;
  }

  /// Kiểm tra xem một phân mục/hoạt động có audio thật hay không
  bool hasAudioFor({
    required String lessonKey,
    required String section,
    String? activityNumber,
  }) {
    final normalizedKey = _normalizeLessonKey(lessonKey);
    if (section == 'listening') {
      if (activityNumber != null) {
        return getListeningTrack(lessonKey: normalizedKey, activityNumber: activityNumber) != null;
      }
      return getListeningTracksForLesson(normalizedKey).isNotEmpty;
    } else if (section == 'reading') {
      return getReadingTrack(lessonKey: normalizedKey) != null;
    } else if (section == 'vocabulary') {
      return getVocabularyTrack(lessonKey: normalizedKey) != null;
    }
    return false;
  }

  /// Chuẩn hóa lessonKey: 'gs12_u01' -> 'unit-01', '1' -> 'unit-01', 'unit-1' -> 'unit-01'
  String _normalizeLessonKey(String raw) {
    final lower = raw.trim().toLowerCase();
    if (lower.startsWith('gs12_u') && lower.length >= 8) {
      final numStr = lower.substring(6);
      final n = int.tryParse(numStr);
      if (n != null) {
        return 'unit-${n.toString().padLeft(2, '0')}';
      }
    }
    if (lower.startsWith('gs12_review')) {
      final numStr = lower.replaceAll('gs12_review', '');
      final n = int.tryParse(numStr);
      if (n != null) {
        return 'review-${n.toString().padLeft(2, '0')}';
      }
    }
    if (lower.startsWith('review-')) {
      final parts = lower.split('-');
      if (parts.length > 1) {
        final n = int.tryParse(parts[1]);
        if (n != null) {
          return 'review-${n.toString().padLeft(2, '0')}';
        }
      }
    }
    if (lower.startsWith('review')) {
      final numStr = lower.replaceAll('review', '').replaceAll('_', '').replaceAll('-', '').trim();
      final n = int.tryParse(numStr);
      if (n != null) {
        return 'review-${n.toString().padLeft(2, '0')}';
      }
    }
    final intOnly = int.tryParse(lower);
    if (intOnly != null) {
      return 'unit-${intOnly.toString().padLeft(2, '0')}';
    }
    if (lower.startsWith('unit-')) {
      final parts = lower.split('-');
      if (parts.length > 1) {
        final n = int.tryParse(parts[1]);
        if (n != null) {
          return 'unit-${n.toString().padLeft(2, '0')}';
        }
      }
    }
    return lower;
  }
}

