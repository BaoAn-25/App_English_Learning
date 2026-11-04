import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../data/interest_repository.dart';
import '../../data/models/interest_topic.dart';
import '../../data/models/interest_word.dart';

class InterestController extends ChangeNotifier {
  final InterestRepository _repo;
  final FlutterTts _tts = FlutterTts();

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  List<InterestTopic> _allTopics = [];
  List<InterestTopic> get allTopics => _allTopics;

  String _selectedCategory = 'all';
  String get selectedCategory => _selectedCategory;

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  List<InterestTopic> get filteredTopics {
    return _allTopics.where((t) {
      final matchesCategory = _selectedCategory == 'all' || t.categoryId == _selectedCategory;
      final matchesQuery = _searchQuery.isEmpty ||
          t.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          t.titleVi.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          t.description.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesQuery;
    }).toList();
  }

  InterestController({InterestRepository? repo})
      : _repo = repo ?? InterestRepository() {
    _initTts();
    loadTopics();
  }

  void _initTts() {
    try {
      _tts.setLanguage('en-US');
      _tts.setSpeechRate(0.42);
    } catch (_) {}
  }

  Future<void> loadTopics() async {
    _isLoading = true;
    notifyListeners();

    try {
      _allTopics = await _repo.getInterestTopics();
    } catch (e) {
      debugPrint('Lỗi tải danh sách chủ đề: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setCategory(String categoryId) {
    _selectedCategory = categoryId;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query.trim();
    notifyListeners();
  }

  Future<List<InterestWord>> getWordsForTopic(String topicId) async {
    return await _repo.getWordsByTopic(topicId);
  }

  Future<List<InterestWord>> getAllWords() async {
    return await _repo.getAllWords();
  }

  Future<void> speak(String text) async {
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {}
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }
}
