import 'package:thpt_english/data/app_repository.dart';
import 'package:thpt_english/data/models/daily_stat.dart';

class FakeRepository extends AppRepository {
  final Map<String, String> settings = {};
  List<DailyStat> stats = [];
  bool failRead = false;
  bool failWrite = false;

  @override
  Future<String?> getSetting(String key) async {
    if (failRead) throw StateError('Read failed');
    return settings[key];
  }

  @override
  Future<void> setSetting(String key, String value) async {
    if (failWrite) throw StateError('Write failed');
    settings[key] = value;
  }

  @override
  Future<List<DailyStat>> getAllDailyStats() async {
    if (failRead) throw StateError('Read failed');
    return stats;
  }
}
