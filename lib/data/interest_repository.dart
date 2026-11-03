import 'app_database.dart';
import 'models/interest_topic.dart';
import 'models/interest_word.dart';

/// Repository quản lý kho chủ đề sở thích mở rộng (Bóng đá, Quán Cafe, Du lịch...)
class InterestRepository {
  final AppDatabase _db;

  InterestRepository({AppDatabase? db}) : _db = db ?? AppDatabase.instance;

  /// Lấy toàn bộ danh sách các chủ đề sở thích kèm số lượng từ vựng
  Future<List<InterestTopic>> getInterestTopics() => _db.getAllInterestTopics();

  /// Lấy danh sách từ vựng và câu đàm thoại thực tế theo chủ đề
  Future<List<InterestWord>> getWordsByTopic(String topicId) =>
      _db.getWordsByInterestTopicId(topicId);

  /// Lấy toàn bộ từ vựng sở thích cho việc tìm kiếm hoặc tạo Flashcard ngẫu nhiên
  Future<List<InterestWord>> getAllWords() => _db.getAllInterestWords();
}
