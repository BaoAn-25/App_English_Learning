import 'app_database.dart';
import 'models/ipa_sound.dart';
import 'models/minimal_pair_question.dart';

/// Repository quản lý dữ liệu phát âm chuẩn quốc tế IPA và các bài tập đối lập âm
class PronunciationRepository {
  final AppDatabase _db;

  PronunciationRepository({AppDatabase? db}) : _db = db ?? AppDatabase.instance;

  /// Lấy toàn bộ 44 âm quốc tế IPA kèm theo độ thông thạo của người dùng
  Future<List<IpaSound>> getIpaSounds({String? ownerId}) =>
      _db.getAllIpaSounds(ownerId: ownerId);

  /// Cập nhật điểm thành thạo của một âm IPA sau khi luyện tập
  Future<void> updateSoundMastery({
    required String soundId,
    required String ownerId,
    required int delta,
  }) =>
      _db.updateIpaMastery(soundId, ownerId, delta);

  /// Lấy danh sách các câu hỏi luyện tai nghe cặp âm đối lập (Minimal Pairs: dock vs deck)
  Future<List<MinimalPairQuestion>> getMinimalPairs() => _db.getAllMinimalPairs();
}

