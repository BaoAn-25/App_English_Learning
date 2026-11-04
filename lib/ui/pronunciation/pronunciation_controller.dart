import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../data/models/ipa_sound.dart';
import '../../data/models/minimal_pair_question.dart';
import '../../data/pronunciation_repository.dart';
import '../auth/auth_controller.dart';

class PronunciationController extends ChangeNotifier {
  final PronunciationRepository _repo;
  final FlutterTts _tts = FlutterTts();

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  List<IpaSound> _allSounds = [];
  List<MinimalPairQuestion> _minimalPairs = [];

  List<IpaSound> get allSounds => _allSounds;
  List<IpaSound> get vowels => _allSounds.where((s) => s.isVowel).toList();
  List<IpaSound> get diphthongs => _allSounds.where((s) => s.isDiphthong).toList();
  List<IpaSound> get consonants => _allSounds.where((s) => s.isConsonant).toList();
  List<MinimalPairQuestion> get minimalPairs => _minimalPairs;

  IpaSound? _activePlayingSound;
  IpaSound? get activePlayingSound => _activePlayingSound;

  PronunciationController({PronunciationRepository? repo})
      : _repo = repo ?? PronunciationRepository() {
    _initTts();
    loadData();
  }

  void _initTts() {
    try {
      _tts.setLanguage('en-US');
      _tts.setSpeechRate(0.42);
      _tts.setVolume(1.0);
      _tts.setPitch(1.0);
    } catch (_) {}
  }

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final currentUserId = AuthController.instance.isAuthenticated
          ? AuthController.instance.user.id
          : '';
      _allSounds = await _repo.getIpaSounds(ownerId: currentUserId);
      _minimalPairs = await _repo.getMinimalPairs();
    } catch (e) {
      debugPrint('Lỗi tải dữ liệu phát âm: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Phát âm thanh ví dụ của một âm IPA
  Future<void> speakSound(IpaSound sound) async {
    _activePlayingSound = sound;
    notifyListeners();
    try {
      await _tts.stop();
      await _tts.speak(sound.exampleWord);
    } catch (_) {}

    // Tự động giải phóng trạng thái playing sau 1.2s
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (_activePlayingSound?.id == sound.id) {
        _activePlayingSound = null;
        notifyListeners();
      }
    });
  }

  /// Phát từ hoặc câu bất kỳ
  Future<void> speakWord(String text) async {
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {}
  }

  /// Dừng phát âm thanh
  Future<void> stop() async {
    try {
      await _tts.stop();
      _activePlayingSound = null;
      notifyListeners();
    } catch (_) {}
  }

  /// Cập nhật điểm thành thạo của âm sau bài tập
  Future<void> recordPracticeResult(String soundId, bool isCorrect) async {
    final currentUserId = AuthController.instance.isAuthenticated
        ? AuthController.instance.user.id
        : '';
    final delta = isCorrect ? 15 : -5;
    await _repo.updateSoundMastery(
      soundId: soundId,
      ownerId: currentUserId,
      delta: delta,
    );
    // Tải lại để cập nhật thanh % tiến độ
    await loadData();
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }
}
