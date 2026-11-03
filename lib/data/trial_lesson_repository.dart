import 'models/question.dart';

/// Đại diện cho một đoạn văn trong bài đọc SGK kèm bản dịch hỗ trợ
class LessonParagraph {
  final String id;
  final String label; // Ví dụ: "Đoạn A: Thời niên thiếu và học tập"
  final String text; // Nguyên văn tiếng Anh chuẩn SGK
  final String translation; // Bản dịch hỗ trợ do ứng dụng biên soạn
  final List<String> keyWords; // Các từ vựng trọng tâm trong đoạn

  const LessonParagraph({
    required this.id,
    required this.label,
    required this.text,
    required this.translation,
    this.keyWords = const [],
  });
}

/// Câu hỏi đọc hiểu học thử chuẩn SGK
class TrialQuestionData {
  final String id;
  final String word; // Tiêu đề câu hỏi, ví dụ: "1. adopted (SGK trang in 12)"
  final String targetWord; // Từ/cụm từ trọng tâm, ví dụ: "adopted"
  final String pageLabel; // Ví dụ: "Trang in 12"
  final String contextSentence; // Câu văn ngữ cảnh trích từ bài đọc
  final String contextTranslation; // Bản dịch hỗ trợ của câu ngữ cảnh
  final String textbookQuote; // Trích dẫn đối chiếu từ bài đọc
  final List<String> options; // Danh sách phương án
  final int correctIndex; // Vị trí đáp án đúng (0-based)
  final String explanation; // Lời giải biên soạn

  const TrialQuestionData({
    required this.id,
    required this.word,
    required this.targetWord,
    required this.pageLabel,
    required this.contextSentence,
    required this.contextTranslation,
    required this.textbookQuote,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  Question toQuestion({required String lessonId, required String topicId}) {
    return Question(
      id: id,
      grade: 12,
      type: 'reading',
      stem: '$word\nNgữ cảnh trong bài đọc: "$contextSentence"',
      options: options,
      correctIndex: correctIndex,
      explanation:
          'Trích dẫn SGK: "$textbookQuote"\nGiải nghĩa biên soạn: $explanation',
      topicId: topicId,
      passageId: lessonId,
      difficulty: 1,
    );
  }
}

/// Dữ liệu toàn diện của một bài học đọc hiểu tương tác
class TrialLessonData {
  final String lessonId; // ID ổn định, ví dụ: "trial_unit1_reading"
  final int unitNumber; // Số Unit (1..10)
  final String unitTitle; // Tiêu đề Unit
  final String lessonTitle; // Tiêu đề bài đọc
  final String skill; // Kỹ năng ("Reading")
  final String textbookSource; // Nguồn sách và số trang in
  final String activityName; // Tên hoạt động ("Activity 2")
  final String version; // Phiên bản nội dung
  final bool isReady; // Trạng thái sẵn sàng
  final String unreadyReason; // Lý do nếu chưa sẵn sàng
  final String estimatedDuration; // Thời lượng dự kiến ("ước tính 5-8 phút")
  final List<LessonParagraph> paragraphs; // Các đoạn văn
  final List<TrialQuestionData> questions; // Các câu hỏi
  final Map<String, String> vocabulary; // Từ điển từ vựng trọng tâm
  final Map<String, String> phraseDictionary; // Từ điển cụm từ

  const TrialLessonData({
    required this.lessonId,
    required this.unitNumber,
    required this.unitTitle,
    required this.lessonTitle,
    this.skill = 'Reading',
    required this.textbookSource,
    required this.activityName,
    this.version = '1.0.0',
    this.isReady = true,
    this.unreadyReason = '',
    this.estimatedDuration = 'Ước tính: 5-8 phút',
    required this.paragraphs,
    required this.questions,
    required this.vocabulary,
    this.phraseDictionary = const {},
  });

  List<Question> get questionsAsStandardQuestions => questions
      .map((q) => q.toQuestion(lessonId: lessonId, topicId: 'unit$unitNumber'))
      .toList();
}

/// Kết quả tra cứu từ hoặc cụm từ
class WordLookupResult {
  final String query;
  final String displayWord;
  final String? phonetic;
  final String? partOfSpeech;
  final String meaning;
  final String source;
  final bool isFoundInDictionary;
  final bool isPhrase;
  final String? sentenceTranslation;
  final String? grammaticalRole; // Vai trò ngữ pháp theo ngữ cảnh trong câu
  final String? contextSentence; // Câu ngữ cảnh chứa từ
  final String? phraseSuggestion; // Cụm từ gợi ý nếu từ nằm trong cụm từ SGK
  final String? phraseMeaning; // Nghĩa của cụm từ gợi ý

  const WordLookupResult({
    required this.query,
    required this.displayWord,
    this.phonetic,
    this.partOfSpeech,
    required this.meaning,
    required this.source,
    required this.isFoundInDictionary,
    this.isPhrase = false,
    this.sentenceTranslation,
    this.grammaticalRole,
    this.contextSentence,
    this.phraseSuggestion,
    this.phraseMeaning,
  });
}

/// Kho dữ liệu bài học thử và từ điển học liệu ngoại tuyến chuẩn SGK 12 Global Success
class TrialLessonRepository {
  TrialLessonRepository._();

  static final TrialLessonRepository instance = TrialLessonRepository._();

  // ===========================================================================
  // TỪ ĐIỂN TỔNG QUÁT NGOẠI TUYẾN DÀNH CHO BÀI ĐỌC SGK 12
  // ===========================================================================
  static const Map<String, Map<String, String>> _generalDictionary = {
    'born': {
      'phonetic': '/bɔːn/',
      'pos': '(v)',
      'meaning': 'sinh ra, chào đời',
    },
    'parents': {
      'phonetic': '/ˈpeərənts/',
      'pos': '(n)',
      'meaning': 'bố mẹ, phụ huynh',
    },
    'biological': {
      'phonetic': '/ˌbaɪəˈlɒdʒɪkl/',
      'pos': '(adj)',
      'meaning': 'thuộc về sinh học, huyết thống (cha mẹ ruột)',
    },
    'adoption': {
      'phonetic': '/əˈdɒpʃn/',
      'pos': '(n)',
      'meaning': 'sự nhận con nuôi',
    },
    'bonded': {
      'phonetic': '/ˈbɒndɪd/',
      'pos': '(v-ed)',
      'meaning': 'gắn kết, kết thân sâu sắc',
    },
    'college': {
      'phonetic': '/ˈkɒlɪdʒ/',
      'pos': '(n)',
      'meaning': 'trường đại học, cao đẳng',
    },
    'boring': {
      'phonetic': '/ˈbɔːrɪŋ/',
      'pos': '(adj)',
      'meaning': 'nhàm chán, tẻ nhạt',
    },
    'garage': {
      'phonetic': '/ˈɡærɑːʒ/',
      'pos': '(n)',
      'meaning': 'nhàเพื่อ để xe, ga-ra',
    },
    'success': {
      'phonetic': '/səkˈses/',
      'pos': '(n)',
      'meaning': 'sự thành công, thành tựu lớn',
    },
    'invent': {
      'phonetic': '/ɪnˈvent/',
      'pos': '(v)',
      'meaning': 'phát minh, sáng chế',
    },
    'introduced': {
      'phonetic': '/ˌɪntrəˈdjuːst/',
      'pos': '(v-ed)',
      'meaning': 'giới thiệu, ra mắt công chúng',
    },
    'stylish': {
      'phonetic': '/ˈstaɪlɪʃ/',
      'pos': '(adj)',
      'meaning': 'thời trang, phong cách, thẩm mỹ',
    },
    'diagnosed': {
      'phonetic': '/ˈdaɪəɡnəʊzd/',
      'pos': '(v-ed)',
      'meaning': 'được chẩn đoán (bệnh)',
    },
    'pancreatic': {
      'phonetic': '/ˌpæŋkriˈætɪk/',
      'pos': '(adj)',
      'meaning': 'thuộc tuyến tụy',
    },
    'visionary': {
      'phonetic': '/ˈvɪʒənri/',
      'pos': '(adj/n)',
      'meaning': 'có tầm nhìn xa trông rộng',
    },
    'residents': {
      'phonetic': '/ˈrezɪdənts/',
      'pos': '(n)',
      'meaning': 'cư dân, người sinh sống tại một khu vực',
    },
    'colonial': {
      'phonetic': '/kəˈləʊniəl/',
      'pos': '(adj)',
      'meaning': 'thuộc thời kỳ thuộc địa',
    },
    'gradually': {
      'phonetic': '/ˈɡrædʒuəli/',
      'pos': '(adv)',
      'meaning': 'dần dần, từ từ qua thời gian',
    },
    'modernising': {
      'phonetic': '/ˈmɒdənaɪzɪŋ/',
      'pos': '(v-ing)',
      'meaning': 'hiện đại hóa, đổi mới theo công nghệ tiên tiến',
    },
    'concern': {
      'phonetic': '/kənˈsɜːn/',
      'pos': '(n/v)',
      'meaning': 'mối lo ngại, sự quan tâm lo lắng',
    },
    'infrastructure': {
      'phonetic': '/ˈɪnfrəstrʌktʃə(r)/',
      'pos': '(n)',
      'meaning': 'cơ sở hạ tầng (đường xá, cầu cống, giao thông)',
    },
    'exhibition': {
      'phonetic': '/ˌeksɪˈbɪʃn/',
      'pos': '(n)',
      'meaning': 'cuộc triển lãm, trưng bày',
    },
    'vacancies': {
      'phonetic': '/ˈveɪkənsiz/',
      'pos': '(n, số nhiều)',
      'meaning': 'vị trí tuyển dụng đang còn trống',
    },
    'flexible': {
      'phonetic': '/ˈfleksəbl/',
      'pos': '(adj)',
      'meaning': 'linh hoạt (về thời gian làm việc)',
    },
    'reviews': {
      'phonetic': '/rɪˈvjuːz/',
      'pos': '(n, số nhiều)',
      'meaning': 'bài đánh giá, nhận xét sản phẩm',
    },
    'casual': {
      'phonetic': '/ˈkæʒuəl/',
      'pos': '(adj)',
      'meaning': 'công việc tạm thời, thời vụ, không cố định',
    },
    'portfolio': {
      'phonetic': '/pɔːtˈfəʊliəʊ/',
      'pos': '(n)',
      'meaning': 'hồ sơ năng lực, tập hợp kinh nghiệm học tập & làm việc',
    },
    'virtual': {
      'phonetic': '/ˈvɜːtʃuəl/',
      'pos': '(adj)',
      'meaning': 'ảo, hiển thị qua máy tính/Internet',
    },
    'platform': {
      'phonetic': '/ˈplætfɔːm/',
      'pos': '(n)',
      'meaning': 'nền tảng phần mềm hoặc hệ thống học tập',
    },
    'passionate': {
      'phonetic': '/ˈpæʃənət/',
      'pos': '(adj)',
      'meaning': 'đam mê, nhiệt huyết mạnh mẽ với điều gì',
    },
    'specialty': {
      'phonetic': '/ˈspeʃəlti/',
      'pos': '(n)',
      'meaning': 'chuyên môn đào tạo sâu (hoặc món đặc sản)',
    },
    'barista': {
      'phonetic': '/bəˈriːstə/',
      'pos': '(n)',
      'meaning': 'nhân viên pha chế đồ uống (cà phê)',
    },
    'obsolete': {
      'phonetic': '/ˈɒbsəliːt/',
      'pos': '(adj)',
      'meaning': 'lỗi thời, không còn được sử dụng',
    },
    'wonder': {
      'phonetic': '/ˈwʌndə(r)/',
      'pos': '(v)',
      'meaning': 'băn khoăn, tự hỏi, suy nghĩ',
    },
    'relevant': {
      'phonetic': '/ˈreləvənt/',
      'pos': '(adj)',
      'meaning': 'phù hợp, hữu ích và có ý nghĩa thiết thực',
    },
    'widens': {
      'phonetic': '/ˈwaɪdnz/',
      'pos': '(v)',
      'meaning': 'mở rộng (phạm vi cơ hội việc làm, tri thức)',
    },
    'hardships': {
      'phonetic': '/ˈhɑːdʃɪps/',
      'pos': '(n, số nhiều)',
      'meaning': 'sự gian nan, gian khổ, thử thách khắc nghiệt',
    },
    'imprisoned': {
      'phonetic': '/ɪmˈprɪznd/',
      'pos': '(v-ed)',
      'meaning': 'bị giam cầm, bị tù đày',
    },
    'globalisation': {
      'phonetic': '/ˌɡləʊbəlaɪˈzeɪʃn/',
      'pos': '(n)',
      'meaning': 'sự toàn cầu hóa, quá trình hội nhập thế giới',
    },
    'diversity': {
      'phonetic': '/daɪˈvɜːsəti/',
      'pos': '(n)',
      'meaning': 'sự đa dạng, phong phú về văn hóa và cuộc sống',
    },
    'cuisine': {
      'phonetic': '/kwɪˈziːn/',
      'pos': '(n)',
      'meaning': 'ẩm thực, phong cách nấu nướng đặc trưng',
    },
    'cuisines': {
      'phonetic': '/kwɪˈziːnz/',
      'pos': '(n)',
      'meaning': 'các nền ẩm thực, phong cách ẩm thực khác nhau',
    },
    'specialities': {
      'phonetic': '/ˌspeʃiˈælətiz/',
      'pos': '(n)',
      'meaning': 'những món ăn đặc sản, nét đặc trưng địa phương',
    },
    'captivated': {
      'phonetic': '/ˈkæptɪveɪtɪd/',
      'pos': '(v-ed)',
      'meaning': 'bị lôi cuốn, mê hoặc, cuốn hút mạnh mẽ',
    },
    'festivals': {
      'phonetic': '/ˈfestɪvlz/',
      'pos': '(n)',
      'meaning': 'các lễ hội âm nhạc hoặc văn hóa',
    },
    'blend': {
      'phonetic': '/blend/',
      'pos': '(v)',
      'meaning': 'pha trộn, kết hợp hài hòa nhiều yếu tố',
    },
    'identities': {
      'phonetic': '/aɪˈdentətiz/',
      'pos': '(n)',
      'meaning': 'bản sắc, nét đặc trưng cá nhân hoặc dân tộc',
    },
    'decompose': {
      'phonetic': '/ˌdiːkəmˈpəʊz/',
      'pos': '(v)',
      'meaning': 'phân hủy tự nhiên trong đất hoặc môi trường',
    },
    'landfills': {
      'phonetic': '/ˈlændfɪlz/',
      'pos': '(n)',
      'meaning': 'các bãi chôn lấp rác thải',
    },
    'reusable': {
      'phonetic': '/ˌriːˈjuːzəbl/',
      'pos': '(adj)',
      'meaning': 'có thể tái sử dụng nhiều lần, dùng lại được',
    },
    'packaging': {
      'phonetic': '/ˈpækɪdʒɪŋ/',
      'pos': '(n)',
      'meaning': 'bao bì đóng gói sản phẩm hàng hóa',
    },
    'leftovers': {
      'phonetic': '/ˈleftəʊvəz/',
      'pos': '(n)',
      'meaning': 'thức ăn thừa sau bữa ăn chưa dùng hết',
    },
    'contaminated': {
      'phonetic': '/kənˈtæmɪneɪtɪd/',
      'pos': '(v-ed/adj)',
      'meaning': 'bị làm bẩn, nhiễm tạp chất hoặc vi khuẩn',
    },
    'accessible': {
      'phonetic': '/əkˈsesəbl/',
      'pos': '(adj)',
      'meaning': 'dễ tiếp cận, có thể truy cập và sử dụng được',
    },
    'interactive': {
      'phonetic': '/ˌɪntərˈæktɪv/',
      'pos': '(adj)',
      'meaning': 'có tính tương tác qua lại hai chiều giữa các bên',
    },
    'credible': {
      'phonetic': '/ˈkredəbl/',
      'pos': '(adj)',
      'meaning': 'đáng tin cậy, có thể tin tưởng được',
    },
    'broadcast': {
      'phonetic': '/ˈbrɔːdkɑːst/',
      'pos': '(n/v)',
      'meaning': 'phát sóng truyền hình hoặc đài phát thanh',
    },
    'debris': {
      'phonetic': '/ˈdebriː/',
      'pos': '(n)',
      'meaning': 'mảnh vụn, rác thải vỡ trôi nổi',
    },
    'marine': {
      'phonetic': '/məˈriːn/',
      'pos': '(adj)',
      'meaning': 'thuộc về biển cả, hải dương',
    },
    'vulnerable': {
      'phonetic': '/ˈvʌlnərəbl/',
      'pos': '(adj)',
      'meaning': 'dễ bị tổn thương, gặp nguy hiểm (loài nguy cấp)',
    },
    'extinction': {
      'phonetic': '/ɪkˈstɪŋkʃn/',
      'pos': '(n)',
      'meaning': 'sự tuyệt chủng hoàn toàn của loài sinh vật',
    },
    'biodiversity': {
      'phonetic': '/ˌbaɪəʊdaɪˈvɜːsəti/',
      'pos': '(n)',
      'meaning': 'sự đa dạng sinh học trong hệ sinh thái',
    },
    'attract': {
      'phonetic': '/əˈtrækt/',
      'pos': '(v)',
      'meaning': 'thu hút, lôi cuốn, hấp dẫn (sự chú ý, du khách, người xem)',
    },
    'attracted': {
      'phonetic': '/əˈtræktɪd/',
      'pos': '(v-ed / v3)',
      'meaning': 'đã thu hút, lôi cuốn (dạng quá khứ/phân từ của attract)',
    },
    'attraction': {
      'phonetic': '/əˈtrækʃn/',
      'pos': '(n)',
      'meaning': 'sự thu hút, điểm tham quan hấp dẫn',
    },
    'attractive': {
      'phonetic': '/əˈtræktɪv/',
      'pos': '(adj)',
      'meaning': 'hấp dẫn, lôi cuốn, quyến rũ',
    },
    'thousands': {
      'phonetic': '/ˈθaʊzndz/',
      'pos': '(n, số nhiều)',
      'meaning': 'hàng ngàn, hàng nghìn (số lượng lớn)',
    },
    'child': {
      'phonetic': '/tʃaɪld/',
      'pos': '(n)',
      'meaning': 'đứa trẻ, con cái',
    },
    'children': {
      'phonetic': '/ˈtʃɪldrən/',
      'pos': '(n, số nhiều)',
      'meaning': 'trẻ em, những đứa con (dạng số nhiều bất quy tắc của child)',
    },
    'go': {
      'phonetic': '/ɡəʊ/',
      'pos': '(v)',
      'meaning': 'đi, di chuyển, tới đâu đó',
    },
    'see': {
      'phonetic': '/siː/',
      'pos': '(v)',
      'meaning': 'nhìn thấy, chứng kiến, nhận ra',
    },
    'build': {
      'phonetic': '/bɪld/',
      'pos': '(v)',
      'meaning': 'xây dựng, kiến tạo, thiết lập',
    },
    'buy': {
      'phonetic': '/baɪ/',
      'pos': '(v)',
      'meaning': 'mua sắm',
    },
    'think': {
      'phonetic': '/θɪŋk/',
      'pos': '(v)',
      'meaning': 'nghĩ, suy nghĩ, cho rằng',
    },
    'find': {
      'phonetic': '/faɪnd/',
      'pos': '(v)',
      'meaning': 'tìm thấy, phát hiện ra',
    },
    'give': {
      'phonetic': '/ɡɪv/',
      'pos': '(v)',
      'meaning': 'cho, trao tặng, mang lại',
    },
    'take': {
      'phonetic': '/teɪk/',
      'pos': '(v)',
      'meaning': 'lấy, tiếp nhận, thực hiện',
    },
    'write': {
      'phonetic': '/raɪt/',
      'pos': '(v)',
      'meaning': 'viết, sáng tác',
    },
    'become': {
      'phonetic': '/bɪˈkʌm/',
      'pos': '(v)',
      'meaning': 'trở thành, trở nên',
    },
    'begin': {
      'phonetic': '/bɪˈɡɪn/',
      'pos': '(v)',
      'meaning': 'bắt đầu, khởi đầu',
    },
    'feel': {
      'phonetic': '/fiːl/',
      'pos': '(v)',
      'meaning': 'cảm thấy, cảm giác',
    },
    'keep': {
      'phonetic': '/kiːp/',
      'pos': '(v)',
      'meaning': 'giữ, duy trì',
    },
    'lose': {
      'phonetic': '/luːz/',
      'pos': '(v)',
      'meaning': 'mất mát, thất lạc, thua',
    },
    'grow': {
      'phonetic': '/ɡrəʊ/',
      'pos': '(v)',
      'meaning': 'phát triển, tăng trưởng, trồng trọt',
    },
    'know': {
      'phonetic': '/nəʊ/',
      'pos': '(v)',
      'meaning': 'biết, hiểu rõ',
    },
    'box': {
      'phonetic': '/bɒks/',
      'pos': '(n)',
      'meaning': 'chiếc hộp, thùng đựng đồ',
    },
    'city': {
      'phonetic': '/ˈsɪti/',
      'pos': '(n)',
      'meaning': 'thành phố, đô thị',
    },
    'year': {
      'phonetic': '/jɪə(r)/',
      'pos': '(n)',
      'meaning': 'năm, niên khóa',
    },
    'people': {
      'phonetic': '/ˈpiːpl/',
      'pos': '(n, số nhiều)',
      'meaning': 'con người, mọi người (dạng số nhiều của person)',
    },
    'create': {
      'phonetic': '/kriˈeɪt/',
      'pos': '(v)',
      'meaning': 'tạo ra, sáng tạo nên',
    },
    'created': {
      'phonetic': '/kriˈeɪtɪd/',
      'pos': '(v-ed / v3)',
      'meaning': 'đã tạo ra, đã sáng lập (dạng quá khứ của create)',
    },
    'decide': {
      'phonetic': '/dɪˈsaɪd/',
      'pos': '(v)',
      'meaning': 'quyết định, lựa chọn',
    },
    'decided': {
      'phonetic': '/dɪˈsaɪdɪd/',
      'pos': '(v-ed / v3)',
      'meaning': 'đã quyết định (dạng quá khứ của decide)',
    },
    'serve': {
      'phonetic': '/sɜːv/',
      'pos': '(v)',
      'meaning': 'phục vụ, cống hiến, phụng sự',
    },
    'served': {
      'phonetic': '/sɜːvd/',
      'pos': '(v-ed / v3)',
      'meaning': 'đã phục vụ, đã cống hiến (dạng quá khứ của serve)',
    },
    'work': {
      'phonetic': '/wɜːk/',
      'pos': '(v/n)',
      'meaning': 'làm việc, công việc, tác phẩm',
    },
    'worked': {
      'phonetic': '/wɜːkt/',
      'pos': '(v-ed / v3)',
      'meaning': 'đã làm việc (dạng quá khứ của work)',
    },
    'live': {
      'phonetic': '/lɪv/',
      'pos': '(v)',
      'meaning': 'sống, sinh sống',
    },
    'lived': {
      'phonetic': '/lɪvd/',
      'pos': '(v-ed / v3)',
      'meaning': 'đã sống, từng sinh sống (dạng quá khứ của live)',
    },
    'develop': {
      'phonetic': '/dɪˈveləp/',
      'pos': '(v)',
      'meaning': 'phát triển, mở rộng quy mô, nghiên cứu chế tạo',
    },
    'developed': {
      'phonetic': '/dɪˈveləpt/',
      'pos': '(v-ed / v3)',
      'meaning': 'đã phát triển (dạng quá khứ của develop)',
    },
    'achieve': {
      'phonetic': '/əˈtʃiːv/',
      'pos': '(v)',
      'meaning': 'đạt được, gặt hái thành công',
    },
    'achieved': {
      'phonetic': '/əˈtʃiːvd/',
      'pos': '(v-ed / v3)',
      'meaning': 'đã đạt được thành tựu (dạng quá khứ của achieve)',
    },
    'achievement': {
      'phonetic': '/əˈtʃiːvmənt/',
      'pos': '(n)',
      'meaning': 'thành tựu, thành tích to lớn',
    },
    'achievements': {
      'phonetic': '/əˈtʃiːvmənts/',
      'pos': '(n, số nhiều)',
      'meaning': 'thành tựu, thành tích lớn đạt được trong sự nghiệp',
    },
    'increase': {
      'phonetic': '/ɪnˈkriːs/',
      'pos': '(v/n)',
      'meaning': 'tăng lên, sự gia tăng',
    },
    'decreased': {
      'phonetic': '/dɪˈkriːst/',
      'pos': '(v-ed / v3)',
      'meaning': 'đã giảm sút, suy giảm (dạng quá khứ của decrease)',
    },
    'connect': {
      'phonetic': '/kəˈnekt/',
      'pos': '(v)',
      'meaning': 'kết nối, liên kết, nối lại với nhau',
    },
    'connected': {
      'phonetic': '/kəˈnektɪd/',
      'pos': '(adj/v-ed)',
      'meaning': 'được kết nối, gắn kết, liên kết với nhau',
    },
    'global': {
      'phonetic': '/ˈɡləʊbl/',
      'pos': '(adj)',
      'meaning': 'toàn cầu, trên toàn thế giới',
    },
    'belief': {
      'phonetic': '/bɪˈliːf/',
      'pos': '(n)',
      'meaning': 'niềm tin, tín ngưỡng',
    },
    'beliefs': {
      'phonetic': '/bɪˈliːfs/',
      'pos': '(n, số nhiều)',
      'meaning': 'tín ngưỡng, niềm tin tôn giáo, quan niệm',
    },
    'custom': {
      'phonetic': '/ˈkʌstəm/',
      'pos': '(n)',
      'meaning': 'phong tục, tập quán truyền thống',
    },
    'customs': {
      'phonetic': '/ˈkʌstəmz/',
      'pos': '(n, số nhiều)',
      'meaning': 'phong tục tập quán của một cộng đồng/dân tộc',
    },
    'respect': {
      'phonetic': '/rɪˈspekt/',
      'pos': '(n/v)',
      'meaning': 'khía cạnh, phương diện (hoặc sự tôn trọng)',
    },
    'respects': {
      'phonetic': '/rɪˈspekts/',
      'pos': '(n, số nhiều)',
      'meaning': 'các phương diện, khía cạnh khác nhau',
    },
    'similar': {
      'phonetic': '/ˈsɪmələ(r)/',
      'pos': '(adj)',
      'meaning': 'tương tự, giống nhau, tương đồng',
    },
    'culture': {
      'phonetic': '/ˈkʌltʃə(r)/',
      'pos': '(n)',
      'meaning': 'văn hóa, nền văn minh',
    },
    'cultural': {
      'phonetic': '/ˈkʌltʃərəl/',
      'pos': '(adj)',
      'meaning': 'thuộc về văn hóa',
    },
    'dish': {
      'phonetic': '/dɪʃ/',
      'pos': '(n)',
      'meaning': 'món ăn',
    },
    'dishes': {
      'phonetic': '/ˈdɪʃɪz/',
      'pos': '(n, số nhiều)',
      'meaning': 'các món ăn ẩm thực',
    },
    'chain': {
      'phonetic': '/tʃeɪn/',
      'pos': '(n)',
      'meaning': 'chuỗi, dây chuyền',
    },
    'chains': {
      'phonetic': '/tʃeɪnz/',
      'pos': '(n, số nhiều)',
      'meaning': 'chuỗi cửa hàng, chuỗi nhà hàng kinh doanh',
    },
    'ingredient': {
      'phonetic': '/ɪnˈɡriːdiənt/',
      'pos': '(n)',
      'meaning': 'thành phần, nguyên liệu',
    },
    'ingredients': {
      'phonetic': '/ɪnˈɡriːdiənts/',
      'pos': '(n, số nhiều)',
      'meaning': 'các nguyên liệu dùng để nấu ăn',
    },
    'identity': {
      'phonetic': '/aɪˈdentəti/',
      'pos': '(n)',
      'meaning': 'bản sắc, đặc trưng riêng',
    },
    'popular': {
      'phonetic': '/ˈpɒpjələ(r)/',
      'pos': '(adj)',
      'meaning': 'phổ biến, được ưa chuộng rộng rãi',
    },
    'international': {
      'phonetic': '/ˌɪntəˈnæʃnəl/',
      'pos': '(adj)',
      'meaning': 'quốc tế, toàn cầu',
    },
    'appreciate': {
      'phonetic': '/əˈpriːʃieɪt/',
      'pos': '(v)',
      'meaning': 'trân trọng, đánh giá cao, thưởng thức',
    },
  };

  // Bảng động từ bất quy tắc phổ biến SGK 12
  static const Map<String, String> _irregularVerbs = {
    'went': 'go',
    'gone': 'go',
    'saw': 'see',
    'seen': 'see',
    'built': 'build',
    'bought': 'buy',
    'thought': 'think',
    'found': 'find',
    'gave': 'give',
    'given': 'give',
    'took': 'take',
    'taken': 'take',
    'wrote': 'write',
    'written': 'write',
    'became': 'become',
    'began': 'begin',
    'begun': 'begin',
    'felt': 'feel',
    'kept': 'keep',
    'lost': 'lose',
    'paid': 'pay',
    'stood': 'stand',
    'taught': 'teach',
    'told': 'tell',
    'understood': 'understand',
    'won': 'win',
    'grew': 'grow',
    'grown': 'grow',
    'knew': 'know',
    'known': 'know',
    'spoke': 'speak',
    'spoken': 'speak',
    'chose': 'choose',
    'chosen': 'choose',
    'drove': 'drive',
    'driven': 'drive',
    'ate': 'eat',
    'eaten': 'eat',
    'fell': 'fall',
    'fallen': 'fall',
    'flew': 'fly',
    'flown': 'fly',
    'forgot': 'forget',
    'forgotten': 'forget',
    'got': 'get',
    'gotten': 'get',
    'heard': 'hear',
    'held': 'hold',
    'left': 'leave',
    'met': 'meet',
    'read': 'read',
    'ran': 'run',
    'sent': 'send',
    'spent': 'spend',
    'swam': 'swim',
    'swum': 'swim',
    'threw': 'throw',
    'thrown': 'throw',
    'brought': 'bring',
    'caught': 'catch',
    'drawn': 'draw',
    'drew': 'draw',
    'drank': 'drink',
    'drunk': 'drink',
    'rose': 'rise',
    'risen': 'rise',
    'shook': 'shake',
    'slept': 'sleep',
    'stole': 'steal',
    'wore': 'wear',
    'broken': 'break',
    'broke': 'break',
    'laid': 'lay',
    'led': 'lead',
    'meant': 'mean',
    'set': 'set',
    'put': 'put',
    'cut': 'cut',
    'spread': 'spread',
  };

  // Danh sách các quá khứ phân từ nhận diện thì hoàn thành / thể bị động
  static const Set<String> _pastParticiples = {
    'attracted',
    'been',
    'seen',
    'done',
    'gone',
    'become',
    'built',
    'written',
    'made',
    'taken',
    'left',
    'known',
    'felt',
    'lost',
    'found',
    'grown',
    'given',
    'held',
    'led',
    'run',
    'understood',
    'won',
    'spent',
    'set',
    'put',
    'cut',
    'cost',
    'read',
    'paid',
    'brought',
    'bought',
    'caught',
    'taught',
    'sold',
    'told',
    'chosen',
    'driven',
    'eaten',
    'fallen',
    'forgotten',
    'gotten',
    'heard',
    'met',
    'sent',
    'swum',
    'thrown',
    'drawn',
    'drunk',
    'risen',
    'shaken',
    'slept',
    'stolen',
    'worn',
    'broken',
    'graduated',
    'decided',
    'increased',
    'decreased',
    'changed',
    'modernised',
    'developed',
    'started',
    'created',
    'stopped',
    'worked',
    'lived',
    'diagnosed',
    'served',
    'joined',
    'passed',
    'promoted',
    'received',
    'completed',
    'applied',
    'achieved',
    'improved',
    'introduced',
    'published',
    'established',
    'founded',
    'recognized',
    'invented',
    'discovered',
    'caused',
    'designed',
    'named',
    'used',
    'produced',
    'admired',
    'inspired',
    'surrounded',
    'faced',
    'solved',
    'protected',
    'damaged',
    'threatened',
    'saved',
    'encouraged',
  };

  // Trạng từ chen giữa trợ động từ và động từ chính
  static const Set<String> _adverbsOfFrequencyAndDegree = {
    'already',
    'never',
    'ever',
    'recently',
    'just',
    'greatly',
    'always',
    'also',
    'now',
    'often',
    'successfully',
    'quickly',
    'gradually',
    'slowly',
    'even',
    'still',
    'probably',
    'certainly',
    'almost',
  };

  // ===========================================================================
  // TỪ ĐIỂN CỤM TỪ (PHRASAL VERBS & IDIOMS) PHỔ BIẾN
  // ===========================================================================
  static const Map<String, String> phraseDictionary = {
    'attracted thousands': 'thu hút hàng nghìn người tham gia/theo dõi',
    'pass away': 'qua đời, mất (cách nói trang trọng thay cho die)',
    'passed away': 'đã qua đời, đã mất',
    'drop out': 'bỏ học giữa chừng',
    'dropped out': 'đã bỏ học giữa chừng',
    'in addition to': 'bên cạnh, ngoài ra, thêm vào đó',
    'take pride in': 'tự hào về điều gì đó',
    'took pride in': 'đã tự hào về điều gì đó',
    'break down': 'hỏng hóc, suy sụp',
    'broke down': 'đã bị hỏng, đã suy sụp',
    'cope with': 'đối phó, xử lý, đương đầu với khó khăn',
    'work out': 'tìm ra cách giải quyết, tập thể dục',
    'carry out': 'tiến hành, thực hiện (nghiên cứu, kế hoạch)',
    'carried out': 'đã tiến hành, đã thực hiện',
    'give up': 'từ bỏ, bỏ cuộc',
    'gave up': 'đã từ bỏ, đã bỏ cuộc',
    'cardboard boxes': 'thùng các-tông, hộp bìa cứng đóng hàng',
    'cardboard box': 'thùng các-tông',
    'rinse out': 'tráng sạch hoặc súc rửa bằng nước',
    'spawning ground': 'bãi đẻ trứng của sinh vật biển',
    'here to stay': 'tiếp tục tồn tại lâu dài, là một phần cuộc sống',
    'thing of the past': 'trở thành điều dĩ vãng trong quá khứ',
    'takeaway containers': 'hộp nhựa đựng đồ ăn mang về',
    'vending machine': 'máy bán hàng tự động',
    'drinking fountains': 'vòi phun nước uống tại trường/nơi công cộng',
    'water filling stations': 'trạm tiếp nước, bình rót nước công cộng',
    'remove the cap': 'tháo nắp chai trước khi tái chế',
    'coral reef': 'rạn san hô biển',
    'sea turtle': 'loài rùa biển',
    'raise public awareness': 'nâng cao nhận thức của cộng đồng',
    'raise money': 'gây quỹ từ thiện hoặc bảo tồn',
    'gave him up': 'trao cho người khác (nhận nuôi)',
    'bonded over': 'gắn kết với nhau nhờ sở thích chung',
    'started apple computers': 'thành lập công ty máy tính Apple',
    'cutting-edge': 'tiên tiến, hiện đại bậc nhất',
    'cutting edge': 'công nghệ mũi nhọn, tiên tiến nhất',
    'touch-screen': 'màn hình cảm ứng',
    'touch screen': 'màn hình cảm ứng',
    'computer animation': 'hoạt hình máy tính (Pixar)',
    'on foot': 'đi bộ',
    'then and now': 'xưa và nay',
    'old quarter': 'khu phố cổ (36 phố phường)',
    'high-rise': 'nhà cao tầng',
    'high rise': 'nhà cao tầng',
    'low-rise': 'nhà thấp tầng',
    'low rise': 'nhà thấp tầng',
    'traffic jams': 'ùn tắc giao thông, kẹt xe',
    'air pollution': 'ô nhiễm không khí',
    'unemployment rates': 'tỷ lệ thất nghiệp',
    'on-the-job training': 'đào tạo thực tế ngay tại nơi làm việc',
    'on the job training': 'đào tạo tại chỗ khi đi làm',
    'part-time': 'bán thời gian',
    'part time': 'bán thời gian',
    'take care of': 'chăm sóc, trông nom',
    'take into account': 'xem xét, tính đến, cân nhắc kỹ',
    'hands-on': 'trải nghiệm thực tế, tự tay làm',
    'hands on': 'thực hành trực tiếp',
    'distance learning': 'học từ xa, học trực tuyến',
    'night school': 'lớp học ban đêm',
    'role model': 'tấm gương sáng, hình mẫu lý tưởng',
    'lifelong learning': 'học tập suốt đời',
  };

  // ===========================================================================
  // BÀI HỌC 1: UNIT 1 - STEVE JOBS (CHUẨN SGK TRANG IN 11-12)
  // ===========================================================================
  static const TrialLessonData _unit1Lesson = TrialLessonData(
    lessonId: 'trial_unit1_reading',
    unitNumber: 1,
    unitTitle: 'Life Stories We Admire',
    lessonTitle: 'Steve Jobs: Life and Achievements',
    textbookSource:
        'SGK Tiếng Anh 12 Global Success · Unit 1: Life Stories We Admire · Reading (Trang in 11-12)',
    activityName: 'Activity 2: Chọn nghĩa phù hợp với từ in đậm',
    estimatedDuration: 'Ước tính: 5-8 phút',
    paragraphs: [
      LessonParagraph(
        id: 'u1_para_a',
        label: 'Đoạn A: Thời niên thiếu và học tập (SGK trang in 11)',
        text:
            'Steven Paul Jobs was born on 24 February, 1955 in San Francisco, USA. His biological parents were not married and gave him up for adoption. He was adopted by Clara and Paul Jobs. In 1971, Jobs met Steve Wozniak, who was five years older than him, but they bonded over their love of electronics. After high school, Jobs attended Reed College in Oregon, but found the classes boring and dropped out after six months.',
        translation:
            'Steven Paul Jobs sinh ngày 24 tháng 2 năm 1955 tại San Francisco, Hoa Kỳ. Cha mẹ ruột của ông chưa kết hôn và đã trao ông cho người khác nhận nuôi. Ông được Clara và Paul Jobs nhận làm con nuôi. Năm 1971, Jobs gặp Steve Wozniak, người lớn hơn ông 5 tuổi, nhưng họ đã gắn kết với nhau nhờ niềm đam mê chung về thiết bị điện tử. Sau khi tốt nghiệp trung học, Jobs theo học tại Đại học Reed ở Oregon, nhưng nhận thấy các lớp học nhàm chán và đã bỏ học chỉ sau 6 tháng.',
        keyWords: ['adopted', 'dropped out', 'electronics'],
      ),
      LessonParagraph(
        id: 'u1_para_b',
        label: 'Đoạn B: Sự nghiệp tại Apple & Pixar (SGK trang in 11)',
        text:
            "When Jobs was 21, he and Wozniak started Apple Computers in Jobs' family garage with money they got by selling Jobs' van and Wozniak's scientific calculator. By making computers smaller, cheaper, and accessible to everyday users, their company became a huge success and sales quickly increased. Although Jobs left Apple in 1985, he returned to his post in 1997 when the company needed new ideas. He helped invent new products such as the iMac, the iBook for students, the iPod music player, and iTunes music software. In 2007, he introduced the touch-screen iPhone which changed the way phones were used. Apple products were not only designed to be cutting-edge technology, but also to be stylish and easy to use. In addition, Jobs contributed to computer animation. In 1986, he bought a small company, which later became Pixar Animation Studios. It produced the first full-length computer-animated film Toy Story, followed by other blockbusters.",
        translation:
            'Khi Jobs 21 tuổi, ông cùng Wozniak thành lập hãng máy tính Apple Computers ngay trong ga-ra gia đình Jobs bằng số tiền bán chiếc xe tải nhỏ của Jobs và máy tính khoa học của Wozniak. Bằng cách tạo ra những chiếc máy tính nhỏ hơn, giá rẻ hơn và dễ tiếp cận cho người dùng phổ thông, công ty đã gặt hái thành công vang dội và doanh số tăng vọt nhanh chóng. Dù rời Apple năm 1985, ông đã trở lại cương vị của mình năm 1997 khi công ty cần những ý tưởng mới. Ông đã góp phần sáng chế ra các sản phẩm mới như iMac, iBook cho học sinh, máy nghe nhạc iPod và phần mềm iTunes. Năm 2007, ông ra mắt chiếc iPhone màn hình cảm ứng làm thay đổi hoàn toàn cách sử dụng điện thoại. Các sản phẩm của Apple không chỉ có công nghệ mũi nhọn tiên tiến mà còn thời trang và dễ sử dụng. Ngoài ra, Jobs còn đóng góp cho ngành hoạt hình máy tính. Năm 1986, ông mua lại một công ty nhỏ, sau này trở thành Xưởng phim hoạt hình Pixar. Nơi đây đã sản xuất bộ phim hoạt hình vi tính dài đầu tiên mang tên Câu chuyện đồ chơi (Toy Story), tiếp nối bởi nhiều bộ phim bom tấn khác.',
        keyWords: ['garage', 'accessible', 'cutting-edge', 'animation'],
      ),
      LessonParagraph(
        id: 'u1_para_c',
        label: 'Đoạn C: Thử thách, di sản & tôn vinh (SGK trang in 11)',
        text:
            "In 2003, Jobs was diagnosed with a rare form of pancreatic cancer. He fought the disease for several years, and stopped working in August, 2011. Two months later, he passed away. He had four children, three with his wife of 20 years and one from a previous relationship. On an Apple web page, a statement reads, 'Apple has lost a visionary and creative genius, and the world has lost an amazing human being.'",
        translation:
            'Năm 2003, Jobs được chẩn đoán mắc một thể ung thư tuyến tụy hiếm gặp. Ông kiên cường chống chọi với bệnh tật trong nhiều năm và ngừng làm việc vào tháng 8 năm 2011. Hai tháng sau đó, ông qua đời. Ông có 4 người con, 3 người với người vợ gắn bó 20 năm và 1 người từ mối quan hệ trước. Trên trang web của Apple, một thông điệp viết rằng: "Apple đã mất đi một thiên tài sáng tạo và có tầm nhìn xa trông rộng, và thế giới đã mất đi một con người phi thường."',
        keyWords: ['cancer', 'passed away', 'genius'],
      ),
    ],
    questions: [
      TrialQuestionData(
        id: 'u1_rd_q1',
        word: '1. adopted (SGK trang in 12)',
        targetWord: 'adopted',
        pageLabel: 'Trang in 12',
        contextSentence:
            'His biological parents were not married and gave him up for adoption. He was adopted by Clara and Paul Jobs.',
        contextTranslation:
            'Cha mẹ ruột của ông chưa kết hôn và đã trao ông cho người khác nhận nuôi. Ông được nhận làm con nuôi bởi Clara và Paul Jobs.',
        textbookQuote:
            'His biological parents were not married and gave him up for adoption. He was adopted by Clara and Paul Jobs.',
        options: [
          'A. given birth to',
          'B. taken by another family as their own child',
        ],
        correctIndex: 1,
        explanation:
            'Trong ngữ cảnh này, "adopted" có nghĩa là được một gia đình khác nhận làm con đẻ nuôi nấng.',
      ),
      TrialQuestionData(
        id: 'u1_rd_q2',
        word: '2. dropped out (SGK trang in 12)',
        targetWord: 'dropped out',
        pageLabel: 'Trang in 12',
        contextSentence:
            'After high school, Jobs attended Reed College in Oregon, but found the classes boring and dropped out after six months.',
        contextTranslation:
            'Sau trung học, Jobs học Đại học Reed ở Oregon, nhưng thấy nhàm chán và bỏ học sau 6 tháng.',
        textbookQuote:
            'Jobs attended Reed College in Oregon, but found the classes boring and dropped out after six months.',
        options: [
          'A. continued to study',
          'B. left school/college before completing your studies',
        ],
        correctIndex: 1,
        explanation:
            '"dropped out" là cụm động từ chỉ hành động rời bỏ trường lớp trước khi hoàn thành chương trình học.',
      ),
      TrialQuestionData(
        id: 'u1_rd_q3',
        word: '3. cancer (SGK trang in 12)',
        targetWord: 'cancer',
        pageLabel: 'Trang in 12',
        contextSentence:
            'In 2003, Jobs was diagnosed with a rare form of pancreatic cancer. He fought the disease for several years, and stopped working in August, 2011.',
        contextTranslation:
            'Năm 2003, Jobs được chẩn đoán mắc bệnh ung thư tuyến tụy hiếm gặp. Ông đã chiến đấu với căn bệnh này nhiều năm.',
        textbookQuote:
            'In 2003, Jobs was diagnosed with a rare form of pancreatic cancer. He fought the disease for several years, and stopped working in August, 2011.',
        options: ['A. a serious disease', 'B. a dangerous animal'],
        correctIndex: 0,
        explanation:
            '"cancer" trong y học chỉ bệnh ung thư hiểm nghèo, không phải loài động vật nguy hiểm.',
      ),
      TrialQuestionData(
        id: 'u1_rd_q4',
        word: '4. passed away (SGK trang in 12)',
        targetWord: 'passed away',
        pageLabel: 'Trang in 12',
        contextSentence:
            'He stopped working in August, 2011. Two months later, he passed away.',
        contextTranslation:
            'Ông ngừng làm việc vào tháng 8 năm 2011. Hai tháng sau đó, ông qua đời.',
        textbookQuote:
            'He stopped working in August, 2011. Two months later, he passed away.',
        options: ['A. died', 'B. went past something'],
        correctIndex: 0,
        explanation:
            '"passed away" là lối nói giảm nói tránh trang trọng của từ "died" (qua đời, tạ thế).',
      ),
      TrialQuestionData(
        id: 'u1_rd_q5',
        word: '5. genius (SGK trang in 12)',
        targetWord: 'genius',
        pageLabel: 'Trang in 12',
        contextSentence:
            "On an Apple web page, a statement reads, 'Apple has lost a visionary and creative genius, and the world has lost an amazing human being.'",
        contextTranslation:
            'Trên trang web của Apple có viết: "Apple đã mất đi một thiên tài có tầm nhìn và đầy sáng tạo, và thế giới đã mất đi một con người phi thường."',
        textbookQuote:
            'Apple has lost a visionary and creative genius, and the world has lost an amazing human being.',
        options: ['A. a very intelligent person', 'B. an ordinary person'],
        correctIndex: 0,
        explanation:
            '"genius" chỉ người có trí tuệ hoặc tài năng xuất chúng bẩm sinh (thiên tài).',
      ),
    ],
    vocabulary: {
      'adopted': 'được nhận làm con nuôi',
      'dropped out': 'bỏ học giữa chừng',
      'electronics': 'thiết bị điện tử',
      'garage': 'nhà để xe, ga-ra',
      'accessible': 'dễ tiếp cận, dễ sử dụng',
      'cutting-edge': 'tiên tiến, hiện đại bậc nhất',
      'animation': 'hoạt hình máy tính (Pixar)',
      'cancer': 'bệnh ung thư tuyến tụy',
      'passed away': 'qua đời, mất',
      'genius': 'người xuất chúng, thiên tài',
    },
  );

  // ===========================================================================
  // BÀI HỌC 4: UNIT 4 - URBANISATION OF HA NOI (CHUẨN SGK TRANG IN 52-53)
  // ===========================================================================
  static const TrialLessonData _unit4Lesson = TrialLessonData(
    lessonId: 'trial_unit4_reading',
    unitNumber: 4,
    unitTitle: 'Urbanisation',
    lessonTitle: 'Ha Noi: Then and Now',
    textbookSource:
        'SGK Tiếng Anh 12 Global Success · Unit 4: Urbanisation · Reading (Trang in 52-53)',
    activityName: 'Activity 2: Chọn nghĩa phù hợp với từ in đậm',
    estimatedDuration: 'Ước tính: 5-8 phút',
    paragraphs: [
      LessonParagraph(
        id: 'u4_para_a',
        label: 'Đoạn A: Triển lãm và Hà Nội thế kỷ 20 (SGK trang in 52)',
        text:
            "'Ha Noi Then and Now' exhibition has attracted thousands of visitors this week. The pictures have brought back childhood memories to old residents while helping younger generations see how the city has changed over the years. In the 'Then' hall, visitors can see pictures of 20th-century Ha Noi. Back in 1954, it was a small city with a population of about 530,000 residents in an area of about 152 sq km. The capital's famous Old Quarter or '36 old streets' dates back hundreds of years, with each street focusing on a different trade or craft.",
        translation:
            'Triển lãm "Hà Nội Xưa và Nay" đã thu hút hàng ngàn du khách trong tuần này. Những bức ảnh đã gợi lại ký ức tuổi thơ cho các cư dân lớn tuổi, đồng thời giúp thế hệ trẻ nhìn thấy thành phố đã đổi thay như thế nào qua năm tháng. Trong gian phòng "Xưa", khách tham quan có thể chiêm ngưỡng hình ảnh Hà Nội thế kỷ 20. Trở lại năm 1954, nơi đây là một thành phố nhỏ với dân số khoảng 530.000 cư dân trên diện tích khoảng 152 km vuông. Khu phố cổ nổi tiếng hay "36 phố phường" của thủ đô đã có từ hàng trăm năm trước, mỗi con phố tập trung vào một ngành buôn bán hoặc nghề thủ công khác nhau.',
        keyWords: ['residents', 'exhibition'],
      ),
      LessonParagraph(
        id: 'u4_para_b',
        label: 'Đoạn B: Giao thông và kiến trúc xưa (SGK trang in 52)',
        text:
            "'My parents couldn't afford a motorbike or car. Most residents used to get around by bicycle or on foot,' said an 80-year-old visitor. Trams, which began service in 1901, were a popular means of public transport until 1991. Buses were not very frequent then. People lived and worked in low-rise buildings. The city was a fascinating mixture of French colonial buildings and traditional Eastern architecture.",
        translation:
            '"Bố mẹ tôi hồi đó không đủ tiền mua xe máy hay ô tô. Hầu hết cư dân đều đi lại bằng xe đạp hoặc đi bộ", một cụ ông 80 tuổi chia sẻ. Xe điện (leng keng), bắt đầu hoạt động từ năm 1901, từng là phương tiện giao thông công cộng phổ biến cho đến năm 1991. Xe buýt thời đó cũng không chạy thường xuyên. Mọi người sinh sống và làm việc trong các tòa nhà thấp tầng. Thành phố mang nét pha trộn đầy cuốn hút giữa các công trình kiến trúc thời thuộc địa Pháp và kiến trúc phương Đông truyền thống.',
        keyWords: ['colonial', 'residents'],
      ),
      LessonParagraph(
        id: 'u4_para_c',
        label:
            'Đoạn C: Hà Nội hiện đại và hạ tầng phát triển (SGK trang in 52)',
        text:
            'The \'Now\' pictures show a modern city with a population of over 8 million people. Over the years, the urban area has gradually expanded to over 3,000 sq km including many of the surrounding villages. As rural residents move into Ha Noi, the government is providing more affordable housing. More high-rise buildings have also been built. Ha Noi has improved its transport infrastructure, building new roads and bridges. It is modernising bus services using more electric ones. The Ha Noi Metro opened to the public in 2021 and is expected to include more lines by 2030.',
        translation:
            'Những bức ảnh "Nay" phản ánh một thành phố hiện đại với dân số hơn 8 triệu người. Qua nhiều năm, khu vực đô thị đã dần dần mở rộng lên hơn 3.000 km vuông bao gồm nhiều làng mạc xung quanh. Khi cư dân nông thôn đổ về Hà Nội, chính quyền đang cung cấp thêm nhà ở giá rẻ. Nhiều tòa nhà cao tầng mọc lên. Hà Nội đã cải thiện cơ sở hạ tầng giao thông, xây dựng thêm nhiều tuyến đường và cây cầu mới. Thành phố cũng đang hiện đại hóa dịch vụ xe buýt bằng cách đưa vào nhiều xe buýt điện hơn. Tuyến đường sắt đô thị (Metro) Hà Nội đã khai thác phục vụ người dân từ năm 2021 và dự kiến sẽ mở rộng thêm các tuyến mới vào năm 2030.',
        keyWords: ['gradually', 'modernising', 'infrastructure'],
      ),
      LessonParagraph(
        id: 'u4_para_d',
        label: 'Đoạn D: Thách thức của quá trình đô thị hóa (SGK trang in 52)',
        text:
            "However, urbanisation has created new problems. 'As more people come to seek better job opportunities, the city is getting more and more crowded. This has led to more traffic jams and higher unemployment rates,' said a 21-year-old student. Air pollution is also causing concern among city residents.",
        translation:
            'Tuy nhiên, quá trình đô thị hóa cũng tạo ra những vấn đề mới. "Khi ngày càng nhiều người đến tìm kiếm cơ hội việc làm tốt hơn, thành phố trở nên ngày càng đông đúc. Điều này dẫn đến tình trạng ùn tắc giao thông nhiều hơn và tỷ lệ thất nghiệp cao hơn", một sinh viên 21 tuổi cho biết. Tình trạng ô nhiễm không khí cũng đang gây ra mối quan ngại sâu sắc cho cư dân thành phố.',
        keyWords: ['concern', 'residents'],
      ),
    ],
    questions: [
      TrialQuestionData(
        id: 'u4_rd_q1',
        word: '1. residents (SGK trang in 53)',
        targetWord: 'residents',
        pageLabel: 'Trang in 53',
        contextSentence:
            'The pictures have brought back childhood memories to old residents while helping younger generations see how the city has changed over the years.',
        contextTranslation:
            'Những bức ảnh đã gợi lại kỷ niệm tuổi thơ cho những cư dân lớn tuổi, đồng thời giúp thế hệ trẻ thấy được thành phố đã đổi thay ra sao.',
        textbookQuote:
            'The pictures have brought back childhood memories to old residents...',
        options: [
          'A. people who live in a particular place',
          'B. buildings in a particular place',
        ],
        correctIndex: 0,
        explanation:
            '"residents" là danh từ chỉ những người sinh sống lâu dài tại một địa phương cụ thể (cư dân).',
      ),
      TrialQuestionData(
        id: 'u4_rd_q2',
        word: '2. colonial (SGK trang in 53)',
        targetWord: 'colonial',
        pageLabel: 'Trang in 53',
        contextSentence:
            'The city was a fascinating mixture of French colonial buildings and traditional Eastern architecture.',
        contextTranslation:
            'Thành phố là sự pha trộn thú vị giữa các tòa nhà thời thuộc địa Pháp và kiến trúc truyền thống phương Đông.',
        textbookQuote:
            'The city was a fascinating mixture of French colonial buildings and traditional Eastern architecture.',
        options: [
          'A. connected with the native country',
          'B. connected with a country that controls another country',
        ],
        correctIndex: 1,
        explanation:
            '"colonial" (thuộc địa) liên quan đến một quốc gia ngoại bang thống trị, cai quản một quốc gia khác.',
      ),
      TrialQuestionData(
        id: 'u4_rd_q3',
        word: '3. gradually (SGK trang in 53)',
        targetWord: 'gradually',
        pageLabel: 'Trang in 53',
        contextSentence:
            'Over the years, the urban area has gradually expanded to over 3,000 sq km including many of the surrounding villages.',
        contextTranslation:
            'Qua nhiều năm, vùng đô thị đã dần dần mở rộng lên hơn 3.000 km vuông bao gồm cả các làng lân cận.',
        textbookQuote:
            'Over the years, the urban area has gradually expanded to over 3,000 sq km...',
        options: [
          'A. slowly, over a period of time',
          'B. quickly, over a short time',
        ],
        correctIndex: 0,
        explanation:
            '"gradually" là trạng từ diễn tả sự việc diễn ra từ từ, chậm rãi theo thời gian dài.',
      ),
      TrialQuestionData(
        id: 'u4_rd_q4',
        word: '4. modernising (SGK trang in 53)',
        targetWord: 'modernising',
        pageLabel: 'Trang in 53',
        contextSentence:
            'It is modernising bus services using more electric ones.',
        contextTranslation:
            'Thành phố đang hiện đại hóa các dịch vụ xe buýt bằng cách đưa vào nhiều xe buýt điện hơn.',
        textbookQuote:
            'It is modernising bus services using more electric ones.',
        options: [
          'A. making something attractive',
          'B. making use of the latest technology, design, etc.',
        ],
        correctIndex: 1,
        explanation:
            '"modernising" (hiện đại hóa) nghĩa là áp dụng công nghệ, thiết kế hoặc phương pháp mới nhất.',
      ),
      TrialQuestionData(
        id: 'u4_rd_q5',
        word: '5. concern (SGK trang in 53)',
        targetWord: 'concern',
        pageLabel: 'Trang in 53',
        contextSentence:
            'Air pollution is also causing concern among city residents.',
        contextTranslation:
            'Ô nhiễm không khí cũng đang gây ra mối lo ngại cho người dân thành phố.',
        textbookQuote:
            'Air pollution is also causing concern among city residents.',
        options: [
          'A. a feeling of satisfaction',
          'B. a feeling of worry about something important',
        ],
        correctIndex: 1,
        explanation:
            '"concern" trong ngữ cảnh này mang nghĩa là cảm xúc lo âu, bận tâm về một vấn đề hệ trọng.',
      ),
    ],
    vocabulary: {
      'residents': 'cư dân sinh sống tại địa phương',
      'colonial': 'thuộc thời kỳ thuộc địa',
      'gradually': 'dần dần, từ từ qua thời gian',
      'modernising': 'hiện đại hóa (dùng công nghệ mới)',
      'concern': 'mối lo ngại, sự bận tâm',
      'infrastructure': 'cơ sở hạ tầng đường xá, cầu cống',
      'exhibition': 'triển lãm tranh ảnh',
    },
  );

  // ===========================================================================
  // BÀI HỌC 5: UNIT 5 - JOB ADVERTISEMENTS (CHUẨN SGK TRANG IN 64-65)
  // ===========================================================================
  static const TrialLessonData _unit5Lesson = TrialLessonData(
    lessonId: 'trial_unit5_reading',
    unitNumber: 5,
    unitTitle: 'The World of Work',
    lessonTitle: 'Job Advertisements',
    textbookSource:
        'SGK Tiếng Anh 12 Global Success · Unit 5: The World of Work · Reading (Trang in 64-65)',
    activityName: 'Activity 2: Chọn nghĩa phù hợp với từ in đậm',
    estimatedDuration: 'Ước tính: 5-8 phút',
    paragraphs: [
      LessonParagraph(
        id: 'u5_para_a',
        label:
            'Mục 1 & 2: Tạp chí Công nghệ & Sự kiện Từ thiện (SGK trang in 64)',
        text:
            '1. Tech World Magazine Online is looking to fill two vacancies in its technology section. We want people who understand electronic products and can communicate their opinions clearly. We offer flexible working hours and a bonus based on the number of times people view, share, and comment on your reviews.\n\n2. Heart-to-Heart Organisation is looking for four people to help at charity events. You will be greeting and talking to guests, and sorting donations. You need to be friendly, polite, and willing to work under pressure. This is an unpaid role, but a great opportunity to develop new skills.',
        translation:
            '1. Tạp chí trực tuyến Tech World đang cần tuyển 2 vị trí còn trống trong ban công nghệ. Chúng tôi tìm kiếm những bạn am hiểu thiết bị điện tử và có khả năng diễn đạt nhận định rõ ràng. Chúng tôi mang đến thời gian làm việc linh hoạt cùng tiền thưởng dựa trên số lượt xem, chia sẻ và bình luận cho các bài đánh giá của bạn.\n\n2. Tổ chức Trái Tim Nhân Ái đang tìm kiếm 4 tình nguyện viên hỗ trợ các sự kiện từ thiện. Bạn sẽ đón tiếp, trò chuyện với khách mời và phân loại quà ủng hộ. Bạn cần thân thiện, lịch sự và sẵn sàng chịu được áp lực công việc. Đây là công việc không hưởng lương nhưng là cơ hội quý giá để trau dồi kỹ năng mới.',
        keyWords: ['vacancies', 'flexible', 'reviews'],
      ),
      LessonParagraph(
        id: 'u5_para_b',
        label:
            'Mục 3, 4 & 5: Thời trang, Trợ giảng & Trông trẻ (SGK trang in 64)',
        text:
            "3. TH Fashion: We are looking for hard-working people to join our team, welcoming customers and assisting with sales. No experience is required. On-the-job training is given to all employees. We offer an hourly wage plus overtime pay.\n\n4. Ha Noi School English Department: Part-time vacancies open for classroom assistants. Requirements: Excellent English skills, enthusiastic and well-organised.\n\n5. Babysitter: Are you looking for casual work? We need someone to take care of a two-year-old child every morning from Monday to Friday. Perfect candidate should be responsible and reliable.",
        translation:
            '3. Thời trang TH: Cần tuyển nhân viên chăm chỉ đón khách và hỗ trợ bán hàng. Không yêu cầu kinh nghiệm. Nhân viên sẽ được đào tạo trực tiếp tại chỗ khi làm việc. Mức lương trả theo giờ kèm lương làm thêm giờ.\n\n4. Khoa Tiếng Anh Trường Hà Nội: Tuyển trợ giảng lớp học bán thời gian. Yêu cầu tiếng Anh xuất sắc, nhiệt tình và có tổ chức tốt.\n\n5. Tìm người trông trẻ: Bạn đang tìm công việc thời vụ? Chúng tôi cần một bạn trông bé 2 tuổi vào các buổi sáng từ thứ Hai đến thứ Sáu. Ứng viên cần có trách nhiệm và đáng tin cậy.',
        keyWords: ['on-the-job training', 'casual', 'vacancies'],
      ),
    ],
    questions: [
      TrialQuestionData(
        id: 'u5_rd_q1',
        word: '1. vacancies (SGK trang in 65)',
        targetWord: 'vacancies',
        pageLabel: 'Trang in 65',
        contextSentence:
            'Tech World Magazine Online is looking to fill two vacancies in its technology section.',
        contextTranslation:
            'Tạp chí Tech World đang tìm người để điền vào 2 vị trí còn trống trong ban công nghệ.',
        textbookQuote:
            'Tech World Magazine Online is looking to fill two vacancies in its technology section.',
        options: [
          'A. jobs which are available for someone to do',
          'B. all the jobs in a company',
        ],
        correctIndex: 0,
        explanation:
            '"vacancies" là các vị trí tuyển dụng công việc đang còn trống cần tuyển người vào làm.',
      ),
      TrialQuestionData(
        id: 'u5_rd_q2',
        word: '2. flexible (SGK trang in 65)',
        targetWord: 'flexible',
        pageLabel: 'Trang in 65',
        contextSentence:
            'We offer flexible working hours and a bonus based on the number of times people view, share, and comment on your reviews.',
        contextTranslation:
            'Chúng tôi mang đến giờ làm việc linh hoạt và tiền thưởng theo lượt tương tác bài đánh giá.',
        textbookQuote: 'We offer flexible working hours...',
        options: [
          'A. able to change quickly according to the situation',
          'B. able to stick to the chosen job',
        ],
        correctIndex: 0,
        explanation:
            '"flexible" (linh hoạt) là khả năng thích ứng hoặc thay đổi tùy theo hoàn cảnh thực tế.',
      ),
      TrialQuestionData(
        id: 'u5_rd_q3',
        word: '3. reviews (SGK trang in 65)',
        targetWord: 'reviews',
        pageLabel: 'Trang in 65',
        contextSentence:
            '...a bonus based on the number of times people view, share, and comment on your reviews.',
        contextTranslation:
            '...tiền thưởng dựa trên số lần người dùng xem, chia sẻ và bình luận bài đánh giá của bạn.',
        textbookQuote: '...view, share, and comment on your reviews.',
        options: [
          'A. articles expressing opinions about new products, books, films, etc.',
          'B. the act of reading materials to prepare for an exam',
        ],
        correctIndex: 0,
        explanation:
            '"reviews" ở đây là các bài viết nhận xét, đánh giá chuyên môn về sản phẩm mới.',
      ),
      TrialQuestionData(
        id: 'u5_rd_q4',
        word: '4. on-the-job training (SGK trang in 65)',
        targetWord: 'on-the-job training',
        pageLabel: 'Trang in 65',
        contextSentence:
            'No experience is required. On-the-job training is given to all employees.',
        contextTranslation:
            'Không yêu cầu kinh nghiệm. Đào tạo tại chỗ được cung cấp cho tất cả nhân viên.',
        textbookQuote: 'On-the-job training is given to all employees.',
        options: [
          'A. the work experience you need to get a job',
          'B. teaching employees how to do a job at their workplace',
        ],
        correctIndex: 1,
        explanation:
            '"on-the-job training" là hình thức hướng dẫn, đào tạo nhân viên làm việc ngay tại nơi làm việc thực tế.',
      ),
      TrialQuestionData(
        id: 'u5_rd_q5',
        word: '5. casual (SGK trang in 65)',
        targetWord: 'casual',
        pageLabel: 'Trang in 65',
        contextSentence:
            'Are you looking for casual work? We need someone to take care of a two-year-old child...',
        contextTranslation:
            'Bạn đang tìm kiếm công việc thời vụ? Chúng tôi cần người chăm sóc bé hai tuổi...',
        textbookQuote: 'Are you looking for casual work?',
        options: [
          'A. not regular; for a short period of time',
          'B. permanent; long-term',
        ],
        correctIndex: 0,
        explanation:
            '"casual work" là công việc làm theo thời vụ, không mang tính lâu dài hoặc ký hợp đồng cố định.',
      ),
    ],
    vocabulary: {
      'vacancies': 'vị trí tuyển dụng còn trống',
      'flexible': 'linh hoạt, dễ điều chỉnh',
      'reviews': 'bài nhận xét, đánh giá sản phẩm',
      'on-the-job training': 'đào tạo thực tế tại nơi làm việc',
      'casual': 'công việc thời vụ, không thường xuyên',
    },
  );

  // ===========================================================================
  // BÀI HỌC 6: UNIT 6 - AI IN EDUCATION (CHUẨN SGK TRANG IN 80-81)
  // ===========================================================================
  static const TrialLessonData _unit6Lesson = TrialLessonData(
    lessonId: 'trial_unit6_reading',
    unitNumber: 6,
    unitTitle: 'Artificial Intelligence',
    lessonTitle: 'AI Applications in Education',
    textbookSource:
        'SGK Tiếng Anh 12 Global Success · Unit 6: Artificial Intelligence · Reading (Trang in 80-81)',
    activityName: 'Activity 2: Chọn nghĩa phù hợp với từ in đậm',
    estimatedDuration: 'Ước tính: 5-8 phút',
    paragraphs: [
      LessonParagraph(
        id: 'u6_para_a',
        label: 'Mục A: Hồ sơ năng lực số (Digital Portfolio) (SGK trang in 80)',
        text:
            'A. Digital portfolio: To apply for a university or a job, secondary school students usually need to support their applications with a list of relevant qualifications and work experience. Thanks to AI, they can now effortlessly do that online. A team from two famous universities in Singapore has invented an AI digital portfolio. This app collects data from the learning and working experience that students upload onto the app. Then the data is sorted into sets of skills which students can use for their job or university applications.',
        translation:
            'A. Hồ sơ năng lực số: Để nộp đơn vào đại học hoặc xin việc, học sinh trung học thường cần kèm theo danh sách văn bằng và kinh nghiệm làm việc liên quan. Nhờ có trí tuệ nhân tạo (AI), các bạn hiện có thể làm điều đó trực tuyến một cách dễ dàng. Một nhóm nghiên cứu từ 2 trường đại học danh tiếng tại Singapore đã phát minh ra ứng dụng hồ sơ số AI. Ứng dụng này thu thập dữ liệu về quá trình học tập và làm việc mà học sinh tải lên, sau đó phân loại thành các bộ kỹ năng hữu ích cho hồ sơ ứng tuyển.',
        keyWords: ['portfolio'],
      ),
      LessonParagraph(
        id: 'u6_para_b',
        label:
            'Mục B & C: Chatbot giáo dục & Thực tế ảo (VR) (SGK trang in 80)',
        text:
            "B. Educational chatbots: AI chatbots are being used in many schools and universities around the world. These virtual tutors can explain concepts clearly, answer specific questions, and give feedback on homework.\n\nC. Virtual reality: Schools in Hong Kong are bringing fascinating learning to the classroom through the power of virtual reality (VR). This new way of teaching provides 'hands-on' experiences when studying history or geography, and limits potential dangers of chemistry or physics experiments.",
        translation:
            'B. Chatbot giáo dục: Chatbot AI đang được ứng dụng rộng rãi tại nhiều trường học. Những gia sư ảo này có thể giải thích khái niệm rõ ràng, trả lời câu hỏi và góp ý bài tập về nhà.\n\nC. Thực tế ảo (VR): Các trường tại Hồng Kông đang mang lại trải nghiệm học tập lôi cuốn nhờ công nghệ thực tế ảo. Phương pháp này mang lại trải nghiệm thực hành trực quan khi học lịch sử, địa lý và hạn chế rủi ro trong các thí nghiệm vật lý, hóa học.',
        keyWords: ['virtual', 'hands-on'],
      ),
      LessonParagraph(
        id: 'u6_para_d',
        label: 'Mục D: Nền tảng học tập cá nhân hóa (SGK trang in 80)',
        text:
            'D. Personalised learning: Experts in Israel have created a technology platform to support personalised learning. It collects data from students about what they know and do not know, analyses performances using AI, then offers them suitable assignments. This app has served as the main distance-learning platform for many Israeli secondary school students.',
        translation:
            'D. Học tập cá nhân hóa: Các chuyên gia tại Israel đã tạo ra một nền tảng công nghệ hỗ trợ học tập cá nhân hóa. Hệ thống thu thập dữ liệu về những gì học sinh đã nắm vững hoặc còn hổng, phân tích năng lực bằng AI và đưa ra bài tập phù hợp nhất. Ứng dụng này đóng vai trò là nền tảng học từ xa chủ lực cho hàng ngàn học sinh chuẩn bị các kỳ thi chuyên sâu.',
        keyWords: ['platform'],
      ),
    ],
    questions: [
      TrialQuestionData(
        id: 'u6_rd_q1',
        word: '1. portfolio (SGK trang in 81)',
        targetWord: 'portfolio',
        pageLabel: 'Trang in 81',
        contextSentence:
            'A team from two famous universities in Singapore has invented an AI digital portfolio.',
        contextTranslation:
            'Một nhóm từ hai trường đại học nổi tiếng tại Singapore đã phát minh ra hồ sơ năng lực số AI.',
        textbookQuote:
            'invented an AI digital portfolio. This app collects data from the learning and working experience...',
        options: [
          "A. collection of someone's prizes",
          "B. collection of someone's work such as drawings or documents",
          "C. collection of someone's learning and working experience",
        ],
        correctIndex: 2,
        explanation:
            'Trong bài đọc học đường, "digital portfolio" là tập hợp kinh nghiệm học tập và làm việc của học sinh.',
      ),
      TrialQuestionData(
        id: 'u6_rd_q2',
        word: '2. virtual (SGK trang in 81)',
        targetWord: 'virtual',
        pageLabel: 'Trang in 81',
        contextSentence:
            'These virtual tutors can explain concepts clearly, answer specific questions, and give feedback on homework.',
        contextTranslation:
            'Những gia sư ảo này có thể giải thích khái niệm rõ ràng, trả lời câu hỏi và đưa ra phản hồi về bài tập.',
        textbookQuote: 'These virtual tutors can explain concepts clearly...',
        options: [
          'A. not made of natural things',
          'B. made, done, or seen on the Internet or a computer rather than the real world',
          'C. very similar to the real world but appearing in a different form',
        ],
        correctIndex: 1,
        explanation:
            '"virtual" (ảo) chỉ những thực thể được tạo ra và hoạt động thông qua máy tính hoặc Internet.',
      ),
      TrialQuestionData(
        id: 'u6_rd_q3',
        word: '3. hands-on (SGK trang in 81)',
        targetWord: 'hands-on',
        pageLabel: 'Trang in 81',
        contextSentence:
            "This new way of teaching helps students learn valuable skills, provides 'hands-on' experiences when studying history or geography...",
        contextTranslation:
            'Phương pháp giảng dạy mới này giúp học sinh học các kỹ năng quý báu, mang lại trải nghiệm thực hành trực quan...',
        textbookQuote:
            "provides 'hands-on' experiences when studying history or geography...",
        options: [
          'A. doing something yourself rather than just talking about it',
          'B. asking people to do something',
          'C. doing something by hand',
        ],
        correctIndex: 0,
        explanation:
            '"hands-on" là trải nghiệm thực hành trực tiếp, tự mình bắt tay vào làm thay vì chỉ lý thuyết.',
      ),
      TrialQuestionData(
        id: 'u6_rd_q4',
        word: '4. platform (SGK trang in 81)',
        targetWord: 'platform',
        pageLabel: 'Trang in 81',
        contextSentence:
            'Experts in Israel have created a technology platform to support personalised learning.',
        contextTranslation:
            'Các chuyên gia tại Israel đã tạo ra một nền tảng công nghệ để hỗ trợ học tập cá nhân hóa.',
        textbookQuote:
            'created a technology platform to support personalised learning.',
        options: [
          'A. a floor of a building',
          'B. a kind of computer system or software',
          'C. a working area',
        ],
        correctIndex: 1,
        explanation:
            '"platform" trong công nghệ thông tin là một hệ thống máy tính, phần mềm hoặc nền tảng dịch vụ số.',
      ),
    ],
    vocabulary: {
      'portfolio': 'hồ sơ năng lực ghi nhận kinh nghiệm học tập',
      'virtual': 'ảo, vận hành trên máy tính/Internet',
      'hands-on': 'trải nghiệm thực hành trực tiếp',
      'platform': 'nền tảng công nghệ, phần mềm dịch vụ',
    },
  );

  // ===========================================================================
  // BÀI HỌC 9: UNIT 9 - CAREER PATHS (CHUẨN SGK TRANG IN 120-121)
  // ===========================================================================
  static const TrialLessonData _unit9Lesson = TrialLessonData(
    lessonId: 'trial_unit9_reading',
    unitNumber: 9,
    unitTitle: 'Career Paths',
    lessonTitle: "Career Experts' Advice",
    textbookSource:
        'SGK Tiếng Anh 12 Global Success · Unit 9: Career Paths · Reading (Trang in 120-121)',
    activityName: 'Activity 2: Chọn nghĩa phù hợp với từ in đậm',
    estimatedDuration: 'Ước tính: 5-8 phút',
    paragraphs: [
      LessonParagraph(
        id: 'u9_para_a',
        label: 'Đoạn A: Hiểu bản thân và sở thích (SGK trang in 120)',
        text:
            'A. First, learn about yourself and discover your personality type, beliefs, soft skills, and interests. For example, if you are passionate about working with people and helping them develop, you may consider becoming a social worker or a teacher. If you are interested in languages, history, art, and architecture, you might look at jobs in the tourist industry. Spend time thinking about what you want to do, and list what you are good at. This can help you come up with a career path that matches your personality.',
        translation:
            'A. Trước tiên, hãy thấu hiểu bản thân và khám phá nét tính cách, niềm tin, kỹ năng mềm cũng như sở thích của bạn. Ví dụ, nếu bạn đam mê làm việc với mọi người và giúp họ phát triển, bạn có thể cân nhắc trở thành nhân viên công tác xã hội hoặc giáo viên. Nếu bạn yêu thích ngôn ngữ, lịch sử, nghệ thuật và kiến trúc, bạn có thể tìm kiếm các công việc trong ngành du lịch. Dành thời gian suy ngẫm về những điều bạn muốn làm và liệt kê thế mạnh của mình để định hình con đường sự nghiệp tương xứng.',
        keyWords: ['passionate'],
      ),
      LessonParagraph(
        id: 'u9_para_b',
        label: 'Đoạn B: Yêu cầu bằng cấp và đào tạo (SGK trang in 120)',
        text:
            "B. Next, you should take into account any career qualifications you may need. Many jobs require formal education at a university or college. In order to work as a doctor, for example, you will need to study at medical school for some years of general medical training, followed by several years of specialty training. But there are also jobs that don't require any formal qualifications. You can be hired as a server or a barista in a coffee shop, for instance, and you will be given on-the-job training.",
        translation:
            'B. Tiếp theo, bạn cần cân nhắc kỹ bất kỳ yêu cầu bằng cấp chuyên môn nào cần thiết. Nhiều ngành nghề đòi hỏi giáo dục chính quy tại trường đại học hoặc cao đẳng. Chẳng hạn, để làm bác sĩ, bạn phải học trường y nhiều năm đào tạo tổng quát rồi tiếp tục vài năm đào tạo chuyên khoa sâu. Tuy nhiên cũng có những công việc không bắt buộc bằng cấp chính quy, ví dụ như nhân viên phục vụ bàn hay nhân viên pha chế cà phê, nơi bạn sẽ được đào tạo trực tiếp tại chỗ.',
        keyWords: ['take into account', 'specialty', 'barista'],
      ),
      LessonParagraph(
        id: 'u9_para_c',
        label: 'Đoạn C: Xu hướng tuyển dụng trong tương lai (SGK trang in 120)',
        text:
            'C. You should also consider your chances of being hired. Some fields of work may offer very few positions. With technology developing at a fast pace, some jobs such as cashiers and travel agents may become automated or obsolete. However, other jobs are on the rise. Doctors, nurses, and pharmacists, for instance, are in great demand because of ageing populations and increased life expectancy. That is why before you make a decision, you should carefully examine the opportunities that a career path may provide.',
        translation:
            'C. Bạn cũng nên cân nhắc cơ hội được tuyển dụng thực tế. Một số lĩnh vực có số lượng vị trí tuyển dụng rất hạn chế. Với tốc độ phát triển chóng mặt của công nghệ, một số công việc như thu ngân hay đại lý bán vé du lịch có thể bị tự động hóa hoặc trở nên lỗi thời. Ngược lại, nhiều ngành nghề khác đang gia tăng nhu cầu mạnh mẽ, chẳng hạn bác sĩ, điều dưỡng hay dược sĩ do xu hướng già hóa dân số và tuổi thọ tăng. Do đó, hãy tìm hiểu cặn kẽ triển vọng trước khi đưa ra lựa chọn.',
        keyWords: ['obsolete'],
      ),
    ],
    questions: [
      TrialQuestionData(
        id: 'u9_rd_q1',
        word: '1. passionate (SGK trang in 120)',
        targetWord: 'passionate',
        pageLabel: 'Trang in 120',
        contextSentence:
            'For example, if you are passionate about working with people and helping them develop, you may consider becoming a social worker or a teacher.',
        contextTranslation:
            'Ví dụ, nếu bạn đam mê làm việc với con người và giúp họ phát triển, bạn có thể cân nhắc trở thành nhân viên công tác xã hội hoặc giáo viên.',
        textbookQuote:
            'if you are passionate about working with people and helping them develop...',
        options: [
          'A. having strong feelings of enthusiasm for something',
          'B. showing happiness and excitement about something',
        ],
        correctIndex: 0,
        explanation:
            '"passionate" mang nghĩa có niềm đam mê và nhiệt huyết mãnh liệt với một hoạt động hoặc lĩnh vực.',
      ),
      TrialQuestionData(
        id: 'u9_rd_q2',
        word: '2. take into account (SGK trang in 120)',
        targetWord: 'take into account',
        pageLabel: 'Trang in 120',
        contextSentence:
            'Next, you should take into account any career qualifications you may need.',
        contextTranslation:
            'Tiếp theo, bạn nên cân nhắc bất kỳ bằng cấp nghề nghiệp nào bạn có thể cần.',
        textbookQuote:
            'Next, you should take into account any career qualifications you may need.',
        options: ['A. describe', 'B. consider'],
        correctIndex: 1,
        explanation:
            '"take into account" là thành ngữ đồng nghĩa với "consider" (xem xét, tính đến, cân nhắc kỹ).',
      ),
      TrialQuestionData(
        id: 'u9_rd_q3',
        word: '3. specialty (SGK trang in 120)',
        targetWord: 'specialty',
        pageLabel: 'Trang in 120',
        contextSentence:
            'In order to work as a doctor, for example, you will need to study at medical school for some years of general medical training, followed by several years of specialty training.',
        contextTranslation:
            'Ví dụ, để làm bác sĩ, bạn cần học vài năm y khoa tổng quát tại trường y, sau đó là vài năm đào tạo chuyên khoa.',
        textbookQuote: '...followed by several years of specialty training.',
        options: [
          'A. the subject of study that someone knows a lot about',
          'B. the typical food that a restaurant is famous for',
        ],
        correctIndex: 0,
        explanation:
            'Trong đào tạo nghề nghiệp và y khoa, "specialty" là chuyên khoa, ngành đào tạo chuyên sâu.',
      ),
      TrialQuestionData(
        id: 'u9_rd_q4',
        word: '4. barista (SGK trang in 120)',
        targetWord: 'barista',
        pageLabel: 'Trang in 120',
        contextSentence:
            'You can be hired as a server or a barista in a coffee shop, for instance, and you will be given on-the-job training.',
        contextTranslation:
            'Bạn có thể được tuyển dụng làm nhân viên phục vụ hoặc thợ pha chế tại quán cà phê, và bạn sẽ được đào tạo tại chỗ.',
        textbookQuote:
            'You can be hired as a server or a barista in a coffee shop...',
        options: [
          'A. an owner of a coffee shop',
          'B. a person who serves customers in a coffee shop',
        ],
        correctIndex: 1,
        explanation:
            '"barista" là nhân viên làm việc trong quán cà phê chuyên pha chế và phục vụ đồ uống cho khách hàng.',
      ),
      TrialQuestionData(
        id: 'u9_rd_q5',
        word: '5. obsolete (SGK trang in 120)',
        targetWord: 'obsolete',
        pageLabel: 'Trang in 120',
        contextSentence:
            'With technology developing at a fast pace, some jobs such as cashiers and travel agents may become automated or obsolete.',
        contextTranslation:
            'Với công nghệ phát triển nhanh chóng, một số công việc như thu ngân và đại lý du lịch có thể bị tự động hóa hoặc trở nên lỗi thời.',
        textbookQuote:
            '...some jobs such as cashiers and travel agents may become automated or obsolete.',
        options: ['A. updated', 'B. out of date'],
        correctIndex: 1,
        explanation:
            '"obsolete" mang nghĩa lỗi thời, lạc hậu, không còn phù hợp với xu thế hiện tại (out of date).',
      ),
    ],
    vocabulary: {
      'passionate': 'đam mê, nhiệt huyết mạnh mẽ',
      'take into account': 'xem xét, tính đến, cân nhắc',
      'specialty': 'chuyên môn đào tạo sâu',
      'barista': 'nhân viên pha chế cà phê',
      'obsolete': 'lỗi thời, không còn thịnh hành',
    },
  );

  // ===========================================================================
  // BÀI HỌC 10: UNIT 10 - LIFELONG LEARNING (CHUẨN SGK TRANG IN 132-133)
  // ===========================================================================
  static const TrialLessonData _unit10Lesson = TrialLessonData(
    lessonId: 'trial_unit10_reading',
    unitNumber: 10,
    unitTitle: 'Lifelong Learning',
    lessonTitle: "Head Teacher's Message to School-Leavers",
    textbookSource:
        'SGK Tiếng Anh 12 Global Success · Unit 10: Lifelong Learning · Reading (Trang in 132-133)',
    activityName: 'Activity 2: Chọn nghĩa phù hợp với từ in đậm',
    estimatedDuration: 'Ước tính: 5-8 phút',
    paragraphs: [
      LessonParagraph(
        id: 'u10_para_a',
        label: 'Đoạn A: Lời nhắn gửi & Học tập suốt đời (SGK trang in 132)',
        text:
            "Dear students, In a few weeks' time, you'll complete your secondary education. Some of you may have already made plans for continuing your studies at university or vocational school, while others may wish to start working right away. Whatever choice you make, remember to keep on learning new knowledge and skills. 'Haven't we learnt enough in secondary school?' many may wonder. In fact, learning does not stop after graduation. It is a lifelong process. It involves creating and maintaining a positive attitude to learning for both professional and personal development.",
        translation:
            'Các em học sinh thân mến, chỉ vài tuần nữa thôi, các em sẽ hoàn thành bậc học trung học phổ thông. Một số em có thể đã có kế hoạch học tiếp đại học hoặc trường nghề, trong khi số khác muốn đi làm ngay. Dù các em chọn con đường nào, hãy luôn nhớ không ngừng học hỏi thêm kiến thức và kỹ năng mới. "Chẳng phải chúng ta đã học đủ ở trường phổ thông rồi sao?" - có thể nhiều em sẽ tự hỏi như vậy. Nhưng trên thực tế, việc học không bao giờ dừng lại sau ngày tốt nghiệp. Đó là một quá trình kéo dài cả đời.',
        keyWords: ['wonder', 'lifelong'],
      ),
      LessonParagraph(
        id: 'u10_para_b',
        label: 'Đoạn B: Lợi ích của học tập suốt đời (SGK trang in 132)',
        text:
            'Lifelong learning is especially relevant in today\'s changing world. It allows you to adapt to changes in the modern workplace and widens your employment opportunities. It helps you make better, informed decisions and become a more well-rounded individual. In addition, it keeps your brain healthy and boosts your memory. Lifelong learning also helps you stay connected with modern ideas and meet new people as you participate in various forms of adult education.',
        translation:
            'Học tập suốt đời đặc biệt thiết thực trong thế giới luôn biến chuyển ngày nay. Nó cho phép các em thích ứng với những thay đổi tại nơi làm việc hiện đại và mở rộng cơ hội việc làm. Nó giúp các em đưa ra quyết định sáng suốt hơn và trở thành một cá nhân toàn diện hơn. Thêm vào đó, việc học liên tục giữ cho trí não khỏe mạnh và tăng cường trí nhớ, đồng thời giúp các em gắn kết với những tư tưởng mới.',
        keyWords: ['relevant', 'widens'],
      ),
      LessonParagraph(
        id: 'u10_para_c',
        label: 'Đoạn C: Bác Hồ - Tấm gương học tập suốt đời (SGK trang in 132)',
        text:
            'Uncle Ho is a great role model for lifelong learning. He never stopped learning throughout his life despite all the hardships and challenges. He learnt to speak different languages, including English, French, Russian, Italian, German, and Chinese mainly by himself. He even wrote poems in Chinese when he was imprisoned in China to keep his mind sharp. He took regular physical exercise, did traditional martial arts, and enjoyed activities such as swimming and mountain climbing throughout his life. We can all learn from Uncle Ho\'s lifelong efforts to improve himself.',
        translation:
            'Bác Hồ là một tấm gương vĩ đại về tinh thần học tập suốt đời. Người chưa từng ngừng học trong suốt cuộc đời dù trải qua bao gian khổ và thử thách. Người đã tự học và thông thạo nhiều ngôn ngữ như tiếng Anh, Pháp, Nga, Ý, Đức và Trung Quốc. Người thậm chí còn viết thơ chữ Hán trong những ngày bị giam cầm tại Trung Quốc để giữ cho trí tuệ luôn minh mẫn. Người cũng rèn luyện thân thể đều đặn, tập võ cổ truyền và yêu thích bơi lội, leo núi suốt cuộc đời. Tất cả chúng ta đều có thể học tập từ nỗ lực tự hoàn thiện không ngừng của Bác.',
        keyWords: ['hardships', 'imprisoned'],
      ),
    ],
    questions: [
      TrialQuestionData(
        id: 'u10_rd_q1',
        word: '1. wonder (SGK trang in 132)',
        targetWord: 'wonder',
        pageLabel: 'Trang in 132',
        contextSentence:
            "'Haven't we learnt enough in secondary school?' many may wonder.",
        contextTranslation:
            '"Chẳng phải chúng ta đã học đủ ở trường phổ thông rồi sao?" nhiều người có thể băn khoăn.',
        textbookQuote:
            "'Haven't we learnt enough in secondary school?' many may wonder.",
        options: [
          'A. to think about something and try to guess what is true or will happen',
          'B. to walk slowly around an area without a clear purpose',
        ],
        correctIndex: 0,
        explanation:
            '"wonder" nghĩa là băn khoăn, trăn trở và suy nghĩ tìm hiểu về một điều gì đó.',
      ),
      TrialQuestionData(
        id: 'u10_rd_q2',
        word: '2. relevant (SGK trang in 133)',
        targetWord: 'relevant',
        pageLabel: 'Trang in 133',
        contextSentence:
            "Lifelong learning is especially relevant in today's changing world.",
        contextTranslation:
            'Học tập suốt đời đặc biệt thích hợp và thiết thực trong thế giới thay đổi ngày nay.',
        textbookQuote:
            "Lifelong learning is especially relevant in today's changing world.",
        options: ['A. relatively close', 'B. valuable and useful'],
        correctIndex: 1,
        explanation:
            '"relevant" diễn tả điều có giá trị thiết thực và hữu ích (valuable and useful) đối với tình huống thực tế.',
      ),
      TrialQuestionData(
        id: 'u10_rd_q3',
        word: '3. widens (SGK trang in 133)',
        targetWord: 'widens',
        pageLabel: 'Trang in 133',
        contextSentence:
            'It allows you to adapt to changes in the modern workplace and widens your employment opportunities.',
        contextTranslation:
            'Nó cho phép bạn thích nghi với các thay đổi tại nơi làm việc và mở rộng cơ hội việc làm.',
        textbookQuote: 'widens your employment opportunities.',
        options: [
          'A. makes something larger in degree or range',
          'B. makes something smaller in degree or range',
        ],
        correctIndex: 0,
        explanation:
            '"widens" mang nghĩa làm gia tăng về mức độ hoặc mở rộng phạm vi của điều gì đó.',
      ),
      TrialQuestionData(
        id: 'u10_rd_q4',
        word: '4. hardships (SGK trang in 133)',
        targetWord: 'hardships',
        pageLabel: 'Trang in 133',
        contextSentence:
            'He never stopped learning throughout his life despite all the hardships and challenges.',
        contextTranslation:
            'Bác chưa bao giờ ngừng học hỏi suốt cuộc đời dù trải qua mọi gian lao và thử thách.',
        textbookQuote: 'despite all the hardships and challenges.',
        options: [
          'A. large boats that are hard to operate',
          'B. conditions of life that cause difficulty and suffering',
        ],
        correctIndex: 1,
        explanation:
            '"hardships" là những hoàn cảnh sống khó khăn, gian nan và thử thách gây ra nhiều vất vả.',
      ),
      TrialQuestionData(
        id: 'u10_rd_q5',
        word: '5. imprisoned (SGK trang in 133)',
        targetWord: 'imprisoned',
        pageLabel: 'Trang in 133',
        contextSentence:
            'He even wrote poems in Chinese when he was imprisoned in China to keep his mind sharp.',
        contextTranslation:
            'Bác thậm chí còn viết các bài thơ bằng chữ Hán khi bị giam cầm tại Trung Quốc để giữ cho trí óc minh mẫn.',
        textbookQuote:
            'when he was imprisoned in China to keep his mind sharp.',
        options: ['A. released from a prison', 'B. put in a prison'],
        correctIndex: 1,
        explanation:
            '"imprisoned" là bị bắt giữ và giam giữ trong nhà tù (put in a prison).',
      ),
    ],
    vocabulary: {
      'wonder': 'tự hỏi, băn khoăn',
      'relevant': 'thích đáng, thiết thực và hữu ích',
      'widens': 'mở rộng phạm vi cơ hội',
      'hardships': 'gian khổ, thử thách khắc nghiệt',
      'imprisoned': 'bị giam cầm trong tù',
    },
  );

  // ===========================================================================
  // BÀI HỌC 2: UNIT 2 - GLOBALISATION ON CULTURAL DIVERSITY (SGK TRANG IN 23-24)
  // ===========================================================================
  static const TrialLessonData _unit2Lesson = TrialLessonData(
    lessonId: 'trial_unit2_reading',
    unitNumber: 2,
    unitTitle: 'A Multicultural World',
    lessonTitle: 'The Effects of Globalisation on Cultural Diversity',
    textbookSource:
        'SGK Tiếng Anh 12 Global Success · Unit 2: A Multicultural World · Reading (Trang in 23-24)',
    activityName: 'Activity 2 & 3: Đọc hiểu và Ghép tiêu đề đoạn văn',
    estimatedDuration: 'Ước tính: 6-8 phút',
    isReady: true,
    paragraphs: [
      LessonParagraph(
        id: 'u2_para_intro',
        label: 'Mở đầu: Toàn cầu hóa và văn hóa (SGK trang in 24)',
        text:
            "As a result of globalisation, the world is becoming more and more connected. This has changed people's way of life, beliefs, art and customs, or their culture, in many respects. Although people's experiences around the world have become very similar, globalisation has also encouraged cultural diversity. Below are some examples.",
        translation:
            'Do kết quả của toàn cầu hóa, thế giới ngày càng trở nên kết nối hơn. Điều này đã thay đổi lối sống, niềm tin, nghệ thuật và phong tục tập quán, hay nói cách khác là văn hóa của con người, trên nhiều phương diện. Mặc dù trải nghiệm của con người trên khắp thế giới đã trở nên rất tương đồng, toàn cầu hóa cũng khuyến khích sự đa dạng văn hóa. Dưới đây là một số ví dụ.',
        keyWords: ['globalisation', 'customs', 'diversity'],
      ),
      LessonParagraph(
        id: 'u2_para_a',
        label: 'Đoạn A: Sự đa dạng của các nền ẩm thực (SGK trang in 24)',
        text:
            'Fast food chains and international restaurants have become popular, offering a wide range of dishes and more food choices to local people. For example, here in Viet Nam, we can enjoy Italian pizza or Japanese sushi, in addition to our traditional food. Moreover, some international dishes use local ingredients, which make them unique and more suitable to local tastes. On the other hand, Vietnamese specialities, such as pho and banh mi, are also gaining popularity worldwide.',
        translation:
            'Các chuỗi thức ăn nhanh và nhà hàng quốc tế đã trở nên phổ biến, mang đến nhiều món ăn phong phú và nhiều lựa chọn ẩm thực hơn cho người dân địa phương. Ví dụ, ngay tại Việt Nam, chúng ta có thể thưởng thức bánh pizza của Ý hay sushi của Nhật Bản bên cạnh các món ăn truyền thống. Hơn nữa, một số món ăn quốc tế sử dụng các nguyên liệu địa phương, làm cho chúng trở nên độc đáo và phù hợp hơn với khẩu vị bản địa. Mặt khác, những nét đặc sản của Việt Nam như phở và bánh mì cũng đang ngày càng được ưa chuộng rộng rãi trên toàn thế giới.',
        keyWords: ['chains', 'dishes', 'ingredients', 'specialities'],
      ),
      LessonParagraph(
        id: 'u2_para_b',
        label: 'Đoạn B: Âm nhạc không biên giới (SGK trang in 24)',
        text:
            "Thanks to globalisation, people can quickly discover new music from all over the world. People nowadays enjoy listening to music from different countries and cultures, and in different languages. For example, American teens are captivated by K-pop music and dance. There are also many music festivals around the globe that bring artists and music fans together. In today's connected world, it is very common for musicians across the world to work on music projects and share ideas together.",
        translation:
            'Nhờ toàn cầu hóa, con người có thể nhanh chóng khám phá âm nhạc mới từ khắp nơi trên thế giới. Ngày nay mọi người thích nghe nhạc từ các quốc gia và nền văn hóa khác nhau, bằng các ngôn ngữ khác nhau. Ví dụ, thanh thiếu niên Mỹ bị cuốn hút mạnh mẽ bởi âm nhạc và vũ đạo K-pop. Cũng có rất nhiều lễ hội âm nhạc trên toàn cầu quy tụ nghệ sĩ và người hâm mộ âm nhạc lại với nhau. Trong thế giới kết nối ngày nay, việc các nhạc sĩ trên khắp thế giới cùng hợp tác trong các dự án âm nhạc và chia sẻ ý tưởng là điều rất phổ biến.',
        keyWords: ['discover', 'captivated', 'festivals', 'musicians'],
      ),
      LessonParagraph(
        id: 'u2_para_c',
        label: 'Đoạn C: Giao thoa phong cách thời trang (SGK trang in 24)',
        text:
            'Globalisation has also impacted fashion by opening it up to a variety of styles and influences from around the world. Cross-cultural styles that blend both traditional and modern elements are on the rise. This presents opportunities for fashion designers to be creative and reflect the cultural richness of the world. It is now easier for people to keep up with fashion trends from different cultures and regions, and express their identities in new and exciting ways. In conclusion, globalisation has helped strengthen cultural diversity in the world and made people appreciate different cultures and lifestyles.',
        translation:
            'Toàn cầu hóa cũng đã tác động đến thời trang bằng cách mở ra vô vàn phong cách và ảnh hưởng từ khắp nơi trên thế giới. Các phong cách giao thoa văn hóa pha trộn cả các yếu tố truyền thống và hiện đại đang ngày càng gia tăng. Điều này mang lại cơ hội cho các nhà thiết kế thời trang sáng tạo và phản ánh sự phong phú về mặt văn hóa của thế giới. Giờ đây mọi người dễ dàng bắt kịp các xu hướng thời trang từ các nền văn hóa và khu vực khác nhau, đồng thời thể hiện bản sắc của mình theo những cách mới mẻ và thú vị. Tóm lại, toàn cầu hóa đã giúp củng cố sự đa dạng văn hóa trên thế giới và khiến con người trân trọng hơn những nền văn hóa và lối sống khác nhau.',
        keyWords: ['blend', 'identities', 'appreciate'],
      ),
    ],
    questions: [
      TrialQuestionData(
        id: 'u2_rd_q1',
        word: '1. Tiêu đề phù hợp nhất cho Đoạn A (SGK trang in 23-24)',
        targetWord: 'Variety of cuisines',
        pageLabel: 'Trang in 23-24',
        contextSentence:
            'Fast food chains and international restaurants have become popular, offering a wide range of dishes and more food choices to local people... here in Viet Nam, we can enjoy Italian pizza or Japanese sushi...',
        contextTranslation:
            'Các chuỗi thức ăn nhanh và nhà hàng quốc tế trở nên phổ biến, đem đến nhiều món ăn và lựa chọn ẩm thực cho người dân địa phương...',
        textbookQuote:
            'Fast food chains and international restaurants have become popular, offering a wide range of dishes and more food choices to local people.',
        options: [
          'A. Discovering K-pop music',
          'B. Blending fashion styles',
          'C. Fast food popularity',
          'D. Variety of cuisines',
        ],
        correctIndex: 3,
        explanation:
            'Đoạn A bàn về sự phong phú của các nền ẩm thực quốc tế tại địa phương và đặc sản Việt Nam lan tỏa ra thế giới, nên tiêu đề đúng nhất là "Variety of cuisines" (Sự đa dạng của các nền ẩm thực). Phương án C quá hẹp vì đoạn văn còn nhắc tới sushi, phở, bánh mì.',
      ),
      TrialQuestionData(
        id: 'u2_rd_q2',
        word: '2. Tiêu đề phù hợp nhất cho Đoạn B (SGK trang in 23-24)',
        targetWord: 'No borders for music',
        pageLabel: 'Trang in 23-24',
        contextSentence:
            "Thanks to globalisation, people can quickly discover new music from all over the world... In today's connected world, it is very common for musicians across the world to work on music projects and share ideas together.",
        contextTranslation:
            'Nhờ toàn cầu hóa, mọi người có thể nhanh chóng khám phá âm nhạc từ khắp nơi trên thế giới... các nhạc sĩ khắp thế giới cùng hợp tác dự án âm nhạc.',
        textbookQuote:
            'Thanks to globalisation, people can quickly discover new music from all over the world.',
        options: [
          'A. No borders for music',
          'B. Discovering K-pop music',
          'C. Variety of cuisines',
          'D. Fast food popularity',
        ],
        correctIndex: 0,
        explanation:
            'Đoạn B nói về việc âm nhạc lan tỏa khắp toàn cầu, con người nghe nhạc từ nhiều quốc gia và nghệ sĩ khắp nơi hợp tác với nhau, thể hiện ý "No borders for music" (Âm nhạc không biên giới). Phương án B chỉ là ví dụ minh họa nhỏ.',
      ),
      TrialQuestionData(
        id: 'u2_rd_q3',
        word: '3. Tiêu đề phù hợp nhất cho Đoạn C (SGK trang in 23-24)',
        targetWord: 'Blending fashion styles',
        pageLabel: 'Trang in 23-24',
        contextSentence:
            'Cross-cultural styles that blend both traditional and modern elements are on the rise. This presents opportunities for fashion designers to be creative and reflect the cultural richness of the world.',
        contextTranslation:
            'Các phong cách giao thoa văn hóa kết hợp cả yếu tố truyền thống và hiện đại đang ngày càng phát triển. Điều này mang lại cơ hội cho các nhà thiết kế thời trang sáng tạo.',
        textbookQuote:
            'Cross-cultural styles that blend both traditional and modern elements are on the rise.',
        options: [
          'A. Fast food popularity',
          'B. Blending fashion styles',
          'C. No borders for music',
          'D. Discovering K-pop music',
        ],
        correctIndex: 1,
        explanation:
            'Đoạn C tập trung vào ảnh hưởng của toàn cầu hóa tới thời trang, đặc biệt là xu hướng "blend both traditional and modern elements" (pha trộn phong cách thời trang truyền thống và hiện đại), do đó tiêu đề chính xác là "Blending fashion styles".',
      ),
      TrialQuestionData(
        id: 'u2_rd_q4',
        word: "4. How has globalisation affected people's eating habits? (SGK trang in 24)",
        targetWord: 'eating habits',
        pageLabel: 'Trang in 24',
        contextSentence:
            'Fast food chains and international restaurants have become popular, offering a wide range of dishes and more food choices to local people. For example, here in Viet Nam, we can enjoy Italian pizza or Japanese sushi...',
        contextTranslation:
            'Các chuỗi thức ăn nhanh và nhà hàng quốc tế đã trở nên phổ biến, đem đến nhiều món ăn và lựa chọn ẩm thực cho người dân địa phương. Ví dụ ở Việt Nam, chúng ta có thể thưởng thức pizza Ý hay sushi Nhật...',
        textbookQuote:
            'Fast food chains and international restaurants have become popular, offering a wide range of dishes and more food choices to local people.',
        options: [
          'A. It has decreased the popularity of traditional food.',
          'B. It has limited people\'s food choices to local dishes.',
          'C. Local people are trying new cuisines.',
        ],
        correctIndex: 2,
        explanation:
            'Trong đoạn A, bài đọc nêu rõ người dân địa phương được thưởng thức thêm nhiều món ăn quốc tế mới như pizza Ý hay sushi Nhật bên cạnh thức ăn truyền thống, tức là người dân địa phương đang thử những nền ẩm thực mới (Local people are trying new cuisines).',
      ),
      TrialQuestionData(
        id: 'u2_rd_q5',
        word: '5. Which of the following is NOT mentioned as something that local people can try in Viet Nam? (SGK trang in 24)',
        targetWord: 'NOT mentioned',
        pageLabel: 'Trang in 24',
        contextSentence:
            'Moreover, some international dishes use local ingredients, which make them unique and more suitable to local tastes.',
        contextTranslation:
            'Hơn nữa, một số món quốc tế dùng nguyên liệu địa phương giúp chúng độc đáo và hợp khẩu vị bản xứ.',
        textbookQuote:
            'Moreover, some international dishes use local ingredients, which make them unique and more suitable to local tastes.',
        options: [
          'A. Dishes from other cultures using ingredients grown in Viet Nam.',
          'B. Traditional dishes using international ingredients.',
          'C. A Japanese dish of cooked rice and raw fish.',
        ],
        correctIndex: 1,
        explanation:
            'Bài đọc chỉ đề cập đến món ăn quốc tế sử dụng nguyên liệu địa phương Việt Nam ("international dishes use local ingredients"), chứ KHÔNG hề nhắc đến món ăn truyền thống dùng nguyên liệu quốc tế ("traditional dishes using international ingredients").',
      ),
      TrialQuestionData(
        id: 'u2_rd_q6',
        word: '6. What can be inferred from the passage about music? (SGK trang in 24)',
        targetWord: 'inferred about music',
        pageLabel: 'Trang in 24',
        contextSentence:
            "There are also many music festivals around the globe that bring artists and music fans together. In today's connected world, it is very common for musicians across the world to work on music projects and share ideas together.",
        contextTranslation:
            'Có nhiều lễ hội âm nhạc trên khắp thế giới kết nối các nghệ sĩ và người hâm mộ. Trong thế giới kết nối ngày nay, việc các nhạc sĩ trên thế giới cùng làm việc trong các dự án âm nhạc và chia sẻ ý tưởng là rất phổ biến.',
        textbookQuote:
            "In today's connected world, it is very common for musicians across the world to work on music projects and share ideas together.",
        options: [
          'A. Music has connected people across cultures.',
          'B. Teens around the world love listening to K-pop music.',
          'C. It is easier to organise music festivals.',
        ],
        correctIndex: 0,
        explanation:
            'Từ việc giới trẻ thích nghe nhạc từ các nền văn hóa khác nhau, các lễ hội gắn kết người hâm mộ và nhạc sĩ toàn cầu hợp tác, có thể suy ra âm nhạc đã kết nối con người xuyên suốt các nền văn hóa ("Music has connected people across cultures").',
      ),
    ],
    vocabulary: {
      'globalisation': 'sự toàn cầu hóa',
      'diversity': 'sự phong phú, đa dạng văn hóa',
      'customs': 'phong tục tập quán',
      'chains': 'chuỗi nhà hàng, chuỗi cửa hàng',
      'dishes': 'các món ăn',
      'ingredients': 'các nguyên liệu nấu ăn',
      'specialities': 'các món đặc sản địa phương',
      'discover': 'khám phá, tìm hiểu điều mới',
      'captivated': 'bị lôi cuốn, mê hoặc sâu sắc',
      'festivals': 'các lễ hội âm nhạc / văn hóa',
      'musicians': 'các nhạc sĩ, nghệ sĩ âm nhạc',
      'blend': 'pha trộn, kết hợp hài hòa',
      'identities': 'các nét bản sắc riêng biệt',
      'appreciate': 'trân trọng, đánh giá cao',
    },
  );

  // ===========================================================================
  // BÀI HỌC 3: UNIT 3 - GO GREEN WITH PLASTICS! (SGK TRANG IN 35-37)
  // ===========================================================================
  static const TrialLessonData _unit3Lesson = TrialLessonData(
    lessonId: 'trial_unit3_reading',
    unitNumber: 3,
    unitTitle: 'Green Living',
    lessonTitle: 'Go Green with Plastics!',
    textbookSource:
        'SGK Tiếng Anh 12 Global Success · Unit 3: Green Living · Reading (Trang in 35-37)',
    activityName: 'Activity 2 & 4: Từ vựng và Đọc hiểu lời khuyên sống xanh',
    estimatedDuration: 'Ước tính: 6-8 phút',
    isReady: true,
    paragraphs: [
      LessonParagraph(
        id: 'u3_para_intro',
        label: 'Mở đầu: Vấn nạn rác thải nhựa (SGK trang in 36)',
        text:
            'Plastic has become very common in our daily life; however, most plastic items take up to 1,000 years to decompose in landfills. Can we enjoy the convenience of plastics and a greener world at the same time? Our readers have sent us many emails with useful tips this week.',
        translation:
            'Đồ nhựa đã trở nên rất phổ biến trong cuộc sống hàng ngày của chúng ta; tuy nhiên, hầu hết các vật dụng bằng nhựa phải mất tới 1.000 năm để phân hủy tại các bãi chôn lấp rác. Liệu chúng ta có thể vừa tận hưởng sự tiện lợi của đồ nhựa vừa có một thế giới xanh hơn cùng một lúc không? Độc giả của chúng tôi đã gửi rất nhiều email chia sẻ những mẹo hữu ích trong tuần này.',
        keyWords: ['decompose', 'landfills', 'convenience'],
      ),
      LessonParagraph(
        id: 'u3_para_hai',
        label: 'Lời khuyên từ Hải (18 tuổi): Giảm bao bì nhựa (SGK trang in 36)',
        text:
            'I try to use fewer plastic bags when shopping. The supermarket near my house even provides cardboard boxes, so I can pack my groceries and get rid of plastic packaging! When I must use plastic bags, I try to reuse them again and again instead of throwing them away after a single use. (Hai, 18)',
        translation:
            'Tôi cố gắng sử dụng ít túi nhựa hơn khi đi mua sắm. Siêu thị gần nhà tôi thậm chí còn cung cấp các thùng các-tông, để tôi có thể đóng gói hàng tạp hóa của mình và loại bỏ bao bì nhựa! Khi bắt buộc phải dùng túi nhựa, tôi cố gắng tái sử dụng chúng nhiều lần thay vì vứt bỏ sau một lần sử dụng. (Hải, 18 tuổi)',
        keyWords: ['cardboard boxes', 'packaging', 'groceries'],
      ),
      LessonParagraph(
        id: 'u3_para_phuong',
        label: 'Lời khuyên từ Phương (16 tuổi): Bình nước tái sử dụng (SGK trang in 36)',
        text:
            'I know how convenient it is to buy a bottle of water from a vending machine or a supermarket; however, I always bring my reusable water bottle. All I have to remember is to fill my bottle before going to school, and then use the water filling stations or drinking fountains at school. (Phuong, 16)',
        translation:
            'Tôi biết việc mua một chai nước từ máy bán hàng tự động hay siêu thị tiện lợi như thế nào; tuy nhiên, tôi luôn mang theo bình nước có thể tái sử dụng của mình. Tất cả những gì tôi cần nhớ là đổ đầy bình trước khi đến trường, và sau đó sử dụng các trạm tiếp nước hoặc vòi nước uống tại trường. (Phương, 16 tuổi)',
        keyWords: ['reusable', 'fountains'],
      ),
      LessonParagraph(
        id: 'u3_para_hoang',
        label: 'Lời khuyên từ Hoàng (15 tuổi): Tái sử dụng hộp đựng thức ăn (SGK trang in 36)',
        text:
            'I always reuse plastic takeaway containers. I use them to store portions of cooked food and keep leftovers in the fridge, which is also better for the environment. (Hoang, 15)',
        translation:
            'Tôi luôn tái sử dụng các hộp nhựa đựng đồ ăn mang về. Tôi dùng chúng để cất các phần thức ăn đã nấu chín và lưu trữ thức ăn thừa trong tủ lạnh, điều này cũng tốt hơn cho môi trường. (Hoàng, 15 tuổi)',
        keyWords: ['takeaway containers', 'leftovers'],
      ),
      LessonParagraph(
        id: 'u3_para_ha',
        label: 'Lời khuyên từ Hà (16 tuổi): Phân loại theo mã số nhựa (SGK trang in 36)',
        text:
            "I have learnt that most plastic containers have numbers at the bottom to show the type of plastic they're made of. So when you recycle a bottle, for instance, remove the cap because a bottle often has number 1 on it while the cap often has number 5. Numbers 1 and 2 are the most widely accepted plastics for recycling. (Ha, 16)",
        translation:
            'Tôi đã học được rằng hầu hết các đồ chứa bằng nhựa đều có các con số ở dưới đáy để biểu thị loại nhựa tạo nên chúng. Vì vậy, chẳng hạn khi bạn tái chế một chiếc chai, hãy tháo nắp ra vì thân chai thường mang số 1 trong khi nắp thường mang số 5. Nhựa số 1 và số 2 là những loại nhựa được chấp nhận rộng rãi nhất để tái chế. (Hà, 16 tuổi)',
        keyWords: ['containers', 'remove the cap'],
      ),
      LessonParagraph(
        id: 'u3_para_binh',
        label: 'Lời khuyên từ Bình (17 tuổi): Tráng sạch trước khi tái chế (SGK trang in 36)',
        text:
            'When I started recycling, I made the mistake of putting some plastic takeaway containers with some leftover food into the recycling bin. The next day, the whole bin was contaminated, so all the recyclables were taken to the landfill instead. So now I always rinse out containers before recycling them. (Binh, 17)',
        translation:
            'Khi mới bắt đầu tái chế, tôi đã mắc sai lầm là bỏ một số hộp nhựa mang về còn dính thức ăn thừa vào thùng tái chế. Ngày hôm sau, toàn bộ thùng tái chế đã bị nhiễm bẩn, vì vậy tất cả rác tái chế đã bị chuyển đến bãi chôn lấp rác. Vì vậy, bây giờ tôi luôn tráng sạch các hộp đựng trước khi mang chúng đi tái chế. (Bình, 17 tuổi)',
        keyWords: ['contaminated', 'recyclables', 'rinse out'],
      ),
    ],
    questions: [
      TrialQuestionData(
        id: 'u3_rd_q1',
        word: '1. cardboard boxes (SGK trang in 36)',
        targetWord: 'cardboard boxes',
        pageLabel: 'Trang in 36',
        contextSentence:
            'The supermarket near my house even provides cardboard boxes, so I can pack my groceries and get rid of plastic packaging!',
        contextTranslation:
            'Siêu thị gần nhà tôi cung cấp thùng các-tông để tôi gói hàng tạp hóa và loại bỏ bao bì nhựa!',
        textbookQuote:
            'The supermarket near my house even provides cardboard boxes, so I can pack my groceries and get rid of plastic packaging!',
        options: [
          'A. boxes made of thick paper, used for packing goods',
          'B. small plastic bags used in supermarkets',
          'C. metal containers for keeping liquids',
          'D. wooden boxes for storing fresh fruits',
        ],
        correctIndex: 0,
        explanation:
            '"cardboard boxes" là thùng các-tông / hộp bìa cứng được làm từ giấy dày để đóng gói hàng hóa thay vì dùng túi ni-lông.',
      ),
      TrialQuestionData(
        id: 'u3_rd_q2',
        word: '2. leftovers (SGK trang in 36)',
        targetWord: 'leftovers',
        pageLabel: 'Trang in 36',
        contextSentence:
            'I always reuse plastic takeaway containers. I use them to store portions of cooked food and keep leftovers in the fridge...',
        contextTranslation:
            'Tôi luôn tái sử dụng hộp nhựa mang về để chia phần thức ăn đã nấu và giữ đồ ăn thừa trong tủ lạnh...',
        textbookQuote:
            'I use them to store portions of cooked food and keep leftovers in the fridge, which is also better for the environment.',
        options: [
          'A. freshly cooked meals bought from restaurants',
          'B. food remaining uneaten at the end of a meal',
          'C. uncooked raw ingredients kept in the freezer',
          'D. organic waste that must be thrown away immediately',
        ],
        correctIndex: 1,
        explanation:
            '"leftovers" là phần thức ăn thừa còn lại sau bữa ăn chưa ăn hết, có thể cất trong tủ lạnh để ăn tiếp bữa sau nhằm tránh lãng phí.',
      ),
      TrialQuestionData(
        id: 'u3_rd_q3',
        word: '3. contaminated (SGK trang in 36)',
        targetWord: 'contaminated',
        pageLabel: 'Trang in 36',
        contextSentence:
            'When I started recycling, I made the mistake of putting some plastic takeaway containers with some leftover food into the recycling bin. The next day, the whole bin was contaminated...',
        contextTranslation:
            'Tôi đã mắc sai lầm khi bỏ hộp nhựa dính thức ăn thừa vào thùng tái chế. Hôm sau, cả thùng rác đã bị nhiễm bẩn...',
        textbookQuote:
            'The next day, the whole bin was contaminated, so all the recyclables were taken to the landfill instead.',
        options: [
          'A. cleaned and washed carefully',
          'B. made dirty or harmful by adding unwanted substances',
          'C. emptied and ready for new waste',
          'D. sorted correctly according to plastic codes',
        ],
        correctIndex: 1,
        explanation:
            '"contaminated" mang nghĩa bị làm bẩn, nhiễm khuẩn hoặc nhiễm tạp chất độc hại khiến các đồ có thể tái chế bị hỏng và phải mang đi chôn lấp.',
      ),
      TrialQuestionData(
        id: 'u3_rd_q4',
        word: '4. rinse out (SGK trang in 36)',
        targetWord: 'rinse out',
        pageLabel: 'Trang in 36',
        contextSentence:
            'So now I always rinse out containers before recycling them.',
        contextTranslation:
            'Vì vậy bây giờ tôi luôn tráng sạch hộp đựng trước khi mang chúng đi tái chế.',
        textbookQuote:
            'So now I always rinse out containers before recycling them.',
        options: [
          'A. clean something quickly with water',
          'B. break something into small pieces',
          'C. throw something away into landfills',
          'D. paint numbers at the bottom of containers',
        ],
        correctIndex: 0,
        explanation:
            '"rinse out" là tráng sơ qua hoặc súc rửa bằng nước sạch để loại bỏ cặn bẩn bám dính bên trong đồ chứa.',
      ),
      TrialQuestionData(
        id: 'u3_rd_q5',
        word: '5. Which person has learnt from a past mistake how to recycle things properly? (SGK trang in 37)',
        targetWord: 'learnt from a past mistake',
        pageLabel: 'Trang in 37',
        contextSentence:
            'When I started recycling, I made the mistake of putting some plastic takeaway containers with some leftover food into the recycling bin... So now I always rinse out containers before recycling them.',
        contextTranslation:
            'Bình đã phạm sai lầm khi bỏ hộp dính thức ăn vào thùng tái chế làm hỏng cả thùng rác. Giờ đây Bình luôn tráng sạch trước khi bỏ vào.',
        textbookQuote:
            'When I started recycling, I made the mistake of putting some plastic takeaway containers with some leftover food into the recycling bin.',
        options: [
          'A. Hai',
          'B. Phuong',
          'C. Hoang',
          'D. Binh',
        ],
        correctIndex: 3,
        explanation:
            'Theo bài đọc của Bình (17 tuổi): "I made the mistake of putting some plastic takeaway containers with some leftover food into the recycling bin... So now I always rinse out containers", Bình đã rút ra bài học kinh nghiệm từ sai lầm trong quá khứ.',
      ),
      TrialQuestionData(
        id: 'u3_rd_q6',
        word: '6. Which person\'s green habit depends on drinking water facilities at school? (SGK trang in 37)',
        targetWord: 'drinking water facilities',
        pageLabel: 'Trang in 37',
        contextSentence:
            'All I have to remember is to fill my bottle before going to school, and then use the water filling stations or drinking fountains at school. (Phuong, 16)',
        contextTranslation:
            'Tất cả những gì tôi cần nhớ là châm đầy bình trước khi đi học, rồi dùng trạm rót nước hoặc vòi nước uống tại trường.',
        textbookQuote:
            'and then use the water filling stations or drinking fountains at school.',
        options: [
          'A. Hai',
          'B. Phuong',
          'C. Hoang',
          'D. Ha',
        ],
        correctIndex: 1,
        explanation:
            'Phương (16 tuổi) luôn mang theo bình nước cá nhân và tận dụng các vòi nước hoặc trạm tiếp nước ở trường học để giảm việc mua chai nhựa từ máy bán hàng tự động.',
      ),
    ],
    vocabulary: {
      'cardboard boxes': 'thùng các-tông, hộp bìa cứng',
      'leftovers': 'thức ăn thừa sau bữa ăn',
      'contaminated': 'bị làm bẩn, nhiễm tạp chất',
      'rinse out': 'tráng sạch bằng nước',
      'decompose': 'phân hủy tự nhiên trong đất',
      'landfills': 'các bãi chôn lấp rác thải',
      'reusable': 'có thể tái sử dụng nhiều lần',
      'packaging': 'bao bì đóng gói sản phẩm',
      'takeaway containers': 'hộp nhựa đựng đồ ăn mang về',
      'fountains': 'vòi phun nước uống công cộng',
      'recyclables': 'các vật liệu có thể tái chế',
    },
  );

  // ===========================================================================
  // BÀI HỌC 7: UNIT 7 - DIGITAL MEDIA VS. TRADITIONAL MEDIA (SGK TRANG IN 92-93)
  // ===========================================================================
  static const TrialLessonData _unit7Lesson = TrialLessonData(
    lessonId: 'trial_unit7_reading',
    unitNumber: 7,
    unitTitle: 'The World of Mass Media',
    lessonTitle: 'Digital Media vs. Traditional Media',
    textbookSource:
        'SGK Tiếng Anh 12 Global Success · Unit 7: The World of Mass Media · Reading (Trang in 92-93)',
    activityName: 'Activity 2 & 3: Từ vựng và Quan điểm tranh luận (Debate Corner)',
    estimatedDuration: 'Ước tính: 6-8 phút',
    isReady: true,
    paragraphs: [
      LessonParagraph(
        id: 'u7_para_intro',
        label: 'Góc tranh luận: Giới thiệu về phương tiện truyền thông (SGK trang in 92)',
        text:
            'Digital media is any form of media that is created, viewed, and distributed via electronic devices. Examples of digital media include websites, social media, videos, video games, digital advertising, software, and electronic books. With the development of technology and smart devices in recent years, digital media saw a sharp rise. This raises the question of whether digital media will replace traditional media such as printed newspapers, broadcast TV, and radio. Below are two opinion pieces sent to our Debate Corner this week.',
        translation:
            'Truyền thông số là bất kỳ hình thức truyền thông nào được tạo ra, xem và phân phối qua các thiết bị điện tử. Các ví dụ về truyền thông số bao gồm các trang web, mạng xã hội, video, trò chơi điện tử, quảng cáo kỹ thuật số, phần mềm và sách điện tử. Với sự phát triển của công nghệ và thiết bị thông minh trong những năm gần đây, truyền thông số đã chứng kiến sự gia tăng mạnh mẽ. Điều này đặt ra câu hỏi liệu truyền thông số có thay thế các phương tiện truyền thông truyền thống như báo in, truyền hình phát sóng và đài phát thanh hay không. Dưới đây là hai bài viết nêu quan điểm được gửi tới Góc Tranh Luận của chúng tôi tuần này.',
        keyWords: ['distributed', 'electronic devices', 'broadcast'],
      ),
      LessonParagraph(
        id: 'u7_para_quang',
        label: 'Ý kiến của Minh Quang: Thời của truyền thông số (SGK trang in 92)',
        text:
            'Nowadays, it is much easier and more convenient to access information via digital media. Most digital content is also freely accessible. All it takes is a few clicks, and you can read the latest news, watch videos, or see online adverts. In addition, digital media forms are more interactive. For example, customers can provide instant feedback, which can be used to solve any problems. In return, almost every organisation can reach its target customers easily via digital media. Furthermore, digital media is more flexible since information can be updated easily and frequently. By contrast, articles in printed newspapers or adverts on TV cannot be changed immediately. With more than 75 million social media users in Viet Nam and the number is increasing, it will not be long before traditional media becomes a thing of the past. (Minh Quang)',
        translation:
            'Ngày nay, việc tiếp cận thông tin qua truyền thông số dễ dàng và thuận tiện hơn nhiều. Hầu hết nội dung kỹ thuật số cũng được truy cập hoàn toàn miễn phí. Tất cả những gì bạn cần chỉ là vài cú nhấp chuột, và bạn có thể đọc tin tức mới nhất, xem video hoặc xem quảng cáo trực tuyến. Thêm vào đó, các hình thức truyền thông số có tính tương tác cao hơn. Ví dụ, khách hàng có thể cung cấp phản hồi ngay lập tức, điều này có thể được sử dụng để giải quyết bất kỳ vấn đề nào. Đổi lại, hầu hết mọi tổ chức đều có thể tiếp cận khách hàng mục tiêu của mình một cách dễ dàng qua phương tiện truyền thông số. Hơn nữa, truyền thông số linh hoạt hơn vì thông tin có thể được cập nhật dễ dàng và thường xuyên. Ngược lại, các bài báo trên báo in hoặc quảng cáo trên truyền hình không thể thay đổi ngay lập tức. Với hơn 75 triệu người dùng mạng xã hội tại Việt Nam và con số này đang ngày càng tăng, sẽ không còn lâu nữa trước khi truyền thông truyền thống trở thành dĩ vãng. (Minh Quang)',
        keyWords: ['accessible', 'interactive', 'feedback', 'flexible'],
      ),
      LessonParagraph(
        id: 'u7_para_hoa',
        label: 'Ý kiến của Phạm Hoa: Giá trị bền vững của truyền thông truyền thống (SGK trang in 92)',
        text:
            'Digital media is very convenient, but its strengths are also its own weaknesses. Since anyone with access to computers and the Internet can post or share information online, it raises the question of how credible it is. On the other hand, traditional media offers information from reliable sources that are fact-checked. Moreover, let us not forget that digital media relies on the Internet and smart devices to work well. There are still remote or disadvantaged areas in Viet Nam where access to technology is limited or too expensive. Many people also still struggle with technology. So although digital media is on the rise, traditional media such as printed newspapers, broadcast TV, and radio is here to stay. (Pham Hoa)',
        translation:
            'Truyền thông số rất tiện lợi, nhưng thế mạnh của nó cũng chính là điểm yếu của nó. Vì bất kỳ ai có máy tính và Internet đều có thể đăng hoặc chia sẻ thông tin trực tuyến, điều này đặt ra câu hỏi về mức độ đáng tin cậy của thông tin đó. Mặt khác, các phương tiện truyền thông truyền thống cung cấp thông tin từ các nguồn đáng tin cậy đã được kiểm chứng tính xác thực. Hơn nữa, chúng ta đừng quên rằng truyền thông số phải phụ thuộc vào Internet và các thiết bị thông minh mới hoạt động tốt. Vẫn còn những vùng sâu vùng xa hoặc vùng khó khăn ở Việt Nam nơi việc tiếp cận công nghệ còn hạn chế hoặc quá đắt đỏ. Nhiều người cũng vẫn gặp khó khăn trong việc sử dụng công nghệ. Vì vậy, mặc dù truyền thông số đang phát triển mạnh mẽ, các phương tiện truyền thông truyền thống như báo in, truyền hình và đài phát thanh vẫn sẽ tồn tại lâu dài. (Phạm Hoa)',
        keyWords: ['credible', 'reliable', 'fact-checked', 'here to stay'],
      ),
    ],
    questions: [
      TrialQuestionData(
        id: 'u7_rd_q1',
        word: '1. credible (SGK trang in 92)',
        targetWord: 'credible',
        pageLabel: 'Trang in 92',
        contextSentence:
            'Since anyone with access to computers and the Internet can post or share information online, it raises the question of how credible it is.',
        contextTranslation:
            'Vì bất kỳ ai có máy tính và mạng đều có thể đăng tin lên mạng, điều đó đặt ra câu hỏi tin đó đáng tin cậy đến mức nào.',
        textbookQuote:
            'Since anyone with access to computers and the Internet can post or share information online, it raises the question of how credible it is.',
        options: [
          'A. that can be trusted or believed',
          'B. that allows information to pass continuously',
          'C. that can be reached easily by anyone',
          'D. given to a large number of people',
        ],
        correctIndex: 0,
        explanation:
            '"credible" mang nghĩa đáng tin cậy, có thể tin tưởng được (that can be trusted or believed) dựa trên sự thật và căn cứ rõ ràng.',
      ),
      TrialQuestionData(
        id: 'u7_rd_q2',
        word: '2. interactive (SGK trang in 92)',
        targetWord: 'interactive',
        pageLabel: 'Trang in 92',
        contextSentence:
            'In addition, digital media forms are more interactive. For example, customers can provide instant feedback, which can be used to solve any problems.',
        contextTranslation:
            'Ngoài ra các hình thức truyền thông số có tính tương tác cao hơn. Ví dụ khách hàng có thể gửi phản hồi tức thì để giải quyết vấn đề.',
        textbookQuote:
            'In addition, digital media forms are more interactive. For example, customers can provide instant feedback, which can be used to solve any problems.',
        options: [
          'A. that cannot be altered or revised',
          'B. that allows information to be passed continuously and in both directions between different devices or users',
          'C. expensive and difficult to maintain',
          'D. distributed only via printed newspapers',
        ],
        correctIndex: 1,
        explanation:
            '"interactive" là có tính tương tác hai chiều qua lại liên tục giữa người dùng và nhà phát hành thông tin.',
      ),
      TrialQuestionData(
        id: 'u7_rd_q3',
        word: '3. accessible (SGK trang in 92)',
        targetWord: 'accessible',
        pageLabel: 'Trang in 92',
        contextSentence:
            'Nowadays, it is much easier and more convenient to access information via digital media. Most digital content is also freely accessible.',
        contextTranslation:
            'Ngày nay việc tiếp cận thông tin dễ dàng và tiện lợi hơn. Hầu hết nội dung số cũng có thể tiếp cận miễn phí.',
        textbookQuote:
            'Most digital content is also freely accessible. All it takes is a few clicks, and you can read the latest news...',
        options: [
          'A. hidden from general public view',
          'B. that can be reached, used, seen, etc.',
          'C. requiring complicated technical skills',
          'D. strictly limited to urban areas',
        ],
        correctIndex: 1,
        explanation:
            '"accessible" là có thể dễ dàng tiếp cận, xem hoặc sử dụng được (that can be reached, used, seen, etc.).',
      ),
      TrialQuestionData(
        id: 'u7_rd_q4',
        word: '4. "Digital media will replace traditional media in our country soon." - Đây là quan điểm của ai? (SGK trang in 93)',
        targetWord: 'replace traditional media soon',
        pageLabel: 'Trang in 93',
        contextSentence:
            'With more than 75 million social media users in Viet Nam and the number is increasing, it will not be long before traditional media becomes a thing of the past.',
        contextTranslation:
            'Với hơn 75 triệu người dùng mạng xã hội tại Việt Nam và đang tăng, sẽ không còn lâu nữa trước khi truyền thông truyền thống đi vào dĩ vãng.',
        textbookQuote:
            'it will not be long before traditional media becomes a thing of the past.',
        options: [
          'A. Quan điểm của Minh Quang (Q)',
          'B. Quan điểm của Phạm Hoa (H)',
          'C. Không phải quan điểm của cả hai (N)',
        ],
        correctIndex: 0,
        explanation:
            'Minh Quang khẳng định "it will not be long before traditional media becomes a thing of the past" (sẽ không lâu nữa trước khi truyền thông truyền thống thành dĩ vãng), tức là đồng ý số hóa sẽ sớm thay thế truyền thông truyền thống.',
      ),
      TrialQuestionData(
        id: 'u7_rd_q5',
        word: '5. "Both traditional and digital media will be in use in the future." - Đây là quan điểm của ai? (SGK trang in 93)',
        targetWord: 'both will be in use',
        pageLabel: 'Trang in 93',
        contextSentence:
            'So although digital media is on the rise, traditional media such as printed newspapers, broadcast TV, and radio is here to stay.',
        contextTranslation:
            'Vì vậy dù truyền thông số đang tăng, các phương tiện truyền thông truyền thống như báo in, truyền hình và radio vẫn sẽ tiếp tục tồn tại.',
        textbookQuote:
            'So although digital media is on the rise, traditional media such as printed newspapers, broadcast TV, and radio is here to stay.',
        options: [
          'A. Quan điểm của Minh Quang (Q)',
          'B. Quan điểm của Phạm Hoa (H)',
          'C. Không phải quan điểm của cả hai (N)',
        ],
        correctIndex: 1,
        explanation:
            'Phạm Hoa kết luận rằng dù truyền thông số ngày càng phát triển nhưng truyền thông truyền thống "is here to stay" (vẫn sẽ tồn tại và gắn bó lâu dài), tức cả hai hình thức đều sẽ cùng được sử dụng trong tương lai.',
      ),
      TrialQuestionData(
        id: 'u7_rd_q6',
        word: '6. Cụm từ "here to stay" trong bài viết của Hoa mang ý nghĩa gì? (SGK trang in 93)',
        targetWord: 'here to stay',
        pageLabel: 'Trang in 93',
        contextSentence:
            'So although digital media is on the rise, traditional media such as printed newspapers, broadcast TV, and radio is here to stay.',
        contextTranslation:
            'Mặc dù truyền thông số đang lên, truyền thông truyền thống như báo in, truyền hình và đài phát thanh vẫn ở lại lâu dài.',
        textbookQuote:
            'traditional media such as printed newspapers, broadcast TV, and radio is here to stay.',
        options: [
          'A. To show that digital media will only continue to be used in her country.',
          'B. To confirm her opinion that traditional media has become a part of life and will continue to be popular.',
          'C. To emphasise that printed newspapers can easily be sent to remote places.',
          'D. To state her opinion that digital media is on the rise.',
        ],
        correctIndex: 1,
        explanation:
            'Thành ngữ "here to stay" dùng để khẳng định rằng một thứ gì đó đã trở thành một phần quen thuộc của cuộc sống và sẽ tiếp tục tồn tại, phổ biến trong thời gian dài (Activity 4 Q4 SGK trang 93).',
      ),
    ],
    vocabulary: {
      'distributed': 'phân phối, phát hành rộng rãi',
      'electronic devices': 'các thiết bị điện tử',
      'broadcast': 'phát thanh, truyền hình',
      'accessible': 'dễ tiếp cận, có thể truy cập được',
      'interactive': 'có tính tương tác hai chiều',
      'feedback': 'ý kiến phản hồi',
      'flexible': 'linh hoạt, dễ điều chỉnh',
      'credible': 'đáng tin cậy, có căn cứ',
      'reliable': 'chính xác, tin cậy được',
      'fact-checked': 'đã được kiểm chứng thực tế',
      'here to stay': 'tiếp tục tồn tại lâu dài',
    },
  );

  // ===========================================================================
  // BÀI HỌC 8: UNIT 8 - WILDLIFE CONSERVATION NEWS (SGK TRANG IN 104-105)
  // ===========================================================================
  static const TrialLessonData _unit8Lesson = TrialLessonData(
    lessonId: 'trial_unit8_reading',
    unitNumber: 8,
    unitTitle: 'Wildlife Conservation',
    lessonTitle: 'Wildlife Conservation News',
    textbookSource:
        'SGK Tiếng Anh 12 Global Success · Unit 8: Wildlife Conservation · Reading (Trang in 104-105)',
    activityName: 'Activity 2 & 4: Bản tin bảo tồn động vật hoang dã',
    estimatedDuration: 'Ước tính: 6-8 phút',
    isReady: true,
    paragraphs: [
      LessonParagraph(
        id: 'u8_para_1',
        label: 'Bản tin 1: Bảo tồn rùa biển Côn Đảo (SGK trang in 104)',
        text:
            'More than 600 volunteers participated in sea turtle conservation activities held on Con Dao Island last week. Volunteers made sure that their spawning ground is safe. They also rescued turtle eggs and buried them in the sand. Sea turtles are threatened with extinction worldwide, and their populations have decreased dramatically in many places. That is why sea turtle conservation programmes are organised annually around the world. They attract many volunteers and help raise public awareness about the threats to sea turtle species.',
        translation:
            'Hơn 600 tình nguyện viên đã tham gia các hoạt động bảo tồn rùa biển được tổ chức tại đảo Côn Đảo tuần trước. Các tình nguyện viên đã đảm bảo rằng bãi đẻ trứng của chúng được an toàn. Họ cũng giải cứu trứng rùa và chôn chúng xuống cát. Rùa biển đang bị đe dọa tuyệt chủng trên toàn thế giới, và số lượng cá thể của chúng đã suy giảm nghiêm trọng ở nhiều nơi. Đó là lý do tại sao các chương trình bảo tồn rùa biển được tổ chức hàng năm trên khắp thế giới. Chúng thu hút nhiều tình nguyện viên và giúp nâng cao nhận thức cộng đồng về những mối đe dọa đối với các loài rùa biển.',
        keyWords: ['volunteers', 'spawning ground', 'extinction', 'awareness'],
      ),
      LessonParagraph(
        id: 'u8_para_2',
        label: 'Bản tin 2: Phục hồi rạn san hô vịnh Nha Trang (SGK trang in 104)',
        text:
            "Local authorities are taking measures to restore the coral reef ecosystem in Nha Trang Bay. They will organise regular clean-ups of the seabed and removal of marine debris. Diving clubs will also help by having their professional divers collect broken pieces of coral, re-grow them in underwater nurseries, and then re-attach them to reefs. Coral cover is expected to increase, which will help restore natural habitats and promote marine biodiversity in the bay. In addition, the bay's management board will also monitor the number of swimmers and divers to avoid putting too much stress on the ecosystem.",
        translation:
            'Chính quyền địa phương đang thực hiện các biện pháp nhằm phục hồi hệ sinh thái rạn san hô ở vịnh Nha Trang. Họ sẽ tổ chức dọn dẹp đáy biển định kỳ và thu gom các mảnh vụn rác biển. Các câu lạc bộ lặn cũng sẽ giúp đỡ bằng cách cử các thợ lặn chuyên nghiệp đi thu gom các mảnh san hô bị vỡ, ươm mầm lại chúng trong các vườn ươm dưới nước, và sau đó gắn lại chúng vào các rạn san hô. Độ phủ của san hô được kỳ vọng sẽ tăng lên, giúp phục hồi các môi trường sống tự nhiên và thúc đẩy sự đa dạng sinh học biển trong vịnh. Ngoài ra, ban quản lý vịnh cũng sẽ theo dõi số lượng người bơi lội và lặn biển để tránh gây quá nhiều áp lực lên hệ sinh thái.',
        keyWords: ['restore', 'coral reef', 'marine debris', 'biodiversity'],
      ),
      LessonParagraph(
        id: 'u8_para_3',
        label: 'Bản tin 3: Triển lãm tranh vì động vật hoang dã (SGK trang in 104)',
        text:
            "An exhibition entitled 'Paint for wildlife' will be held in Ha Noi next week. It will include more than 30 paintings by secondary school students across the country. Visitors will also have the opportunity to meet the young artists and discuss the stories behind their beautiful paintings. All of them will be on sale to raise money for the protection of endangered and vulnerable species. The event organisers hope to raise public awareness of wildlife conservation through art and contribute to efforts to save rare and endangered animals.",
        translation:
            'Một cuộc triển lãm mang tên "Vẽ tranh vì động vật hoang dã" sẽ được tổ chức tại Hà Nội vào tuần tới. Triển lãm sẽ trưng bày hơn 30 bức tranh của các học sinh trung học cơ sở trên khắp cả nước. Khách tham quan cũng sẽ có cơ hội gặp gỡ các họa sĩ trẻ và thảo luận về những câu chuyện đằng sau các bức tranh tuyệt đẹp của họ. Tất cả tranh sẽ được bán để gây quỹ bảo vệ các loài có nguy cơ tuyệt chủng và dễ bị tổn thương. Ban tổ chức sự kiện hy vọng sẽ nâng cao nhận thức của cộng đồng về bảo tồn động vật hoang dã thông qua nghệ thuật và đóng góp vào những nỗ lực cứu các loài động vật quý hiếm đang gặp nguy hiểm.',
        keyWords: ['exhibition', 'endangered', 'vulnerable', 'funds'],
      ),
    ],
    questions: [
      TrialQuestionData(
        id: 'u8_rd_q1',
        word: '1. Tiêu đề phù hợp nhất cho Bản tin 1 (SGK trang in 104)',
        targetWord: 'Sea turtle protection efforts',
        pageLabel: 'Trang in 104',
        contextSentence:
            'More than 600 volunteers participated in sea turtle conservation activities held on Con Dao Island last week. Volunteers made sure that their spawning ground is safe...',
        contextTranslation:
            'Hơn 600 tình nguyện viên tham gia bảo tồn rùa biển ở đảo Côn Đảo... đảm bảo bãi đẻ an toàn và cứu trứng rùa.',
        textbookQuote:
            'More than 600 volunteers participated in sea turtle conservation activities held on Con Dao Island last week.',
        options: [
          'A. Plans to help coral reefs recover',
          'B. Sea turtle protection efforts supported by hundreds of volunteers',
          'C. The effect of diving activities on coral reefs',
          'D. Wildlife art exhibition to raise public awareness and funds',
        ],
        correctIndex: 1,
        explanation:
            'Bản tin 1 nói về hơn 600 tình nguyện viên tham gia cứu hộ trứng rùa và bảo vệ bãi đẻ ở Côn Đảo, nên tiêu đề chuẩn xác là "Sea turtle protection efforts supported by hundreds of volunteers".',
      ),
      TrialQuestionData(
        id: 'u8_rd_q2',
        word: '2. Tiêu đề phù hợp nhất cho Bản tin 2 (SGK trang in 104)',
        targetWord: 'Plans to help coral reefs recover',
        pageLabel: 'Trang in 104',
        contextSentence:
            'Local authorities are taking measures to restore the coral reef ecosystem in Nha Trang Bay. They will organise regular clean-ups of the seabed and removal of marine debris. Diving clubs will also help...',
        contextTranslation:
            'Chính quyền địa phương đang áp dụng các biện pháp phục hồi hệ sinh thái san hô vịnh Nha Trang... dọn rác biển và cấy lại mảnh san hô vỡ.',
        textbookQuote:
            'Local authorities are taking measures to restore the coral reef ecosystem in Nha Trang Bay.',
        options: [
          'A. Plans to help coral reefs recover',
          'B. Young wildlife artists to hold exhibition of vulnerable species',
          'C. Sea turtle protection efforts supported by hundreds of volunteers',
          'D. Wildlife art exhibition to raise public awareness and funds',
        ],
        correctIndex: 0,
        explanation:
            'Bản tin 2 nêu các kế hoạch của chính quyền và câu lạc bộ lặn nhằm khôi phục rạn san hô vịnh Nha Trang (nursery, dọn dẹp đáy biển, hạn chế áp lực du khách), nên tiêu đề phù hợp nhất là "Plans to help coral reefs recover".',
      ),
      TrialQuestionData(
        id: 'u8_rd_q3',
        word: '3. spawning ground (SGK trang in 105)',
        targetWord: 'spawning ground',
        pageLabel: 'Trang in 105',
        contextSentence:
            'Volunteers made sure that their spawning ground is safe. They also rescued turtle eggs and buried them in the sand.',
        contextTranslation:
            'Các tình nguyện viên đảm bảo bãi đẻ trứng an toàn. Họ cũng giải cứu trứng rùa và chôn xuống cát.',
        textbookQuote:
            'Volunteers made sure that their spawning ground is safe.',
        options: [
          'A. a place where sea turtles and other animals leave their eggs',
          'B. places where young plants are grown for planting somewhere else',
          'C. broken pieces of something larger',
          'D. easily harmed or hurt physically or mentally',
        ],
        correctIndex: 0,
        explanation:
            '"spawning ground" là bãi đẻ trứng của các loài sinh vật biển như rùa biển, cá hoặc ếch nhái.',
      ),
      TrialQuestionData(
        id: 'u8_rd_q4',
        word: '4. Where is the sea turtle spawning ground? (SGK trang in 105)',
        targetWord: 'sea turtle spawning ground',
        pageLabel: 'Trang in 105',
        contextSentence:
            'More than 600 volunteers participated in sea turtle conservation activities held on Con Dao Island last week. Volunteers made sure that their spawning ground is safe.',
        contextTranslation:
            'Hơn 600 tình nguyện viên tham gia bảo tồn rùa biển ở đảo Côn Đảo... bảo đảm bãi đẻ an toàn.',
        textbookQuote:
            'More than 600 volunteers participated in sea turtle conservation activities held on Con Dao Island last week. Volunteers made sure that their spawning ground is safe.',
        options: [
          'A. Con Dao Island',
          'B. Ha Noi',
          'C. Khanh Hoa',
          'D. Nha Trang',
        ],
        correctIndex: 0,
        explanation:
            'Theo câu đầu tiên của Bản tin 1, hoạt động bảo vệ bãi đẻ của rùa biển diễn ra tại đảo Côn Đảo ("Con Dao Island").',
      ),
      TrialQuestionData(
        id: 'u8_rd_q5',
        word: '5. Which of the following is NOT true about sea turtles? (SGK trang in 105)',
        targetWord: 'NOT true about sea turtles',
        pageLabel: 'Trang in 105',
        contextSentence:
            'They also rescued turtle eggs and buried them in the sand. Sea turtles are threatened with extinction worldwide, and their populations have decreased dramatically in many places.',
        contextTranslation:
            'Họ giải cứu trứng rùa và chôn trứng xuống cát. Rùa biển bị đe dọa tuyệt chủng toàn cầu và số lượng sụt giảm nghiêm trọng.',
        textbookQuote:
            'They also rescued turtle eggs and buried them in the sand.',
        options: [
          'A. Volunteers help sea turtles by burying them in the sand.',
          'B. Their populations have gone down significantly.',
          'C. Many volunteers take part in conservation projects to help sea turtles every year.',
          'D. They are facing extinction all over the world.',
        ],
        correctIndex: 0,
        explanation:
            'Phương án A sai vì tình nguyện viên chôn "trứng rùa" ("turtle eggs") xuống cát để bảo vệ và ấp trứng, chứ không phải chôn những con rùa biển ("burying them")!',
      ),
      TrialQuestionData(
        id: 'u8_rd_q6',
        word: '6. What will happen to the paintings at the exhibition? (SGK trang in 105)',
        targetWord: 'paintings at the exhibition',
        pageLabel: 'Trang in 105',
        contextSentence:
            'All of them will be on sale to raise money for the protection of endangered and vulnerable species.',
        contextTranslation:
            'Tất cả các bức tranh sẽ được bán để gây quỹ bảo vệ các loài có nguy cơ tuyệt chủng và dễ bị tổn thương.',
        textbookQuote:
            'All of them will be on sale to raise money for the protection of endangered and vulnerable species.',
        options: [
          'A. They will be donated to visitors.',
          'B. They will be sold to raise money for wildlife conservation.',
          'C. They will be shown in public places.',
          'D. They will be given to different schools.',
        ],
        correctIndex: 1,
        explanation:
            'Trong Bản tin 3, ban tổ chức thông báo toàn bộ tranh sẽ được bán để gây quỹ bảo vệ các loài động vật nguy cấp ("sold to raise money for the protection of endangered and vulnerable species").',
      ),
    ],
    vocabulary: {
      'spawning ground': 'bãi đẻ trứng của sinh vật biển',
      'volunteers': 'các tình nguyện viên',
      'extinction': 'sự tuyệt chủng của loài sinh vật',
      'awareness': 'sự nhận thức của cộng đồng',
      'restore': 'phục hồi, tái thiết lập',
      'coral reef': 'rạn san hô biển',
      'marine debris': 'mảnh vụn, rác thải trôi nổi trên biển',
      'biodiversity': 'sự đa dạng sinh học',
      'exhibition': 'cuộc triển lãm nghệ thuật',
      'endangered': 'nguy cấp, có nguy cơ tuyệt chủng',
      'vulnerable': 'dễ bị tổn thương',
      'funds': 'quỹ kinh phí tài trợ',
    },
  );

  /// Toàn bộ 10 bài học thử tương ứng với 10 Unit trong SGK Tiếng Anh 12
  static const List<TrialLessonData> allLessons = [
    _unit1Lesson,
    _unit2Lesson,
    _unit3Lesson,
    _unit4Lesson,
    _unit5Lesson,
    _unit6Lesson,
    _unit7Lesson,
    _unit8Lesson,
    _unit9Lesson,
    _unit10Lesson,
  ];

  /// Danh sách các bài đã sẵn sàng học tương tác ngay
  List<TrialLessonData> getReadyLessons() {
    return allLessons.where((l) => l.isReady).toList();
  }

  /// Lấy bài học theo ID (ví dụ: 'trial_unit1_reading', 'trial_unit4_reading')
  TrialLessonData? getLessonById(String lessonId) {
    for (final lesson in allLessons) {
      if (lesson.lessonId == lessonId) {
        return lesson;
      }
    }
    return null;
  }

  /// Lấy bài học theo số Unit (1..10)
  TrialLessonData? getLessonByUnit(int unitNumber) {
    for (final lesson in allLessons) {
      if (lesson.unitNumber == unitNumber) {
        return lesson;
      }
    }
    return null;
  }

  /// Bài học đề xuất mặc định (Unit 1)
  TrialLessonData getDefaultLesson() => _unit1Lesson;

  /// Toàn bộ câu hỏi của tất cả các bài sẵn sàng dưới dạng Question model để tra cứu SQLite
  List<Question> getAllReadyStandardQuestions() {
    final list = <Question>[];
    for (final lesson in getReadyLessons()) {
      list.addAll(lesson.questionsAsStandardQuestions);
    }
    return list;
  }

  /// Tra cứu từ hoặc cụm từ bất kỳ trong văn bản với cơ chế ngoại tuyến hoàn chỉnh
  WordLookupResult lookupWordOrPhrase({
    required String query,
    TrialLessonData? currentLesson,
  }) {
    return lookupWordInContext(
      word: query,
      sentence: '',
      currentLesson: currentLesson,
    );
  }

  /// Tra cứu từ theo ngữ cảnh câu thực tế (nhận diện vai trò ngữ pháp, trợ động từ, dạng chia, cụm từ)
  WordLookupResult lookupWordInContext({
    required String word,
    required String sentence,
    int? wordIndex,
    TrialLessonData? currentLesson,
  }) {
    final cleaned = word.trim().toLowerCase();
    final stripped = cleaned.replaceAll(RegExp(r'^[^a-z0-9]+|[^a-z0-9]+$'), '');

    if (stripped.isEmpty) {
      return WordLookupResult(
        query: word,
        displayWord: word,
        meaning: 'Không có dữ liệu văn bản để tra cứu.',
        source: 'Học liệu SGK 12',
        isFoundInDictionary: false,
      );
    }

    // A. Kiểm tra xem trong câu có cụm từ SGK nào chứa từ này không
    String? phraseSuggestion;
    String? phraseMeaning;
    if (sentence.isNotEmpty) {
      final sentenceLower = sentence.toLowerCase();
      // Gom tất cả cụm từ bài học và từ điển cụm từ
      final allPhrases = <String, String>{
        ...phraseDictionary,
        if (currentLesson?.phraseDictionary != null) ...currentLesson!.phraseDictionary,
      };

      for (final entry in allPhrases.entries) {
        final phrase = entry.key.toLowerCase();
        if (phrase.contains(' ') && sentenceLower.contains(phrase)) {
          final wordsInPhrase = phrase.split(RegExp(r'\s+'));
          if (wordsInPhrase.contains(stripped)) {
            phraseSuggestion = entry.key;
            phraseMeaning = entry.value;
            break;
          }
        }
      }
    }

    // B. Nếu từ tra cứu chính là một cụm từ đầy đủ (chứa dấu cách)
    if (stripped.contains(' ')) {
      // 1. Kiểm tra từ điển bài học
      if (currentLesson != null && currentLesson.vocabulary.containsKey(stripped)) {
        return WordLookupResult(
          query: word,
          displayWord: stripped,
          meaning: currentLesson.vocabulary[stripped]!,
          source: 'Từ vựng trọng tâm: ${currentLesson.lessonTitle} (SGK 12)',
          isFoundInDictionary: true,
          isPhrase: true,
          contextSentence: sentence.isNotEmpty ? sentence : null,
        );
      }
      // 2. Kiểm tra từ điển cụm từ SGK
      if (phraseDictionary.containsKey(stripped)) {
        return WordLookupResult(
          query: word,
          displayWord: stripped,
          meaning: phraseDictionary[stripped]!,
          source: 'Từ điển cụm từ SGK Tiếng Anh 12',
          isFoundInDictionary: true,
          isPhrase: true,
          contextSentence: sentence.isNotEmpty ? sentence : null,
        );
      }
    }

    // C. Phân tích ngữ cảnh câu cho các từ chức năng quan trọng (has, have, had, be, do, modal)
    if (sentence.isNotEmpty) {
      final tokens = sentence
          .split(RegExp(r'\s+'))
          .map((w) => w.replaceAll(RegExp(r'^[^a-zA-Z0-9]+|[^a-zA-Z0-9]+$'), '').toLowerCase())
          .where((w) => w.isNotEmpty)
          .toList();

      int targetIdx = wordIndex ?? tokens.indexOf(stripped);
      if (targetIdx == -1) {
        for (int i = 0; i < tokens.length; i++) {
          if (tokens[i].contains(stripped) || stripped.contains(tokens[i])) {
            targetIdx = i;
            break;
          }
        }
      }

      // 1. Phân tích ngữ cảnh cho HAS / HAVE / HAD
      if (stripped == 'has' || stripped == 'have' || stripped == 'had') {
        // Tìm từ có ý nghĩa ngữ pháp đứng sau (bỏ qua trạng từ)
        String? nextMeaningfulWord;
        if (targetIdx != -1 && targetIdx + 1 < tokens.length) {
          for (int i = targetIdx + 1; i < tokens.length; i++) {
            final candidate = tokens[i];
            if (_adverbsOfFrequencyAndDegree.contains(candidate)) {
              continue; // Bỏ qua trạng từ
            }
            nextMeaningfulWord = candidate;
            break;
          }
        }

        final isPast = stripped == 'had';
        final tenseName = isPast ? 'Quá khứ hoàn thành' : 'Hiện tại hoàn thành';
        final aspectName = isPast ? 'Past Perfect' : 'Present Perfect';
        final phoneticStr = isPast ? '/hæd/' : (stripped == 'has' ? '/hæz/' : '/hæv/');

        // Trường hợp A1: Theo sau là to (has to, have to, had to) -> Động từ bắt buộc
        if (nextMeaningfulWord == 'to') {
          return WordLookupResult(
            query: word,
            displayWord: '$stripped to',
            phonetic: phoneticStr,
            partOfSpeech: '(động từ khuyết thiếu - modal verb)',
            meaning: 'Phải (chỉ sự bắt buộc hoặc bổn phận cần thiết phải làm gì).',
            source: 'Ngữ pháp SGK Tiếng Anh 12',
            isFoundInDictionary: true,
            grammaticalRole: 'Động từ chỉ sự bắt buộc (Obligation Modal Verb)',
            contextSentence: sentence,
            phraseSuggestion: phraseSuggestion,
            phraseMeaning: phraseMeaning,
          );
        }

        // Trường hợp A2: Theo sau là quá khứ phân từ (V-ed / V3) -> Trợ động từ thì hoàn thành
        final isNextPastParticiple = nextMeaningfulWord != null &&
            (_pastParticiples.contains(nextMeaningfulWord) ||
                nextMeaningfulWord.endsWith('ed') ||
                nextMeaningfulWord.endsWith('en') ||
                _irregularVerbs.containsKey(nextMeaningfulWord));

        if (isNextPastParticiple) {
          return WordLookupResult(
            query: word,
            displayWord: '$stripped (trong thì $tenseName)',
            phonetic: phoneticStr,
            partOfSpeech: '(trợ động từ - auxiliary verb)',
            meaning:
                'Trợ động từ tạo thì $tenseName; kết hợp với động từ chính phía sau để diễn tả hành động/sự việc đã xảy ra hoặc có tác động đến thời điểm được nói đến.',
            source: 'Ngữ pháp SGK Tiếng Anh 12',
            isFoundInDictionary: true,
            grammaticalRole: 'Trợ động từ thì $tenseName ($aspectName Auxiliary)',
            contextSentence: sentence,
            phraseSuggestion: phraseSuggestion,
            phraseMeaning: phraseMeaning,
          );
        }

        // Trường hợp A3: Theo sau là danh từ / mạo từ / số từ -> Động từ sở hữu
        return WordLookupResult(
          query: word,
          displayWord: stripped,
          phonetic: phoneticStr,
          partOfSpeech: '(ngoại động từ - verb)',
          meaning: 'Có, sở hữu (chỉ quyền sở hữu, mối quan hệ, đặc điểm cá nhân hoặc trải nghiệm).',
          source: 'Học liệu SGK 12',
          isFoundInDictionary: true,
          grammaticalRole: 'Ngoại động từ chỉ sở hữu (Transitive Verb)',
          contextSentence: sentence,
          phraseSuggestion: phraseSuggestion,
          phraseMeaning: phraseMeaning,
        );
      }

      // 2. Phân tích ngữ cảnh cho TO BE (is, are, was, were, am, be, been, being)
      if ({'is', 'are', 'was', 'were', 'am', 'be', 'been', 'being'}.contains(stripped)) {
        String? nextMeaningfulWord;
        if (targetIdx != -1 && targetIdx + 1 < tokens.length) {
          for (int i = targetIdx + 1; i < tokens.length; i++) {
            final candidate = tokens[i];
            if (_adverbsOfFrequencyAndDegree.contains(candidate)) continue;
            nextMeaningfulWord = candidate;
            break;
          }
        }

        // To be + V-ing -> Trợ động từ thì tiếp diễn
        if (nextMeaningfulWord != null && nextMeaningfulWord.endsWith('ing')) {
          return WordLookupResult(
            query: word,
            displayWord: stripped,
            phonetic: '/biː/',
            partOfSpeech: '(trợ động từ - auxiliary verb)',
            meaning:
                'Trợ động từ tạo thì tiếp diễn; diễn tả hành động đang diễn ra tại thời điểm được nói đến.',
            source: 'Ngữ pháp SGK Tiếng Anh 12',
            isFoundInDictionary: true,
            grammaticalRole: 'Trợ động từ thì Tiếp diễn (Continuous Aspect Auxiliary)',
            contextSentence: sentence,
            phraseSuggestion: phraseSuggestion,
            phraseMeaning: phraseMeaning,
          );
        }

        // To be + V-ed / V3 -> Trợ động từ thể bị động
        if (nextMeaningfulWord != null &&
            (_pastParticiples.contains(nextMeaningfulWord) ||
                nextMeaningfulWord.endsWith('ed') ||
                nextMeaningfulWord.endsWith('en'))) {
          return WordLookupResult(
            query: word,
            displayWord: stripped,
            phonetic: '/biː/',
            partOfSpeech: '(trợ động từ - auxiliary verb)',
            meaning:
                'Trợ động từ tạo thể bị động (được, bị); diễn tả chủ ngữ tiếp nhận tác động của hành động.',
            source: 'Ngữ pháp SGK Tiếng Anh 12',
            isFoundInDictionary: true,
            grammaticalRole: 'Trợ động từ thể Bị động (Passive Voice Auxiliary)',
            contextSentence: sentence,
            phraseSuggestion: phraseSuggestion,
            phraseMeaning: phraseMeaning,
          );
        }

        // To be thông thường -> Động từ liên kết
        return WordLookupResult(
          query: word,
          displayWord: stripped,
          phonetic: '/biː/',
          partOfSpeech: '(động từ liên kết - linking verb)',
          meaning: 'Là, thì, ở (liên kết chủ ngữ với tính chất, đặc điểm hoặc vị trí).',
          source: 'Học liệu SGK 12',
          isFoundInDictionary: true,
          grammaticalRole: 'Động từ liên kết to be (Linking Verb)',
          contextSentence: sentence,
          phraseSuggestion: phraseSuggestion,
          phraseMeaning: phraseMeaning,
        );
      }

      // 3. Phân tích cho DO / DOES / DID
      if ({'do', 'does', 'did'}.contains(stripped)) {
        final isQuestion = sentence.contains('?');
        final hasNot = sentence.contains("not") || sentence.contains("n't");
        if (isQuestion || hasNot) {
          return WordLookupResult(
            query: word,
            displayWord: stripped,
            phonetic: stripped == 'did' ? '/dɪd/' : (stripped == 'does' ? '/dʌz/' : '/duː/'),
            partOfSpeech: '(trợ động từ - auxiliary verb)',
            meaning: 'Trợ động từ dùng trong câu hỏi hoặc câu phủ định.',
            source: 'Ngữ pháp SGK Tiếng Anh 12',
            isFoundInDictionary: true,
            grammaticalRole: 'Trợ động từ câu hỏi / phủ định',
            contextSentence: sentence,
            phraseSuggestion: phraseSuggestion,
            phraseMeaning: phraseMeaning,
          );
        }
      }
    }

    // D. Tra cứu từ trong Từ vựng bài học hiện tại (nếu có)
    if (currentLesson != null && currentLesson.vocabulary.containsKey(stripped)) {
      return WordLookupResult(
        query: word,
        displayWord: stripped,
        meaning: currentLesson.vocabulary[stripped]!,
        source: 'Từ vựng trọng tâm: ${currentLesson.lessonTitle} (SGK 12)',
        isFoundInDictionary: true,
        isPhrase: stripped.contains(' '),
        contextSentence: sentence.isNotEmpty ? sentence : null,
        phraseSuggestion: phraseSuggestion,
        phraseMeaning: phraseMeaning,
      );
    }

    // E. Tra cứu trong Từ điển cụm từ
    if (phraseDictionary.containsKey(stripped)) {
      return WordLookupResult(
        query: word,
        displayWord: stripped,
        meaning: phraseDictionary[stripped]!,
        source: 'Từ điển cụm từ SGK Tiếng Anh 12',
        isFoundInDictionary: true,
        isPhrase: true,
        contextSentence: sentence.isNotEmpty ? sentence : null,
        phraseSuggestion: phraseSuggestion,
        phraseMeaning: phraseMeaning,
      );
    }

    // F. Tra cứu trong Từ điển các bài học khác
    for (final lesson in allLessons) {
      if (lesson.vocabulary.containsKey(stripped)) {
        return WordLookupResult(
          query: word,
          displayWord: stripped,
          meaning: lesson.vocabulary[stripped]!,
          source: 'Từ vựng SGK 12 Unit ${lesson.unitNumber}',
          isFoundInDictionary: true,
          isPhrase: stripped.contains(' '),
          contextSentence: sentence.isNotEmpty ? sentence : null,
          phraseSuggestion: phraseSuggestion,
          phraseMeaning: phraseMeaning,
        );
      }
    }

    // G. Tra cứu trong Từ điển tổng quát
    if (_generalDictionary.containsKey(stripped)) {
      final item = _generalDictionary[stripped]!;
      return WordLookupResult(
        query: word,
        displayWord: stripped,
        phonetic: item['phonetic'],
        partOfSpeech: item['pos'],
        meaning: item['meaning'] ?? '',
        source: 'Từ điển học liệu SGK Tiếng Anh 12',
        isFoundInDictionary: true,
        isPhrase: false,
        contextSentence: sentence.isNotEmpty ? sentence : null,
        phraseSuggestion: phraseSuggestion,
        phraseMeaning: phraseMeaning,
      );
    }

    // H. Xử lý Lemmatization (Động từ bất quy tắc, đuôi thì/dạng từ, số nhiều)
    // 1. Động từ bất quy tắc
    if (_irregularVerbs.containsKey(stripped)) {
      final base = _irregularVerbs[stripped]!;
      if (_generalDictionary.containsKey(base)) {
        final item = _generalDictionary[base]!;
        return WordLookupResult(
          query: word,
          displayWord: '$stripped (quá khứ/phân từ của $base)',
          phonetic: item['phonetic'],
          partOfSpeech: '(v-ed / v3)',
          meaning: '${item['meaning']} (dạng quá khứ/phân từ của động từ $base)',
          source: 'Từ điển học liệu SGK Tiếng Anh 12',
          isFoundInDictionary: true,
          contextSentence: sentence.isNotEmpty ? sentence : null,
          phraseSuggestion: phraseSuggestion,
          phraseMeaning: phraseMeaning,
        );
      }
    }

    // 2. Đuôi -ed
    if (stripped.endsWith('ed') && stripped.length > 3) {
      final candidates = [
        stripped.substring(0, stripped.length - 2), // attracted -> attract, worked -> work
        stripped.substring(0, stripped.length - 1), // decided -> decide, lived -> live
      ];
      for (final base in candidates) {
        if (_generalDictionary.containsKey(base)) {
          final item = _generalDictionary[base]!;
          return WordLookupResult(
            query: word,
            displayWord: '$stripped (quá khứ của $base)',
            phonetic: item['phonetic'],
            partOfSpeech: '(v-ed / v3)',
            meaning: '${item['meaning']} (dạng quá khứ hoặc quá khứ phân từ của $base)',
            source: 'Từ điển học liệu SGK Tiếng Anh 12',
            isFoundInDictionary: true,
            contextSentence: sentence.isNotEmpty ? sentence : null,
            phraseSuggestion: phraseSuggestion,
            phraseMeaning: phraseMeaning,
          );
        }
      }
    }

    // 3. Đuôi -ing
    if (stripped.endsWith('ing') && stripped.length > 4) {
      final candidates = [
        stripped.substring(0, stripped.length - 3), // working -> work
        '${stripped.substring(0, stripped.length - 3)}e', // living -> live
      ];
      for (final base in candidates) {
        if (_generalDictionary.containsKey(base)) {
          final item = _generalDictionary[base]!;
          return WordLookupResult(
            query: word,
            displayWord: '$stripped (dạng V-ing của $base)',
            phonetic: item['phonetic'],
            partOfSpeech: '(v-ing)',
            meaning: '${item['meaning']} (dạng hiện tại phân từ / danh động từ của $base)',
            source: 'Từ điển học liệu SGK Tiếng Anh 12',
            isFoundInDictionary: true,
            contextSentence: sentence.isNotEmpty ? sentence : null,
            phraseSuggestion: phraseSuggestion,
            phraseMeaning: phraseMeaning,
          );
        }
      }
    }

    // 4. Đuôi số nhiều -s / -es / -ies
    if (stripped.endsWith('s') && stripped.length > 3) {
      final candidates = <String>[];
      if (stripped.endsWith('ies')) {
        candidates.add('${stripped.substring(0, stripped.length - 3)}y'); // cities -> city
      }
      if (stripped.endsWith('es')) {
        candidates.add(stripped.substring(0, stripped.length - 2)); // boxes -> box
      }
      candidates.add(stripped.substring(0, stripped.length - 1)); // years -> year

      for (final base in candidates) {
        if (_generalDictionary.containsKey(base)) {
          final item = _generalDictionary[base]!;
          return WordLookupResult(
            query: word,
            displayWord: '$stripped (số nhiều của $base)',
            phonetic: item['phonetic'],
            partOfSpeech: '(n, số nhiều)',
            meaning: '${item['meaning']} (dạng số nhiều của danh từ $base)',
            source: 'Từ điển học liệu SGK Tiếng Anh 12',
            isFoundInDictionary: true,
            contextSentence: sentence.isNotEmpty ? sentence : null,
            phraseSuggestion: phraseSuggestion,
            phraseMeaning: phraseMeaning,
          );
        }
      }
    }

    // I. Nếu vẫn chưa có mục từ chi tiết:
    // Báo rõ ràng, trung thực; nếu có phraseSuggestion thì cung cấp cụm từ tương ứng
    return WordLookupResult(
      query: word,
      displayWord: stripped,
      meaning: 'Chưa có mục từ chi tiết cho "$stripped" trong từ điển ngoại tuyến.',
      source: 'Học liệu SGK 12',
      isFoundInDictionary: false,
      isPhrase: stripped.contains(' '),
      contextSentence: sentence.isNotEmpty ? sentence : null,
      phraseSuggestion: phraseSuggestion,
      phraseMeaning: phraseMeaning,
    );
  }
}
