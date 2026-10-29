import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../data/app_repository.dart';
import '../../data/models/topic.dart';
import '../../data/models/word.dart';
import '../../data/models/word_progress.dart';

/// Provider quản lý toàn bộ state cho màn hình Từ Vựng:
/// - Danh sách chủ đề, từ
/// - Tiến độ học từng từ (SRS)
/// - Phát âm TextToSpeech
class VocabProvider extends ChangeNotifier {
  final AppRepository _repo;
  bool _disposed = false;
  void _notifyIfActive() {
    if (!_disposed) notifyListeners();
  }

  final FlutterTts _tts = FlutterTts();

  VocabProvider(this._repo) {
    _initTts();
  }

  // ── Trạng thái chủ đề ─────────────────────────────────────────────────────
  List<Topic> _topics = [];
  Map<String, Set<String>> _topicWordIds = {};
  Set<String> _visibleWordIds = {};
  int get totalWordCount => _visibleWordIds.length;
  int wordCountForTopic(String topicId) => _topicWordIds[topicId]?.length ?? 0;
  int get dueWordCount => _visibleWordIds.where((id) {
    final progress = _progressMap[id];
    return progress != null && progress.isLearned && progress.isDue;
  }).length;
  List<Topic> get topics => _topics;

  // ── Trạng thái từ theo chủ đề ─────────────────────────────────────────────
  List<Word> _words = [];
  List<Word> get words => _words;

  String? _selectedTopicId;
  String? get selectedTopicId => _selectedTopicId;

  // ── Tiến độ ───────────────────────────────────────────────────────────────
  Map<String, WordProgress> _progressMap = {};
  Map<String, WordProgress> get progressMap => _progressMap;

  // ── SRS Review ────────────────────────────────────────────────────────────
  List<Word> _dueWords = [];
  List<Word> get dueWords => _dueWords;

  // ── TTS state ─────────────────────────────────────────────────────────────
  bool _isSpeaking = false;
  bool get isSpeaking => _isSpeaking;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // ── Khởi tạo TTS ──────────────────────────────────────────────────────────
  void _initTts() {
    _tts.setLanguage('en-US');
    _tts.setSpeechRate(0.45);
    _tts.setPitch(1.0);
    _tts.setStartHandler(() {
      _isSpeaking = true;
      _notifyIfActive();
    });
    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      _notifyIfActive();
    });
    _tts.setErrorHandler((_) {
      _isSpeaking = false;
      _notifyIfActive();
    });
  }

  // ── Load dữ liệu ──────────────────────────────────────────────────────────
  Future<void> loadTopics() async {
    _isLoading = true;
    _notifyIfActive();
    try {
      final topics = await _repo.getTopicsByGrade(12);
      final topicWordIds = <String, Set<String>>{};
      for (final topic in topics) {
        // Repository resolves legacy topic aliases; never infer membership from IDs.
        final words = await _repo.getWordsByTopicId(topic.id);
        topicWordIds[topic.id] = words.map((word) => word.id).toSet();
      }
      final allProgress = await _repo.getAllWordProgress();
      _topics = topics;
      _topicWordIds = topicWordIds;
      _visibleWordIds = topicWordIds.values.expand((ids) => ids).toSet();
      _progressMap = {for (final p in allProgress) p.wordId: p};
    } catch (e) {
      debugPrint('VocabProvider.loadTopics error: $e');
    } finally {
      _isLoading = false;
      _notifyIfActive();
    }
  }

  Future<void> loadWordsByTopic(String topicId) async {
    _isLoading = true;
    _selectedTopicId = topicId;
    _notifyIfActive();
    try {
      _words = await _repo.getWordsByTopicId(topicId);
    } catch (e) {
      debugPrint('VocabProvider.loadWordsByTopic error: $e');
    } finally {
      _isLoading = false;
      _notifyIfActive();
    }
  }

  Future<void> loadDueWords() async {
    _isLoading = true;
    _notifyIfActive();
    try {
      final dueProgress = await _repo.getDueWordProgress();
      final dueIds = dueProgress.map((p) => p.wordId).toSet();

      // Lấy tất cả words đã có progress và lọc theo due
      final allWords = await _repo.getAllWords();
      _dueWords = allWords.where((w) => dueIds.contains(w.id)).toList();
    } catch (e) {
      debugPrint('VocabProvider.loadDueWords error: $e');
    } finally {
      _isLoading = false;
      _notifyIfActive();
    }
  }

  // ── Cập nhật tiến độ SRS ──────────────────────────────────────────────────
  Future<void> markWordCorrect(String wordId) async {
    final existing = _progressMap[wordId] ?? WordProgress.newWord(wordId);
    final updated = existing.afterCorrect();
    await _repo.upsertWordProgress(updated);
    _progressMap[wordId] = updated;
    _notifyIfActive();
  }

  Future<void> markWordWrong(String wordId) async {
    final existing = _progressMap[wordId] ?? WordProgress.newWord(wordId);
    final updated = existing.afterWrong();
    await _repo.upsertWordProgress(updated);
    _progressMap[wordId] = updated;
    _notifyIfActive();
  }

  Future<void> markWordSeen(String wordId) async {
    if (_progressMap.containsKey(wordId)) return;
    final progress = WordProgress.newWord(wordId);
    await _repo.upsertWordProgress(progress);
    _progressMap[wordId] = progress;
    _notifyIfActive();
  }

  // ── Helpers thống kê ──────────────────────────────────────────────────────
  int learnedCountForTopic(String topicId) =>
      (_topicWordIds[topicId] ?? <String>{})
          .where((id) => _progressMap[id]?.isLearned == true)
          .length;

  int totalLearnedCount() =>
      _visibleWordIds.where((id) => _progressMap[id]?.isLearned == true).length;

  int masteredCount() => _visibleWordIds
      .where((id) => _progressMap[id]?.isMastered == true)
      .length;

  WordProgress progressOf(String wordId) =>
      _progressMap[wordId] ?? WordProgress.newWord(wordId);

  // ── Phát âm ───────────────────────────────────────────────────────────────
  Future<void> speak(String text) async {
    if (_isSpeaking) await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
    _isSpeaking = false;
    _notifyIfActive();
  }

  @override
  void dispose() {
    _disposed = true;
    _tts.stop();
    super.dispose();
  }
}
