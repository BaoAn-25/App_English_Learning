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
  final FlutterTts _tts = FlutterTts();

  VocabProvider(this._repo) {
    _initTts();
  }

  // ── Trạng thái chủ đề ─────────────────────────────────────────────────────
  List<Topic> _topics = [];
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
      notifyListeners();
    });
    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      notifyListeners();
    });
    _tts.setErrorHandler((_) {
      _isSpeaking = false;
      notifyListeners();
    });
  }

  // ── Load dữ liệu ──────────────────────────────────────────────────────────
  Future<void> loadTopics() async {
    _isLoading = true;
    Future.microtask(() => notifyListeners());
    try {
      _topics = await _repo.getTopicsByGrade(12);
      final allProgress = await _repo.getAllWordProgress();
      _progressMap = {for (final p in allProgress) p.wordId: p};
    } catch (e) {
      debugPrint('VocabProvider.loadTopics error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadWordsByTopic(String topicId) async {
    _isLoading = true;
    _selectedTopicId = topicId;
    Future.microtask(() => notifyListeners());
    try {
      _words = await _repo.getWordsByTopicId(topicId);
    } catch (e) {
      debugPrint('VocabProvider.loadWordsByTopic error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadDueWords() async {
    _isLoading = true;
    Future.microtask(() => notifyListeners());
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
      notifyListeners();
    }
  }

  // ── Cập nhật tiến độ SRS ──────────────────────────────────────────────────
  Future<void> markWordCorrect(String wordId) async {
    final existing = _progressMap[wordId] ?? WordProgress.newWord(wordId);
    final updated = existing.afterCorrect();
    _progressMap[wordId] = updated;
    await _repo.upsertWordProgress(updated);
    notifyListeners();
  }

  Future<void> markWordWrong(String wordId) async {
    final existing = _progressMap[wordId] ?? WordProgress.newWord(wordId);
    final updated = existing.afterWrong();
    _progressMap[wordId] = updated;
    await _repo.upsertWordProgress(updated);
    notifyListeners();
  }

  Future<void> markWordSeen(String wordId) async {
    if (_progressMap.containsKey(wordId)) return;
    final progress = WordProgress.newWord(wordId);
    _progressMap[wordId] = progress;
    await _repo.upsertWordProgress(progress);
    notifyListeners();
  }

  // ── Helpers thống kê ──────────────────────────────────────────────────────
  int learnedCountForTopic(String topicId) {
    final topicWords = _words.isNotEmpty && _selectedTopicId == topicId
        ? _words
        : <Word>[];
    return topicWords
        .where((w) => _progressMap[w.id]?.isLearned == true)
        .length;
  }

  int totalLearnedCount() =>
      _progressMap.values.where((p) => p.isLearned).length;

  int masteredCount() =>
      _progressMap.values.where((p) => p.isMastered).length;

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
    notifyListeners();
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }
}
