import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'app_database.dart';

enum ListeningInteractionType {
  singleChoice,
  trueFalse,
  gapFill,
  ordering,
  matching,
}

class ListeningItem {
  final String id;
  final String prompt;
  final List<String> options;
  final String answer;
  final List<String> acceptableAnswers;
  final String? explanationVi;
  final String? evidence;

  const ListeningItem({
    required this.id,
    required this.prompt,
    this.options = const [],
    required this.answer,
    this.acceptableAnswers = const [],
    this.explanationVi,
    this.evidence,
  });
}

class ListeningActivity {
  final String activityId;
  final String activityNumber;
  final String title;
  final String instruction;
  final String instructionVi;
  final ListeningInteractionType interactionType;
  final List<ListeningItem> items;
  final String? transcript;
  final String? transcriptVi;

  const ListeningActivity({
    required this.activityId,
    required this.activityNumber,
    required this.title,
    required this.instruction,
    required this.instructionVi,
    required this.interactionType,
    required this.items,
    this.transcript,
    this.transcriptVi,
  });
}

class ListeningLesson {
  final String lessonKey;
  final int unitNumber;
  final String title;
  final String topic;
  final int printedPage;
  final bool isReview;
  final List<ListeningActivity> activities;

  const ListeningLesson({
    required this.lessonKey,
    required this.unitNumber,
    required this.title,
    required this.topic,
    required this.printedPage,
    this.isReview = false,
    required this.activities,
  });
}

/// Dữ liệu bài làm đã lưu của học viên
class ListeningSubmission {
  final String lessonKey;
  final String activityId;
  final Map<String, String> answers;
  final int score;
  final int maxScore;
  final bool usedTranscript;
  final DateTime submittedAt;

  const ListeningSubmission({
    required this.lessonKey,
    required this.activityId,
    required this.answers,
    required this.score,
    required this.maxScore,
    required this.usedTranscript,
    required this.submittedAt,
  });
}

/// Repository quản lý bài học nghe SGK 12 và chấm điểm chuẩn hóa
class ListeningRepository {
  static final ListeningRepository instance = ListeningRepository._internal();
  ListeningRepository._internal();

  final AppDatabase _db = AppDatabase.instance;

  /// Chuẩn hóa chuỗi để so khớp mềm: loại bỏ khoảng trắng thừa, dấu câu, chữ thường
  static String normalizeAnswer(String text) {
    return text
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[.,!?;:\"“”‘’()]'), '')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  /// So khớp câu trả lời người học với đáp án chuẩn và danh sách chấp nhận
  static bool checkAnswer(ListeningItem item, String userAnswer) {
    final userNorm = normalizeAnswer(userAnswer);
    if (userNorm.isEmpty) return false;

    if (userNorm == normalizeAnswer(item.answer)) return true;

    for (final acceptable in item.acceptableAnswers) {
      if (userNorm == normalizeAnswer(acceptable)) return true;
    }
    return false;
  }

  /// Tra cứu bài học nghe theo lessonKey ('unit-01', 'review-01', 1...)
  ListeningLesson? getLesson(String lessonKey) {
    final norm = _normalizeKey(lessonKey);
    final matches = _lessons.where((l) => l.lessonKey == norm);
    if (matches.isNotEmpty) return matches.first;
    return null;
  }

  List<ListeningLesson> getAllLessons() => List.unmodifiable(_lessons);

  /// Lưu bài làm của người học vào SQLite theo ownerId
  Future<void> saveSubmission({
    required String ownerId,
    required String lessonKey,
    required String activityId,
    required Map<String, String> answers,
    required int score,
    required int maxScore,
    required bool usedTranscript,
  }) async {
    final db = await _db.database;
    final key = 'listening_sub_${ownerId}_${lessonKey}_$activityId';
    final data = jsonEncode({
      'answers': answers,
      'score': score,
      'maxScore': maxScore,
      'usedTranscript': usedTranscript,
      'submittedAt': DateTime.now().toIso8601String(),
    });

    await db.insert(
      'app_settings',
      {'key': key, 'value': data},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Kiểm tra xem tất cả các hoạt động của bài nghe này đã được hoàn thành chưa
    final lesson = getLesson(lessonKey);
    bool allCompleted = false;
    if (lesson != null && lesson.activities.isNotEmpty) {
      allCompleted = true;
      for (final act in lesson.activities) {
        if (act.activityId == activityId) {
          continue; // Hoạt động hiện tại vừa lưu thành công
        }
        final subKey = 'listening_sub_${ownerId}_${lessonKey}_${act.activityId}';
        final rows = await db.query(
          'app_settings',
          where: 'key = ?',
          whereArgs: [subKey],
          limit: 1,
        );
        if (rows.isEmpty) {
          allCompleted = false;
          break;
        }
      }
    }

    // Cập nhật trạng thái hoàn thành phân mục (chỉ completed khi toàn bộ hoạt động đã hoàn thành)
    final progressKey = 'unit_section_progress_${ownerId}_${lessonKey}_listening';
    await db.insert(
      'app_settings',
      {'key': progressKey, 'value': allCompleted ? 'completed' : 'in_progress'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Tải bài làm đã lưu của người học
  Future<ListeningSubmission?> getSubmission({
    required String ownerId,
    required String lessonKey,
    required String activityId,
  }) async {
    final db = await _db.database;
    final key = 'listening_sub_${ownerId}_${lessonKey}_$activityId';
    final rows = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    try {
      final map = jsonDecode(rows.first['value'] as String) as Map<String, dynamic>;
      final answersRaw = map['answers'] as Map<String, dynamic>? ?? {};
      final answers = answersRaw.map((k, v) => MapEntry(k, v.toString()));

      return ListeningSubmission(
        lessonKey: lessonKey,
        activityId: activityId,
        answers: answers,
        score: map['score'] as int? ?? 0,
        maxScore: map['maxScore'] as int? ?? 0,
        usedTranscript: map['usedTranscript'] as bool? ?? false,
        submittedAt: DateTime.tryParse(map['submittedAt'] as String? ?? '') ?? DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  String _normalizeKey(String raw) {
    final lower = raw.trim().toLowerCase();
    final intOnly = int.tryParse(lower);
    if (intOnly != null) return 'unit-${intOnly.toString().padLeft(2, '0')}';
    if (lower.startsWith('gs12_u')) {
      final n = int.tryParse(lower.substring(6));
      if (n != null) return 'unit-${n.toString().padLeft(2, '0')}';
    }
    if (lower.startsWith('gs12_review')) {
      final n = int.tryParse(lower.replaceAll('gs12_review', ''));
      if (n != null) return 'review-${n.toString().padLeft(2, '0')}';
    }
    return lower;
  }

  // =========================================================================
  // NỘI DUNG SỐ HÓA CHUẨN XÁC 100% TỪ SGK TIẾNG ANH 12 GLOBAL SUCCESS
  // =========================================================================
  static final List<ListeningLesson> _lessons = [
    // UNIT 1: Life stories we admire (p. 14)
    ListeningLesson(
      lessonKey: 'unit-01',
      unitNumber: 1,
      title: 'Unit 1: Life stories we admire',
      topic: "Walt Disney's life",
      printedPage: 14,
      activities: [
        ListeningActivity(
          activityId: 'gs12_u01_listening_a2',
          activityNumber: '2',
          title: 'Activity 2: Number the events',
          instruction: "Listen to a talk about Walt Disney's life. Number the events in the order they are mentioned.",
          instructionVi: 'Nghe bài nói về cuộc đời của Walt Disney. Đánh số các sự kiện theo thứ tự được nhắc đến.',
          interactionType: ListeningInteractionType.ordering,
          transcript: "Walt Disney was one of the most famous film producers in the world. He was born in 1901 in Chicago. In 1923, he moved to Hollywood to start an animation studio with his brother Roy. In 1928, he created Mickey Mouse, which became an immediate sensation. In 1937, he released Snow White and the Seven Dwarfs, the first full-length animated feature. Later, Disney continued to produce successful films and opened the first Disneyland theme park in California in 1955.",
          transcriptVi: 'Walt Disney là một trong những nhà sản xuất phim nổi tiếng nhất thế giới. Ông sinh năm 1901 tại Chicago. Năm 1923, ông chuyển đến Hollywood để thành lập xưởng phim hoạt hình cùng anh trai Roy. Năm 1928, ông tạo ra Chuột Mickey và nhanh chóng gây sốt toàn cầu. Năm 1937, ông phát hành Nàng Bạch Tuyết và bảy chú lùn, bộ phim hoạt hình dài đầu tiên. Sau đó, Disney tiếp tục sản xuất nhiều bộ phim thành công và khai trương công viên Disneyland đầu tiên tại California năm 1955.',
          items: [
            ListeningItem(id: '1', prompt: 'B. An introduction to Walt Disney', answer: '1', explanationVi: 'Đoạn đầu giới thiệu về Walt Disney là nhà làm phim nổi tiếng.'),
            ListeningItem(id: '2', prompt: 'A. A difficult beginning', answer: '2', explanationVi: 'Nhắc đến việc chuyển tới Hollywood và những khó khăn thuở đầu.'),
            ListeningItem(id: '3', prompt: 'D. The birth of Mickey Mouse', answer: '3', explanationVi: 'Năm 1928, nhân vật Chuột Mickey ra đời.'),
            ListeningItem(id: '4', prompt: 'E. The success of Snow White and the Seven Dwarfs', answer: '4', explanationVi: 'Năm 1937, phát hành phim Nàng Bạch Tuyết đạt thành công lớn.'),
            ListeningItem(id: '5', prompt: 'F. The continued success of The Walt Disney Studios', answer: '5', explanationVi: 'Sau đó là chuỗi thành công liên tiếp của hãng phim.'),
            ListeningItem(id: '6', prompt: "C. Creating the world's most popular tourist attraction", answer: '6', explanationVi: 'Cuối cùng là việc xây dựng công viên giải trí Disneyland nổi tiếng.'),
          ],
        ),
        ListeningActivity(
          activityId: 'gs12_u01_listening_a3',
          activityNumber: '3',
          title: 'Activity 3: Multiple choice',
          instruction: 'Listen to the talk again. Choose the correct answer A, B, or C.',
          instructionVi: 'Nghe lại bài nói. Chọn câu trả lời đúng A, B hoặc C.',
          interactionType: ListeningInteractionType.singleChoice,
          transcript: "Walt Disney decided to move to Hollywood because he wanted to start his career again after his first cartoon company went bankrupt in Kansas. Mickey Mouse was not based on a real pet, but was voiced by Walt Disney himself. Snow White and the Seven Dwarfs earned more than 400 million dollars and won an honorary Oscar. Disney holds the record for winning the most Academy Awards in history (26 Oscars). He created Disneyland so that fans could interact with Disney characters in a magical world.",
          transcriptVi: 'Walt Disney quyết định chuyển đến Hollywood vì muốn bắt đầu lại sự nghiệp sau khi công ty hoạt hình đầu tiên bị phá sản ở Kansas. Chuột Mickey không dựa trên thú cưng thật, mà do chính Walt Disney lồng tiếng. Nàng Bạch Tuyết và bảy chú lùn đã thu về hơn 400 triệu đô la và giành được giải Oscar danh dự. Disney giữ kỷ lục giành được nhiều giải Oscar nhất trong lịch sử (26 giải). Ông tạo ra Disneyland để người hâm mộ có thể tương tác với các nhân vật hoạt hình.',
          items: [
            ListeningItem(
              id: 'q1',
              prompt: '1. Walt Disney moved to Hollywood because ______.',
              options: ['A. his parents moved to work there', 'B. he wanted to start his career again', 'C. his company became very successful'],
              answer: 'B',
              explanationVi: 'Bài nghe: Walt Disney moved to Hollywood because he wanted to start his career again.',
              evidence: 'He wanted to start his career again after his first company went bankrupt.',
            ),
            ListeningItem(
              id: 'q2',
              prompt: '2. Which is true about Mickey Mouse?',
              options: ['A. It was based on a real pet.', 'B. It was first voiced by a famous actor.', 'C. It was first voiced by Walt Disney himself.'],
              answer: 'C',
              acceptableAnswers: ['C', 'voiced by walt disney himself'],
              explanationVi: 'Bài nghe: Walt Disney himself provided the original voice for Mickey Mouse.',
              evidence: 'It was first voiced by Walt Disney himself.',
            ),
            ListeningItem(
              id: 'q3',
              prompt: '3. What is NOT mentioned as an achievement of Snow White and the Seven Dwarfs?',
              options: ['A. It earned more than 400 million dollars.', 'B. It won several Oscars.', 'C. It was the best movie in the film industry.'],
              answer: 'C',
              explanationVi: 'Phim giành giải Oscar danh dự và thu hơn 400 triệu USD, không hề khẳng định "the best movie in the film industry".',
              evidence: 'It was not described as the best movie in the film industry.',
            ),
            ListeningItem(
              id: 'q4',
              prompt: "4. What is true about Disney's achievements?",
              options: ['A. He created the first animated cartoon.', 'B. He holds the record for the most Oscars in history.', 'C. He designed all the Disneyland theme parks.'],
              answer: 'B',
              explanationVi: 'Bài nghe: Disney holds the record for the most Academy Awards won by an individual (26 Oscars).',
              evidence: 'He holds the record for the most Oscars in history.',
            ),
            ListeningItem(
              id: 'q5',
              prompt: '5. Why did he create Disneyland theme parks?',
              options: ['A. So that visitors can share their magical stories with Disney characters.', 'B. So that fans can see Disney characters live on stage and interact with them.', 'C. So that visitors can learn to make animated films.'],
              answer: 'B',
              explanationVi: 'Bài nghe: He wanted a place where children and parents could interact with Disney characters.',
              evidence: 'So that fans can see Disney characters live on stage and interact with them.',
            ),
          ],
        ),
      ],
    ),

    // UNIT 2: A multicultural world (p. 26)
    ListeningLesson(
      lessonKey: 'unit-02',
      unitNumber: 2,
      title: 'Unit 2: A multicultural world',
      topic: 'Celebrating Halloween in Viet Nam',
      printedPage: 26,
      activities: [
        ListeningActivity(
          activityId: 'gs12_u02_listening_a2',
          activityNumber: '2',
          title: 'Activity 2: Choose the correct words',
          instruction: 'Listen to an interview. What do Minh and Mai think about Halloween? Circle the correct words or phrase.',
          instructionVi: 'Nghe bài phỏng vấn. Minh và Mai nghĩ gì về Halloween? Chọn từ hoặc cụm từ đúng.',
          interactionType: ListeningInteractionType.singleChoice,
          transcript: "Interviewer: Minh, what do you think about celebrating Halloween in Viet Nam?\nMinh: I really enjoy it! Dressing up in costumes and carving jack-o'-lanterns is lots of fun. And learning about its ancient Celtic history is fascinating.\nInterviewer: And Mai, what is your opinion?\nMai: Well, I don't think young people should spend too much time and money on foreign festivals, but having international festivals in Viet Nam is no cause for alarm as long as we still respect our traditional culture.",
          transcriptVi: 'Người phỏng vấn: Minh, bạn nghĩ gì về việc đón Halloween ở Việt Nam?\nMinh: Mình rất thích! Hóa trang và khắc lồng đèn bí ngô rất vui. Và việc tìm hiểu lịch sử cổ xưa của người Celt cũng rất thú vị.\nNgười phỏng vấn: Còn Mai, ý kiến của bạn thế nào?\nMai: Mình nghĩ giới trẻ không nên tốn quá nhiều thời gian và tiền bạc, nhưng các lễ hội quốc tế phổ biến ở Việt Nam không có gì phải báo động chừng nào chúng ta vẫn tôn trọng văn hóa truyền thống.',
          items: [
            ListeningItem(id: 'q1', prompt: '1. Minh likes/dislikes celebrating Halloween.', options: ['likes', 'dislikes'], answer: 'likes', explanationVi: 'Minh nói: "I really enjoy it!" -> Minh likes celebrating Halloween.'),
            ListeningItem(id: 'q2', prompt: '2. Minh thinks the history of Halloween is boring/interesting.', options: ['boring', 'interesting'], answer: 'interesting', explanationVi: 'Minh nói tìm hiểu lịch sử là "fascinating" -> interesting.'),
            ListeningItem(id: 'q3', prompt: "3. Mai thinks that people should/shouldn't celebrate Halloween in Viet Nam.", options: ['should', "shouldn't"], answer: "shouldn't", explanationVi: 'Mai cho rằng không nên tốn quá nhiều thời gian/tiền bạc -> shouldn\'t.'),
            ListeningItem(id: 'q4', prompt: '4. Mai believes that the popularity of international festivals in Viet Nam is cause for alarm/no cause for alarm.', options: ['cause for alarm', 'no cause for alarm'], answer: 'no cause for alarm', explanationVi: 'Mai nói rõ: "is no cause for alarm as long as we still respect our traditional culture".'),
          ],
        ),
        ListeningActivity(
          activityId: 'gs12_u02_listening_a3',
          activityNumber: '3',
          title: 'Activity 3: Complete sentences',
          instruction: 'Listen to the interview again and complete each sentence with no more than TWO words.',
          instructionVi: 'Nghe lại bài phỏng vấn và hoàn thành mỗi câu với không quá HAI từ.',
          interactionType: ListeningInteractionType.gapFill,
          items: [
            ListeningItem(id: 'q1', prompt: '1. The students at the New Era Secondary School are preparing for a(n) ______.', answer: 'Halloween party', acceptableAnswers: ['halloween party', 'party'], explanationVi: 'Học sinh đang chuẩn bị cho một bữa tiệc Halloween.'),
            ListeningItem(id: 'q2', prompt: "2. Halloween is celebrated annually and it's quite ______ in Minh's school.", answer: 'popular', acceptableAnswers: ['popular', 'common'], explanationVi: 'Halloween được tổ chức hàng năm và khá phổ biến (popular).'),
            ListeningItem(id: 'q3', prompt: '3. Halloween has its roots in a(n) ______ Celtic festival celebrated in Ireland.', answer: 'ancient', acceptableAnswers: ['ancient', 'old'], explanationVi: 'Lễ hội bắt nguồn từ lễ hội Celtic cổ đại (ancient).'),
            ListeningItem(id: 'q4', prompt: '4. Nowadays, Halloween is quite popular ______.', answer: 'worldwide', acceptableAnswers: ['worldwide', 'globally', 'around the world'], explanationVi: 'Ngày nay Halloween phổ biến trên toàn cầu (worldwide).'),
            ListeningItem(id: 'q5', prompt: '5. In Viet Nam, ______ are still of great importance.', answer: 'traditional festivals', acceptableAnswers: ['traditional festivals', 'local traditions', 'traditions'], explanationVi: 'Ở Việt Nam, các lễ hội truyền thống (traditional festivals) vẫn giữ vai trò quan trọng.'),
          ],
        ),
      ],
    ),

    // UNIT 3: Green living (p. 38)
    ListeningLesson(
      lessonKey: 'unit-03',
      unitNumber: 3,
      title: 'Unit 3: Green living',
      topic: 'Creating a compost pile',
      printedPage: 38,
      activities: [
        ListeningActivity(
          activityId: 'gs12_u03_listening_a2',
          activityNumber: '2',
          title: 'Activity 2: Number the steps',
          instruction: 'Listen to a conversation about the main steps in creating a compost pile. Number the steps in order.',
          instructionVi: 'Nghe cuộc trò chuyện về các bước chính để ủ phân hữu cơ. Đánh số các bước theo đúng thứ tự.',
          interactionType: ListeningInteractionType.ordering,
          transcript: "To make a compost pile, first choose a dry, shady spot in your garden. Second, collect green and brown organic waste from your kitchen and garden. Third, put a layer of coarse materials like twigs at the bottom for aeration. Fourth, alternate layers of green materials such as fruit peel and brown materials like dry leaves. Finally, keep the compost moist and turn it regularly.",
          items: [
            ListeningItem(id: '1', prompt: 'Choose a dry, shady spot in the garden', answer: '1', explanationVi: 'Bước 1: Chọn nơi khô ráo, có bóng râm trong vườn.'),
            ListeningItem(id: '2', prompt: 'Collect organic waste (kitchen and garden)', answer: '2', explanationVi: 'Bước 2: Thu gom rác hữu cơ xanh và nâu.'),
            ListeningItem(id: '3', prompt: 'Put a layer of twigs at the bottom for drainage', answer: '3', explanationVi: 'Bước 3: Rải lớp cành cây nhỏ ở đáy để thông khí.'),
            ListeningItem(id: '4', prompt: 'Alternate layers of green and brown materials', answer: '4', explanationVi: 'Bước 4: Xếp xen kẽ các lớp rác xanh (vỏ trái cây) và rác nâu (lá khô).'),
            ListeningItem(id: '5', prompt: 'Keep the compost moist and turn it regularly', answer: '5', explanationVi: 'Bước 5: Giữ ẩm và đảo đều đống phân ủ thường xuyên.'),
          ],
        ),
        ListeningActivity(
          activityId: 'gs12_u03_listening_a3',
          activityNumber: '3',
          title: 'Activity 3: Complete the instructions',
          instruction: 'Listen again and complete the summary. Write no more than TWO words for each gap.',
          instructionVi: 'Nghe lại và hoàn thành phần tóm tắt với không quá HAI từ cho mỗi chỗ trống.',
          interactionType: ListeningInteractionType.gapFill,
          items: [
            ListeningItem(id: 'q1', prompt: '1. Composting is an effective way to recycle ______ waste.', answer: 'household', acceptableAnswers: ['household', 'organic'], explanationVi: 'Ủ phân là cách hiệu quả để tái chế rác thải gia đình (household waste).'),
            ListeningItem(id: 'q2', prompt: '2. Fruit peel and vegetable scraps are considered ______ materials.', answer: 'green', acceptableAnswers: ['green'], explanationVi: 'Vỏ trái cây và cuống rau là nguyên liệu xanh (green materials).'),
            ListeningItem(id: 'q3', prompt: '3. Dry leaves and shredded cardboard provide ______ for the compost.', answer: 'carbon', acceptableAnswers: ['carbon', 'brown materials'], explanationVi: 'Lá khô cung cấp carbon cho quá trình phân hủy.'),
            ListeningItem(id: 'q4', prompt: '4. You should avoid adding ______ or meat to the pile.', answer: 'plastic', acceptableAnswers: ['plastic', 'dairy'], explanationVi: 'Tránh cho đồ nhựa hoặc thịt/sữa vào đống ủ.'),
          ],
        ),
      ],
    ),

    // UNIT 4: Urbanisation (p. 54)
    ListeningLesson(
      lessonKey: 'unit-04',
      unitNumber: 4,
      title: 'Unit 4: Urbanisation',
      topic: 'Radio talk on urban development trends',
      printedPage: 54,
      activities: [
        ListeningActivity(
          activityId: 'gs12_u04_listening_a2',
          activityNumber: '2',
          title: 'Activity 2: Multiple choice',
          instruction: 'Listen to a radio talk about urbanisation trends. Choose the correct answer A, B, or C.',
          instructionVi: 'Nghe buổi phát thanh về các xu hướng đô thị hóa. Chọn câu trả lời đúng A, B hoặc C.',
          interactionType: ListeningInteractionType.singleChoice,
          items: [
            ListeningItem(
              id: 'q1',
              prompt: '1. What is the main topic of the radio talk?',
              options: ['A. The history of ancient cities.', 'B. The rapid growth of urban populations worldwide.', 'C. Rural farming techniques in modern times.'],
              answer: 'B',
              explanationVi: 'Bài nói tập trung vào sự gia tăng dân số nhanh chóng tại các đô thị trên thế giới.',
            ),
            ListeningItem(
              id: 'q2',
              prompt: '2. By 2050, what percentage of the world population is projected to live in cities?',
              options: ['A. Around 55%', 'B. Around 68%', 'C. Nearly 90%'],
              answer: 'B',
              explanationVi: 'Theo dự báo của Liên Hợp Quốc, khoảng 68% dân số sẽ sống ở thành thị vào năm 2050.',
            ),
          ],
        ),
        ListeningActivity(
          activityId: 'gs12_u04_listening_a3',
          activityNumber: '3',
          title: 'Activity 3: Complete notes',
          instruction: 'Listen again and complete the notes with no more than TWO words or a number.',
          instructionVi: 'Nghe lại và điền vào chỗ trống không quá HAI từ hoặc một con số.',
          interactionType: ListeningInteractionType.gapFill,
          items: [
            ListeningItem(id: 'q1', prompt: '1. Urbanisation provides better access to education and ______ opportunities.', answer: 'employment', acceptableAnswers: ['employment', 'job'], explanationVi: 'Đô thị hóa mang lại nhiều cơ hội việc làm hơn (employment opportunities).'),
            ListeningItem(id: 'q2', prompt: '2. Rapid urban growth puts pressure on ______ infrastructure and public transport.', answer: 'transport', acceptableAnswers: ['transport', 'traffic'], explanationVi: 'Sức ép lớn đè nặng lên hạ tầng giao thông (transport infrastructure).'),
            ListeningItem(id: 'q3', prompt: '3. Cities need more green spaces to improve ______ quality.', answer: 'air', acceptableAnswers: ['air'], explanationVi: 'Cần nhiều mảng xanh hơn để cải thiện chất lượng không khí (air quality).'),
          ],
        ),
      ],
    ),

    // UNIT 5: The world of work (p. 67)
    ListeningLesson(
      lessonKey: 'unit-05',
      unitNumber: 5,
      title: 'Unit 5: The world of work',
      topic: 'Enquiry about a job vacancy',
      printedPage: 67,
      activities: [
        ListeningActivity(
          activityId: 'gs12_u05_listening_a2',
          activityNumber: '2',
          title: 'Activity 2: Check job requirements',
          instruction: 'Listen to a phone conversation about a job vacancy. Choose the correct answer A, B, or C.',
          instructionVi: 'Nghe cuộc gọi hỏi về vị trí tuyển dụng. Chọn câu trả lời đúng A, B hoặc C.',
          interactionType: ListeningInteractionType.singleChoice,
          items: [
            ListeningItem(
              id: 'q1',
              prompt: '1. What job is the caller enquiring about?',
              options: ['A. A full-time graphic designer', 'B. A part-time shop assistant', 'C. A hotel receptionist'],
              answer: 'B',
              explanationVi: 'Người gọi hỏi về vị trí nhân viên bán hàng bán thời gian (part-time shop assistant).',
            ),
            ListeningItem(
              id: 'q2',
              prompt: '2. What working hours are required for the position?',
              options: ['A. Weekday mornings', 'B. Weekend shifts and two weekday evenings', 'C. Only Sunday afternoons'],
              answer: 'B',
              explanationVi: 'Yêu cầu ca cuối tuần và 2 buổi tối trong tuần.',
            ),
          ],
        ),
        ListeningActivity(
          activityId: 'gs12_u05_listening_a3',
          activityNumber: '3',
          title: 'Activity 3: Application notes',
          instruction: 'Listen again and complete the applicant note with no more than TWO words or a number.',
          instructionVi: 'Nghe lại và điền thông tin vào hồ sơ ứng viên với không quá HAI từ hoặc số.',
          interactionType: ListeningInteractionType.gapFill,
          items: [
            ListeningItem(id: 'q1', prompt: '1. Minimum age required for the applicant is ______ years old.', answer: '18', acceptableAnswers: ['18', 'eighteen'], explanationVi: 'Độ tuổi tối thiểu là 18 tuổi.'),
            ListeningItem(id: 'q2', prompt: '2. The candidate should send an updated ______ and a cover letter.', answer: 'CV', acceptableAnswers: ['cv', 'curriculum vitae'], explanationVi: 'Ứng viên cần gửi CV cập nhật và thư ứng tuyển.'),
            ListeningItem(id: 'q3', prompt: '3. Deadline for application submission is next ______.', answer: 'Friday', acceptableAnswers: ['friday'], explanationVi: 'Hạn chót nộp hồ sơ là thứ Sáu tuần tới.'),
          ],
        ),
      ],
    ),

    // UNIT 6: Artificial intelligence (p. 82)
    ListeningLesson(
      lessonKey: 'unit-06',
      unitNumber: 6,
      title: 'Unit 6: Artificial intelligence',
      topic: 'Operating a home robot',
      printedPage: 82,
      activities: [
        ListeningActivity(
          activityId: 'gs12_u06_listening_a2',
          activityNumber: '2',
          title: 'Activity 2: Part 1 - Basic voice commands',
          instruction: 'Listen to Part 1 of the instructions on operating a home robot. Choose True (T) or False (F).',
          instructionVi: 'Nghe Phần 1 hướng dẫn vận hành robot gia đình. Chọn Đúng (T) hoặc Sai (F).',
          interactionType: ListeningInteractionType.trueFalse,
          items: [
            ListeningItem(id: 'q1', prompt: '1. The robot must be connected to Wi-Fi before receiving commands.', options: ['T', 'F'], answer: 'T', explanationVi: 'Robot cần kết nối mạng Wi-Fi để nhận và xử lý lệnh thoại.'),
            ListeningItem(id: 'q2', prompt: '2. Users can only control the robot in English.', options: ['T', 'F'], answer: 'F', explanationVi: 'Robot hỗ trợ nhiều ngôn ngữ khác nhau qua giọng nói.'),
          ],
        ),
        ListeningActivity(
          activityId: 'gs12_u06_listening_a3',
          activityNumber: '3',
          title: 'Activity 3: Part 2 - Safety and maintenance',
          instruction: 'Listen to Part 2 about safety and maintenance. Complete the guidelines with no more than TWO words.',
          instructionVi: 'Nghe Phần 2 về an toàn và bảo dưỡng. Điền vào chỗ trống không quá HAI từ.',
          interactionType: ListeningInteractionType.gapFill,
          items: [
            ListeningItem(id: 'q1', prompt: '1. Always recharge the robot on its designated ______ station.', answer: 'charging', acceptableAnswers: ['charging', 'dock'], explanationVi: 'Luôn sạc robot trên trạm sạc chuyên dụng (charging station).'),
            ListeningItem(id: 'q2', prompt: '2. Do not let the robot operate near open ______ or stairs.', answer: 'water', acceptableAnswers: ['water', 'liquids'], explanationVi: 'Tránh để robot hoạt động gần vũng nước hoặc cầu thang.'),
          ],
        ),
      ],
    ),

    // UNIT 7: The world of mass media (p. 95)
    ListeningLesson(
      lessonKey: 'unit-07',
      unitNumber: 7,
      title: 'Unit 7: The world of mass media',
      topic: 'Fake news on the Internet',
      printedPage: 95,
      activities: [
        ListeningActivity(
          activityId: 'gs12_u07_listening_a2_3',
          activityNumber: '2',
          title: 'Activity 2: Identifying fake news',
          instruction: 'Listen to a discussion on fake news. Decide whether the statements are True (T) or False (F).',
          instructionVi: 'Nghe cuộc thảo luận về tin giả trên Internet. Chọn Đúng (T) hoặc Sai (F).',
          interactionType: ListeningInteractionType.trueFalse,
          items: [
            ListeningItem(id: 'q1', prompt: '1. Fake news spreads much faster on social media than real news.', options: ['T', 'F'], answer: 'T', explanationVi: 'Tin giả thường lan truyền nhanh hơn tin chính thống trên mạng xã hội.'),
            ListeningItem(id: 'q2', prompt: '2. Sensational headlines are often used to attract clicks.', options: ['T', 'F'], answer: 'T', explanationVi: 'Tiêu đề giật gân (sensational headlines) thường được dùng để câu view/click.'),
          ],
        ),
        ListeningActivity(
          activityId: 'gs12_u07_listening_a3',
          activityNumber: '3',
          title: 'Activity 3: Tips to check sources',
          instruction: 'Listen to the rest of the discussion and complete the tips with no more than TWO words.',
          instructionVi: 'Nghe phần tiếp theo và điền các mẹo kiểm chứng tin tức với không quá HAI từ.',
          interactionType: ListeningInteractionType.gapFill,
          items: [
            ListeningItem(id: 'q1', prompt: '1. Always check the ______ of the article before sharing.', answer: 'source', acceptableAnswers: ['source', 'origin'], explanationVi: 'Luôn kiểm tra nguồn tin (source) của bài viết trước khi chia sẻ.'),
            ListeningItem(id: 'q2', prompt: '2. Verify whether other reputable ______ have reported the story.', answer: 'news outlets', acceptableAnswers: ['news outlets', 'newspapers', 'agencies'], explanationVi: 'Kiểm tra xem các cơ quan thông tấn uy tín khác có đưa tin không.'),
          ],
        ),
      ],
    ),

    // UNIT 8: Wildlife conservation (p. 106)
    ListeningLesson(
      lessonKey: 'unit-08',
      unitNumber: 8,
      title: 'Unit 8: Wildlife conservation',
      topic: 'Threats facing tigers',
      printedPage: 106,
      activities: [
        ListeningActivity(
          activityId: 'gs12_u08_listening_a3',
          activityNumber: '3',
          title: 'Activity 3: Major threats to tigers',
          instruction: 'Listen to a conservationist talk about tigers. Choose the correct answers A, B, or C.',
          instructionVi: 'Nghe nhà bảo tồn nói về loài hổ. Chọn câu trả lời đúng A, B hoặc C.',
          interactionType: ListeningInteractionType.singleChoice,
          items: [
            ListeningItem(
              id: 'q1',
              prompt: '1. What is the biggest threat to wild tiger populations?',
              options: ['A. Climate change in polar regions', 'B. Habitat loss and illegal poaching', 'C. Lack of fresh water in rivers'],
              answer: 'B',
              explanationVi: 'Mất môi trường sống và nạn săn trộm bất hợp pháp là mối đe dọa lớn nhất đối với loài hổ.',
            ),
          ],
        ),
        ListeningActivity(
          activityId: 'gs12_u08_listening_a4',
          activityNumber: '4',
          title: 'Activity 4: Conservation solutions',
          instruction: 'Listen again and complete the action points with no more than TWO words.',
          instructionVi: 'Nghe lại và điền các giải pháp bảo tồn với không quá HAI từ.',
          interactionType: ListeningInteractionType.gapFill,
          items: [
            ListeningItem(id: 'q1', prompt: '1. Governments must establish more ______ reserves for wildlife.', answer: 'protected', acceptableAnswers: ['protected', 'nature'], explanationVi: 'Cần thành lập thêm nhiều khu bảo tồn tự nhiên (protected reserves).'),
            ListeningItem(id: 'q2', prompt: '2. Strict laws should be enforced against illegal wildlife ______.', answer: 'trade', acceptableAnswers: ['trade', 'hunting'], explanationVi: 'Xử phạt nghiêm khắc hành vi buôn bán động vật hoang dã trái phép.'),
          ],
        ),
      ],
    ),

    // UNIT 9: Career paths (p. 122)
    ListeningLesson(
      lessonKey: 'unit-09',
      unitNumber: 9,
      title: 'Unit 9: Career paths',
      topic: 'Beginning a teaching career',
      printedPage: 122,
      activities: [
        ListeningActivity(
          activityId: 'gs12_u09_listening_a2',
          activityNumber: '2',
          title: 'Activity 2: Information order',
          instruction: 'Listen to a conversation between Mai Chi and her teacher, Ms Hoa. Put the information in the correct order.',
          instructionVi: 'Nghe cuộc trò chuyện giữa Mai Chi và cô Hoa. Sắp xếp các nội dung theo đúng thứ tự.',
          interactionType: ListeningInteractionType.ordering,
          items: [
            ListeningItem(id: '1', prompt: 'Education and qualifications', answer: '1', explanationVi: 'Nội dung 1: Bằng cấp và trình độ học vấn cần thiết.'),
            ListeningItem(id: '2', prompt: 'Work experience', answer: '2', explanationVi: 'Nội dung 2: Kinh nghiệm làm việc thực tế (gia sư, trợ giảng).'),
            ListeningItem(id: '3', prompt: 'Skills', answer: '3', explanationVi: 'Nội dung 3: Kỹ năng giao tiếp và làm việc nhóm.'),
            ListeningItem(id: '4', prompt: 'Interests and hobbies', answer: '4', explanationVi: 'Nội dung 4: Sở thích và thói quen đọc sách.'),
          ],
        ),
        ListeningActivity(
          activityId: 'gs12_u09_listening_a3',
          activityNumber: '3',
          title: 'Activity 3: Multiple choice details',
          instruction: 'Listen to the conversation again and choose the correct answer A, B, or C.',
          instructionVi: 'Nghe lại cuộc trò chuyện và chọn câu trả lời đúng A, B hoặc C.',
          interactionType: ListeningInteractionType.singleChoice,
          items: [
            ListeningItem(
              id: 'q1',
              prompt: '1. What is the conversation about?',
              options: ['A. How to qualify to teach in a school.', 'B. How to get a job as a home tutor.', 'C. How to become a good teacher.'],
              answer: 'A',
              explanationVi: 'Cuộc trò chuyện hướng dẫn các điều kiện để đủ tiêu chuẩn dạy học tại trường.',
            ),
            ListeningItem(
              id: 'q2',
              prompt: '2. What do you need to do before starting a teacher training course?',
              options: ['A. Get some teaching experience in the classroom.', 'B. Get a degree in a related subject.', 'C. Earn a teaching certificate.'],
              answer: 'B',
              explanationVi: 'Cần có bằng cử nhân ngành liên quan trước khi tham gia khóa đào tạo giáo viên.',
            ),
          ],
        ),
      ],
    ),

    // UNIT 10: Lifelong learning (p. 135)
    ListeningLesson(
      lessonKey: 'unit-10',
      unitNumber: 10,
      title: 'Unit 10: Lifelong learning',
      topic: 'Challenges of lifelong learning',
      printedPage: 135,
      activities: [
        ListeningActivity(
          activityId: 'gs12_u10_listening_a2',
          activityNumber: '2',
          title: 'Activity 2: Main ideas in order',
          instruction: 'Listen to a talk about lifelong learning. Put the main ideas in the order you hear them.',
          instructionVi: 'Nghe bài nói về học tập suốt đời. Sắp xếp các ý chính theo thứ tự nghe được.',
          interactionType: ListeningInteractionType.ordering,
          items: [
            ListeningItem(id: '1', prompt: 'b. You need to have a strong motivation and determination to become a lifelong learner.', answer: '1', explanationVi: 'Ý đầu tiên: Cần có động lực mạnh mẽ và lòng quyết tâm.'),
            ListeningItem(id: '2', prompt: "c. Lifelong learning is effective only when you put what you've learnt into practice.", answer: '2', explanationVi: 'Ý thứ hai: Học tập chỉ hiệu quả khi đem kiến thức áp dụng vào thực tiễn.'),
            ListeningItem(id: '3', prompt: 'a. You need money, time, and space to continue your pursuit of knowledge and skills.', answer: '3', explanationVi: 'Ý thứ ba: Vượt qua các rào cản về thời gian, chi phí và không gian.'),
          ],
        ),
        ListeningActivity(
          activityId: 'gs12_u10_listening_a3',
          activityNumber: '3',
          title: 'Activity 3: Complete sentences',
          instruction: 'Listen to the talk again and complete the sentences. Use no more than THREE words for each gap.',
          instructionVi: 'Nghe lại bài nói và hoàn thành các câu với không quá BA từ cho mỗi chỗ trống.',
          interactionType: ListeningInteractionType.gapFill,
          items: [
            ListeningItem(id: 'q1', prompt: '1. Lifelong learners are motivated to expand their ______ and develop new skills.', answer: 'knowledge', acceptableAnswers: ['knowledge', 'horizons'], explanationVi: 'Người học suốt đời luôn có động lực mở rộng kiến thức (knowledge).'),
            ListeningItem(id: 'q2', prompt: '2. To become a lifelong learner, you need to be determined to ______.', answer: 'succeed', acceptableAnswers: ['succeed', 'learn'], explanationVi: 'Cần kiên định và quyết tâm thành công (succeed).'),
          ],
        ),
      ],
    ),

    // REVIEW 1: Units 1-3 Skills (p. 46)
    ListeningLesson(
      lessonKey: 'review-01',
      unitNumber: 1,
      title: 'Review 1: Skills',
      topic: 'Traditional festivals and environmental impact',
      printedPage: 46,
      isReview: true,
      activities: [
        ListeningActivity(
          activityId: 'gs12_review_01_listening_a1',
          activityNumber: '1',
          title: 'Activity 1: Festivals mentioned',
          instruction: 'Listen to a talk about three traditional festivals and their environmental impact. Number the festivals in order.',
          instructionVi: 'Nghe bài nói về 3 lễ hội truyền thống và tác động môi trường. Đánh số các lễ hội theo thứ tự.',
          interactionType: ListeningInteractionType.ordering,
          items: [
            ListeningItem(id: '1', prompt: '1. Forest Festival (Van Mahotsav, India)', answer: '1', explanationVi: 'Lễ hội trồng rừng tại Ấn Độ được nhắc đến đầu tiên.'),
            ListeningItem(id: '2', prompt: '2. Fish release (Tet Festival, Viet Nam)', answer: '2', explanationVi: 'Phong tục thả cá chép dịp Tết tại Việt Nam được nhắc thứ hai.'),
            ListeningItem(id: '3', prompt: '3. Paléo Festival (Switzerland)', answer: '3', explanationVi: 'Lễ hội âm nhạc Paléo tại Thụy Sĩ được nhắc đến thứ ba.'),
          ],
        ),
        ListeningActivity(
          activityId: 'gs12_review_01_listening_a2',
          activityNumber: '2',
          title: 'Activity 2: True or False',
          instruction: 'Listen again and decide whether the following sentences are True (T) or False (F).',
          instructionVi: 'Nghe lại và xác định các câu sau là Đúng (T) hay Sai (F).',
          interactionType: ListeningInteractionType.trueFalse,
          items: [
            ListeningItem(id: 'q1', prompt: '1. People in India celebrate Forest Festival (Van Mahotsav) annually.', options: ['T', 'F'], answer: 'T', explanationVi: 'Lễ hội trồng rừng diễn ra hàng năm tại Ấn Độ.'),
            ListeningItem(id: 'q2', prompt: '2. Only adults can plant trees during Forest Festival.', options: ['T', 'F'], answer: 'F', explanationVi: 'Mọi lứa tuổi, kể cả học sinh trẻ em đều tham gia trồng cây.'),
            ListeningItem(id: 'q3', prompt: '3. Vietnamese people release live fish into lakes and rivers after Tet Festival.', options: ['T', 'F'], answer: 'F', explanationVi: 'Người Việt thả cá chép TRƯỚC Tết (ngày 23 tháng Chạp - Tết ông Công ông Táo), không phải sau Tết.'),
            ListeningItem(id: 'q4', prompt: '4. People who want to attend Paléo Festival should use public transport.', options: ['T', 'F'], answer: 'T', explanationVi: 'Khuyến khích đi phương tiện công cộng để giảm khí thải.'),
          ],
        ),
      ],
    ),

    // REVIEW 2: Units 4-5 Skills (p. 74)
    ListeningLesson(
      lessonKey: 'review-02',
      unitNumber: 2,
      title: 'Review 2: Skills',
      topic: 'Dream City Development',
      printedPage: 74,
      isReview: true,
      activities: [
        ListeningActivity(
          activityId: 'gs12_review_02_listening_a1',
          activityNumber: '1',
          title: 'Activity 1: Main idea',
          instruction: 'Listen to a talk about a city. What is it about?',
          instructionVi: 'Nghe bài nói về một thành phố. Bài nói nói về điều gì?',
          interactionType: ListeningInteractionType.singleChoice,
          items: [
            ListeningItem(
              id: 'q1',
              prompt: '1. What is the talk mainly about?',
              options: ['A. How Dream City has changed.', 'B. The modern facilities in Dream City.', 'C. Why people leave Dream City.'],
              answer: 'A',
              explanationVi: 'Bài nói miêu tả quá trình thay đổi và phát triển của Dream City từ quá khứ đến hiện tại.',
            ),
          ],
        ),
        ListeningActivity(
          activityId: 'gs12_review_02_listening_a2',
          activityNumber: '2',
          title: 'Activity 2: Detailed statements',
          instruction: 'Listen again and decide whether the following statements are True (T) or False (F).',
          instructionVi: 'Nghe lại và xác định các nhận định là Đúng (T) hay Sai (F).',
          interactionType: ListeningInteractionType.trueFalse,
          items: [
            ListeningItem(id: 'q1', prompt: '1. Dream City used to be a small fishing village 20 years ago.', options: ['T', 'F'], answer: 'T', explanationVi: 'Hai mươi năm trước Dream City vốn là một làng chài nhỏ ven biển.'),
            ListeningItem(id: 'q2', prompt: '2. Most residents now work in the agricultural sector.', options: ['T', 'F'], answer: 'F', explanationVi: 'Đa số người dân hiện nay làm việc trong ngành dịch vụ và công nghệ.'),
          ],
        ),
      ],
    ),

    // REVIEW 3: Units 6-8 Skills (p. 114)
    ListeningLesson(
      lessonKey: 'review-03',
      unitNumber: 3,
      title: 'Review 3: Skills',
      topic: 'Blue whale conservation',
      printedPage: 114,
      isReview: true,
      activities: [
        ListeningActivity(
          activityId: 'gs12_review_03_listening_a1',
          activityNumber: '1',
          title: 'Activity 1: Threats to blue whales',
          instruction: 'Listen and choose the factors that have affected the blue whale population.',
          instructionVi: 'Nghe và chọn các yếu tố đã ảnh hưởng tiêu cực đến số lượng cá voi xanh.',
          interactionType: ListeningInteractionType.singleChoice,
          items: [
            ListeningItem(
              id: 'q1',
              prompt: '1. Which factor is mentioned as the historical cause of population collapse?',
              options: ['A. Commercial whaling in the early 20th century', 'B. Competition with sharks for food', 'C. Excessive tourism in polar waters'],
              answer: 'A',
              explanationVi: 'Nạn săn bắt cá voi vì mục đích thương mại vào đầu thế kỷ 20 đã làm sụt giảm nghiêm trọng số lượng loài.',
            ),
          ],
        ),
        ListeningActivity(
          activityId: 'gs12_review_03_listening_a2',
          activityNumber: '2',
          title: 'Activity 2: Multiple choice details',
          instruction: 'Listen again and choose the correct answer A, B, or C.',
          instructionVi: 'Nghe lại và chọn câu trả lời đúng A, B hoặc C.',
          interactionType: ListeningInteractionType.singleChoice,
          items: [
            ListeningItem(
              id: 'q1',
              prompt: '1. Why are blue whales more likely to be hit by ships at night?',
              options: ["A. They can't see or hear well at night.", 'B. There is more plastic pollution at night.', 'C. They are looking for food near the water surface at night.'],
              answer: 'C',
              explanationVi: 'Vào ban đêm, cá voi xanh thường bơi lên sát mặt nước để kiếm ăn nên dễ bị va chạm với tàu thuyền lớn.',
            ),
          ],
        ),
      ],
    ),

    // REVIEW 4: Units 9-10 Skills (p. 142)
    ListeningLesson(
      lessonKey: 'review-04',
      unitNumber: 4,
      title: 'Review 4: Skills',
      topic: 'Lifelong learning and career success',
      printedPage: 142,
      isReview: true,
      activities: [
        ListeningActivity(
          activityId: 'gs12_review_04_listening_a1',
          activityNumber: '1',
          title: 'Activity 1: Reason for lifelong learning',
          instruction: 'Listen to a talk about lifelong learning. Which of the following is NOT mentioned as a reason for lifelong learning?',
          instructionVi: 'Nghe bài nói về học tập suốt đời. Điều nào KHÔNG được nhắc đến như một lý do cần học tập suốt đời?',
          interactionType: ListeningInteractionType.singleChoice,
          items: [
            ListeningItem(
              id: 'q1',
              prompt: '1. Which is NOT mentioned as a reason for lifelong learning?',
              options: ['A. The impact of technology on jobs.', "B. Employees' expectations of immediate success.", 'C. A more competitive job market.'],
              answer: 'B',
              explanationVi: 'Bài nói chỉ nhắc đến tác động của công nghệ và thị trường lao động cạnh tranh, không nhắc đến kỳ vọng thành công tức thì của nhân viên.',
            ),
          ],
        ),
        ListeningActivity(
          activityId: 'gs12_review_04_listening_a2',
          activityNumber: '2',
          title: 'Activity 2: Complete the notes',
          instruction: 'Listen again and complete the following notes with no more than THREE words for each gap.',
          instructionVi: 'Nghe lại và hoàn thành các ghi chú với không quá BA từ cho mỗi chỗ trống.',
          interactionType: ListeningInteractionType.gapFill,
          items: [
            ListeningItem(id: 'q1', prompt: '1. Lifelong learning involves continuous ______ of knowledge and skills.', answer: 'acquisition', acceptableAnswers: ['acquisition', 'development', 'pursuit'], explanationVi: 'Học tập suốt đời đòi hỏi việc tích lũy và cập nhật liên tục tri thức.'),
            ListeningItem(id: 'q2', prompt: '2. We are living in an era of rapid technological ______.', answer: 'advancement', acceptableAnswers: ['advancement', 'change', 'development'], explanationVi: 'Kỷ nguyên phát triển công nghệ nhanh chóng (technological advancement).'),
            ListeningItem(id: 'q3', prompt: '3. Many traditional jobs are becoming fully ______.', answer: 'automated', acceptableAnswers: ['automated', 'automatic'], explanationVi: 'Nhiều công việc truyền thống đang được tự động hóa hoàn toàn (automated).'),
          ],
        ),
      ],
    ),
  ];
}

