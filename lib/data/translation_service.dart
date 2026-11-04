import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'rbac_proctor_ai_service.dart';
import 'trial_lesson_repository.dart';

/// Nguồn của kết quả dịch
enum TranslationSource {
  phraseDictionary, // Từ điển cụm từ SGK
  lessonVocabulary, // Từ vựng trọng tâm bài học SGK
  cache, // Bộ nhớ đệm (lưu các bản dịch đã tra trước đó)
  machineTranslation, // Dịch vụ dịch máy trực tuyến
  offlineCompiled, // Bản dịch biên soạn đối chiếu
}

/// Kết quả dịch văn bản chọn
class TranslationResult {
  final String originalText;
  final String translatedText;
  final TranslationSource source;
  final bool isSuccess;
  final String? errorMessage;
  final bool requiresNetwork;

  const TranslationResult({
    required this.originalText,
    required this.translatedText,
    required this.source,
    this.isSuccess = true,
    this.errorMessage,
    this.requiresNetwork = false,
  });

  /// Tạo kết quả báo lỗi ngoại tuyến / mất mạng
  factory TranslationResult.networkRequired(String text) {
    return TranslationResult(
      originalText: text,
      translatedText: '',
      source: TranslationSource.machineTranslation,
      isSuccess: false,
      requiresNetwork: true,
      errorMessage: 'Cần kết nối mạng để dịch phần văn bản này.',
    );
  }

  /// Tạo kết quả báo lỗi khác (timeout, lỗi hệ thống)
  factory TranslationResult.failure(String text, String error, {bool requiresNetwork = false}) {
    return TranslationResult(
      originalText: text,
      translatedText: '',
      source: TranslationSource.machineTranslation,
      isSuccess: false,
      requiresNetwork: requiresNetwork,
      errorMessage: error,
    );
  }

  String get sourceLabel {
    switch (source) {
      case TranslationSource.phraseDictionary:
        return 'Từ điển cụm từ SGK Tiếng Anh 12';
      case TranslationSource.lessonVocabulary:
        return 'Từ vựng bài học SGK Tiếng Anh 12';
      case TranslationSource.cache:
        return 'Bản dịch đã lưu trong bộ nhớ đệm';
      case TranslationSource.machineTranslation:
        return 'Dịch tự động trực tuyến (Đối chiếu)';
      case TranslationSource.offlineCompiled:
        return 'Bản dịch biên soạn SGK 12';
    }
  }
}

/// Dịch vụ dịch chuyên dụng, độc lập với widget:
/// - Quản lý bộ nhớ đệm cache (lưu trữ theo chuỗi văn bản + ngữ cảnh).
/// - Ưu tiên từ điển cụm từ & từ vựng bài học.
/// - Kết nối engine dịch trực tuyến qua dart:io HttpClient với timeout và xử lý ngoại tuyến trung thực.
/// - Không bao giờ giả mạo dịch hoặc lấy bản dịch cả đoạn văn đè vào.
class TranslationService {
  TranslationService._();
  static final TranslationService instance = TranslationService._();

  // Bộ nhớ đệm in-memory (tối đa 300 mục)
  final Map<String, TranslationResult> _cache = {};

  // Mock handler cho unit test
  Future<String?> Function(String text)? mockTranslator;

  /// Xóa cache (hữu ích cho kiểm thử)
  void clearCache() {
    _cache.clear();
  }

  /// Chuẩn hóa chuỗi văn bản
  String _normalizeKey(String text) {
    return text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Xây dựng khóa cache kết hợp văn bản + ngữ cảnh câu + mã bài học để tránh dùng nhầm nghĩa giữa các ngữ cảnh
  String _buildCacheKey({
    required String text,
    String? contextSentence,
    String? lessonId,
  }) {
    final normText = _normalizeKey(text);
    final normContext = (contextSentence != null && contextSentence.trim().isNotEmpty)
        ? _normalizeKey(contextSentence)
        : '';
    final lId = lessonId ?? '';
    if (normContext.isEmpty && lId.isEmpty) {
      return normText;
    }
    return '$normText||$normContext||$lId';
  }

  /// Dịch cụm từ hoặc đoạn ngắn được bôi đen
  Future<TranslationResult> translateSelection({
    required String text,
    TrialLessonData? currentLesson,
    String? contextSentence,
  }) async {
    if (ExamLockGuard.instance.isLocked) {
      return TranslationResult.failure(
        text,
        '🔒 Công cụ Dịch thuật đang bị khóa tạm thời vì bạn đang làm bài thi có giám sát (${ExamLockGuard.instance.activeExamTitle ?? "Phòng thi"}).',
      );
    }
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return const TranslationResult(
        originalText: '',
        translatedText: '',
        source: TranslationSource.machineTranslation,
        isSuccess: false,
        errorMessage: 'Văn bản được chọn rỗng.',
      );
    }

    final simpleKey = _normalizeKey(trimmed);
    final contextualCacheKey = _buildCacheKey(
      text: trimmed,
      contextSentence: contextSentence,
      lessonId: currentLesson?.lessonId,
    );

    // 1. Kiểm tra Cache theo ngữ cảnh trước
    if (_cache.containsKey(contextualCacheKey)) {
      final cached = _cache[contextualCacheKey]!;
      if (cached.isSuccess) {
        return TranslationResult(
          originalText: trimmed,
          translatedText: cached.translatedText,
          source: TranslationSource.cache,
        );
      }
    }

    // 2. Kiểm tra Từ điển cụm từ SGK 12
    if (TrialLessonRepository.phraseDictionary.containsKey(simpleKey)) {
      final meaning = TrialLessonRepository.phraseDictionary[simpleKey]!;
      final result = TranslationResult(
        originalText: trimmed,
        translatedText: meaning,
        source: TranslationSource.phraseDictionary,
      );
      _cache[contextualCacheKey] = result;
      return result;
    }

    // 3. Kiểm tra Từ vựng bài học hiện tại (ưu tiên bài hiện tại trước)
    if (currentLesson != null && currentLesson.vocabulary.containsKey(simpleKey)) {
      final meaning = currentLesson.vocabulary[simpleKey]!;
      final result = TranslationResult(
        originalText: trimmed,
        translatedText: meaning,
        source: TranslationSource.lessonVocabulary,
      );
      _cache[contextualCacheKey] = result;
      return result;
    }

    // 4. Kiểm tra từ điển các bài học khác
    for (final lesson in TrialLessonRepository.allLessons) {
      if (lesson.vocabulary.containsKey(simpleKey)) {
        final meaning = lesson.vocabulary[simpleKey]!;
        final result = TranslationResult(
          originalText: trimmed,
          translatedText: meaning,
          source: TranslationSource.lessonVocabulary,
        );
        _cache[contextualCacheKey] = result;
        return result;
      }
    }

    // 5. Kiểm tra Cache đơn giản (fallback nếu trước đó đã dịch văn bản này)
    if (_cache.containsKey(simpleKey)) {
      final cached = _cache[simpleKey]!;
      if (cached.isSuccess) {
        return TranslationResult(
          originalText: trimmed,
          translatedText: cached.translatedText,
          source: TranslationSource.cache,
        );
      }
    }

    // 5. Nếu có mock translator (phục vụ unit test)
    if (mockTranslator != null) {
      try {
        final translated = await mockTranslator!(trimmed);
        if (translated != null && translated.trim().isNotEmpty) {
          final result = TranslationResult(
            originalText: trimmed,
            translatedText: translated.trim(),
            source: TranslationSource.machineTranslation,
          );
          _cache[contextualCacheKey] = result;
          _cache[simpleKey] = result;
          return result;
        }
      } catch (e) {
        return TranslationResult.failure(trimmed, e.toString(), requiresNetwork: true);
      }
      return TranslationResult.networkRequired(trimmed);
    }

    // 6. Dịch máy trực tuyến (Online Machine Translation)
    try {
      final translated = await _fetchOnlineTranslation(trimmed);
      if (translated != null && translated.trim().isNotEmpty) {
        final result = TranslationResult(
          originalText: trimmed,
          translatedText: translated.trim(),
          source: TranslationSource.machineTranslation,
        );
        // Lưu vào cache
        if (_cache.length > 300) {
          _cache.remove(_cache.keys.first);
        }
        _cache[contextualCacheKey] = result;
        _cache[simpleKey] = result;
        return result;
      }
    } on TimeoutException {
      return TranslationResult.failure(
        trimmed,
        'Yêu cầu dịch quá thời gian chờ (timeout). Vui lòng thử lại.',
        requiresNetwork: true,
      );
    } catch (e) {
      debugPrint('[TranslationService] Online translate error: $e');
      return TranslationResult.networkRequired(trimmed);
    }

    // Nếu không dịch được và không có trong từ điển
    return TranslationResult.networkRequired(trimmed);
  }

  /// Gọi API dịch máy trực tuyến qua dart:io HttpClient với timeout an toàn
  Future<String?> _fetchOnlineTranslation(String text) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);

    // 1. Thử Google Translate API endpoint qua HTTP GET (nhanh, chuẩn xác)
    try {
      final gUri = Uri.parse(
        'https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=vi&dt=t&q=${Uri.encodeComponent(text)}',
      );
      final request = await client.getUrl(gUri).timeout(const Duration(seconds: 5));
      request.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)');
      final response = await request.close().timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final decoded = jsonDecode(body);
        if (decoded is List && decoded.isNotEmpty && decoded[0] is List) {
          final segments = decoded[0] as List;
          final buffer = StringBuffer();
          for (final seg in segments) {
            if (seg is List && seg.isNotEmpty && seg[0] != null) {
              buffer.write(seg[0].toString());
            }
          }
          final trans = buffer.toString().trim();
          if (trans.isNotEmpty) {
            client.close();
            return trans;
          }
        }
      }
    } catch (_) {
      // Thử fallback tiếp theo
    }

    // 2. Fallback sang MyMemory Translation API
    try {
      final mUri = Uri.parse(
        'https://api.mymemory.translated.net/get?q=${Uri.encodeComponent(text)}&langpair=en|vi',
      );
      final request = await client.getUrl(mUri).timeout(const Duration(seconds: 5));
      final response = await request.close().timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final decoded = jsonDecode(body);
        if (decoded is Map && decoded['responseData'] is Map) {
          final translated = decoded['responseData']['translatedText'] as String?;
          if (translated != null &&
              translated.trim().isNotEmpty &&
              !translated.contains('MYMEMORY WARNING')) {
            client.close();
            return translated.trim();
          }
        }
      }
    } catch (_) {
      // Lỗi cả 2 nguồn
    } finally {
      client.close();
    }

    return null;
  }

  /// Dịch 2 chiều (Anh -> Việt hoặc Việt -> Anh) phục vụ Trung tâm Dịch thuật Học thuật 3-trong-1
  Future<TranslationResult> translateBidirectional({
    required String text,
    String sourceLang = 'en',
    String targetLang = 'vi',
  }) async {
    if (ExamLockGuard.instance.isLocked) {
      return TranslationResult.failure(
        text,
        '🔒 Công cụ Dịch thuật đang bị khóa vì bạn đang trong Phòng thi có giám sát (${ExamLockGuard.instance.activeExamTitle ?? "Kiểm tra"}).',
      );
    }
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return TranslationResult.failure('', 'Vui lòng nhập hoặc nói nội dung cần dịch.');
    }

    if (sourceLang == 'en' && targetLang == 'vi') {
      return translateSelection(text: trimmed);
    }

    // Dịch Việt -> Anh
    final cacheKey = 'vi2en||${_normalizeKey(trimmed)}';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    // Kiểm tra đối chiếu ngược trong từ điển SGK 12
    final lower = _normalizeKey(trimmed);
    for (final entry in TrialLessonRepository.phraseDictionary.entries) {
      if (entry.value.toLowerCase() == lower || entry.value.toLowerCase().contains(lower)) {
        final res = TranslationResult(
          originalText: trimmed,
          translatedText: entry.key,
          source: TranslationSource.phraseDictionary,
        );
        _cache[cacheKey] = res;
        return res;
      }
    }

    // Gọi dịch máy trực tuyến Việt -> Anh
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    try {
      final gUri = Uri.parse(
        'https://translate.googleapis.com/translate_a/single?client=gtx&sl=$sourceLang&tl=$targetLang&dt=t&q=${Uri.encodeComponent(trimmed)}',
      );
      final request = await client.getUrl(gUri).timeout(const Duration(seconds: 5));
      request.headers.set('User-Agent', 'Mozilla/5.0');
      final response = await request.close().timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final decoded = jsonDecode(body);
        if (decoded is List && decoded.isNotEmpty && decoded[0] is List) {
          final buffer = StringBuffer();
          for (final seg in (decoded[0] as List)) {
            if (seg is List && seg.isNotEmpty && seg[0] != null) {
              buffer.write(seg[0].toString());
            }
          }
          final trans = buffer.toString().trim();
          if (trans.isNotEmpty) {
            final res = TranslationResult(
              originalText: trimmed,
              translatedText: trans,
              source: TranslationSource.machineTranslation,
            );
            _cache[cacheKey] = res;
            return res;
          }
        }
      }
    } catch (_) {
    } finally {
      client.close();
    }

    return TranslationResult.networkRequired(trimmed);
  }

  /// Rút trích danh sách từ vựng học thuật SGK 12 xuất hiện trong đoạn văn để học sinh lưu 1 chạm vào Flashcard SRS
  List<WordLookupResult> extractKeyVocabulary(String englishText) {
    final tokens = englishText
        .replaceAll(RegExp(r'[^a-zA-Z\s-]'), ' ')
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.length >= 4)
        .toSet();

    final extracted = <WordLookupResult>[];
    for (final token in tokens) {
      final lookup = TrialLessonRepository.instance.lookupWordOrPhrase(query: token);
      if (lookup.isFoundInDictionary) {
        extracted.add(lookup);
      }
      if (extracted.length >= 8) break;
    }
    return extracted;
  }
}
