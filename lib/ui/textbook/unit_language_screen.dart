import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';

import '../../data/app_repository.dart';
import '../../data/audio_repository.dart';
import '../../data/models/topic.dart';
import '../../data/models/word.dart';
import '../../data/textbook_repository.dart';
import '../../data/trial_lesson_repository.dart';
import '../theme/app_tokens.dart';
import '../audio/app_audio_controller.dart';
import '../audio/app_audio_player_widget.dart';
import '../vocab/flashcard_screen.dart';
import '../vocab/match_game_screen.dart';
import '../vocab/topic_quiz_screen.dart';
import 'textbook_screen.dart';

/// Màn hình học số hóa tương tác phần Language (Từ vựng & Ngữ pháp) chuẩn SGK Tiếng Anh 12.
class UnitLanguageScreen extends StatefulWidget {
  final int unitNumber;
  final String unitTitle;
  final int startPage;

  const UnitLanguageScreen({
    super.key,
    required this.unitNumber,
    required this.unitTitle,
    required this.startPage,
  });

  @override
  State<UnitLanguageScreen> createState() => _UnitLanguageScreenState();
}

class _UnitLanguageScreenState extends State<UnitLanguageScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final FlutterTts _tts = FlutterTts();
  List<Word> _words = [];
  Topic? _topic;
  bool _isLoadingWords = true;
  AudioTrack? _vocabTrack;

  late final Map<String, dynamic> _grammarData;
  late List<int?> _grammarAnswers;
  late List<bool> _grammarChecked;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initTts();
    _initVocabAudio();

    final lesson = TrialLessonRepository.instance.getLessonByUnit(widget.unitNumber);
    final Map<String, String> vocabMap = lesson?.vocabulary ?? <String, String>{};
    _words = vocabMap.entries.map((e) {
      return Word(
        id: 'fb_${widget.unitNumber}_${e.key}',
        topicId: 'topic_12_u${widget.unitNumber}',
        grade: 12,
        english: e.key,
        ipa: '',
        meaningVi: e.value,
        example: '',
      );
    }).toList();
    _isLoadingWords = false;
    _topic = Topic(
      id: 'topic_12_u${widget.unitNumber}',
      grade: 12,
      title: 'Unit ${widget.unitNumber}: ${widget.unitTitle}',
      order: widget.unitNumber,
    );

    _loadWords();
    _loadGrammarData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _tts.stop();
    AppAudioController.instance.stop();
    super.dispose();
  }

  Future<void> _initVocabAudio() async {
    try {
      if (!AudioRepository.instance.isLoaded) {
        await AudioRepository.instance.load();
      }
      final track = AudioRepository.instance.getVocabularyTrack(
        lessonKey: 'unit-${widget.unitNumber.toString().padLeft(2, '0')}',
      );
      if (mounted) {
        setState(() {
          _vocabTrack = track;
        });
      }
    } catch (_) {}
  }

  void _initTts() {
    try {
      _tts.setLanguage('en-US');
      _tts.setSpeechRate(0.45);
    } catch (_) {}
  }

  Future<void> _speak(String text) async {
    try {
      await _tts.speak(text);
    } catch (_) {}
  }

  Future<void> _loadWords() async {
    try {
      final repo = context.read<AppRepository>();
      final topicId = 'topic_12_u${widget.unitNumber}';
      final list = await repo.getWordsByTopicId(topicId);
      final allTopics = await repo.getAllTopics();
      Topic? foundTopic;
      try {
        foundTopic = allTopics.firstWhere((t) => t.id == topicId);
      } catch (_) {}

      if (mounted) {
        setState(() {
          _words = list;
          _topic = foundTopic ??
              Topic(
                id: topicId,
                grade: 12,
                title: 'Unit ${widget.unitNumber}: ${widget.unitTitle}',
                order: widget.unitNumber,
              );
          _isLoadingWords = false;
        });
      }
    } catch (_) {
      // Fallback: lấy từ vựng từ TrialLessonRepository
      final lesson = TrialLessonRepository.instance.getLessonByUnit(widget.unitNumber);
      final Map<String, String> vocabMap = lesson?.vocabulary ?? <String, String>{};
      final fallbackWords = vocabMap.entries.map((e) {
        return Word(
          id: 'fb_${widget.unitNumber}_${e.key}',
          topicId: 'topic_12_u${widget.unitNumber}',
          grade: 12,
          english: e.key,
          ipa: '',
          meaningVi: e.value,
          example: '',
        );
      }).toList();

      if (mounted) {
        setState(() {
          _words = fallbackWords;
          _topic = Topic(
            id: 'topic_12_u${widget.unitNumber}',
            grade: 12,
            title: 'Unit ${widget.unitNumber}: ${widget.unitTitle}',
            order: widget.unitNumber,
          );
          _isLoadingWords = false;
        });
      }
    }
  }

  void _loadGrammarData() {
    switch (widget.unitNumber) {
      case 1:
        _grammarData = {
          'title': 'Past Simple vs. Past Continuous (Quá khứ đơn & Quá khứ tiếp diễn)',
          'rules': [
            {
              'rule': '1. Diễn tả hành động đang xảy ra thì có hành động khác xen vào:',
              'formula': 'S + was/were + V-ing + WHEN + S + V-ed/V2\nWHILE + S + was/were + V-ing, S + V-ed/V2',
              'example': 'While she was working in a field hospital, she wrote her diary.',
            },
            {
              'rule': '2. Diễn tả hai hành động diễn ra song song trong quá khứ:',
              'formula': 'S1 + was/were + V-ing + WHILE + S2 + was/were + V-ing',
              'example': 'Nam was reading a book while Mark was doing his homework.',
            },
            {
              'rule': '3. Dấu hiệu nhận biết:',
              'formula': 'when, while, at this time yesterday, at 8 p.m last night',
              'example': 'She was operating on a soldier when the alarm went off.',
            },
          ],
          'questions': [
            {
              'question': '1. She ______ her diary while she was working in a field hospital.',
              'options': ['wrote', 'was writing', 'writes', 'had written'],
              'correctIndex': 0,
              'explanation': 'Hành động "viết" là hành động xen vào (Quá khứ đơn: wrote) trong khi hành động "đang làm việc" đang diễn ra (Past continuous: was working).',
            },
            {
              'question': '2. At 8 p.m yesterday, Nam and Mark ______ about the history book.',
              'options': ['talked', 'were talking', 'are talking', 'have talked'],
              'correctIndex': 1,
              'explanation': 'Có thời điểm xác định trong quá khứ ("At 8 p.m yesterday") nên dùng Quá khứ tiếp diễn (were talking).',
            },
            {
              'question': '3. He volunteered to join the army when he ______ 24 years old.',
              'options': ['is', 'was being', 'was', 'were'],
              'correctIndex': 2,
              'explanation': 'Động từ "to be" ở quá khứ đơn đi với chủ ngữ số ít "he" là "was".',
            },
          ],
        };
        break;

      case 2:
        _grammarData = {
          'title': 'Cleft Sentences with "It is / was ... that" (Câu chẻ nhấn mạnh)',
          'rules': [
            {
              'rule': '1. Nhấn mạnh chủ ngữ (Subject focus):',
              'formula': 'It is / was + S (người/vật) + THAT + V + O',
              'example': 'It was Dang Thuy Tram that inspired thousands of young people.',
            },
            {
              'rule': '2. Nhấn mạnh trạng từ nơi chốn / thời gian (Adverbial focus):',
              'formula': 'It was + trạng ngữ + THAT + S + V',
              'example': 'It was in Hue that she was born in 1942.',
            },
          ],
          'questions': [
            {
              'question': '1. It was in 1942 ______ Dang Thuy Tram was born.',
              'options': ['that', 'which', 'who', 'where'],
              'correctIndex': 0,
              'explanation': 'Cấu trúc câu chẻ nhấn mạnh trạng ngữ: "It was + Adv + that + S + V".',
            },
            {
              'question': '2. It was Steve Jobs ______ co-founded Apple Computer.',
              'options': ['whom', 'that', 'which', 'whose'],
              'correctIndex': 1,
              'explanation': 'Trong câu chẻ, đại từ "that" được dùng phổ biến để nhấn mạnh chủ ngữ.',
            },
          ],
        };
        break;

      case 3:
        _grammarData = {
          'title': 'Relative clauses referring to a whole sentence & Phrasal verbs',
          'rules': [
            {
              'rule': '1. Mệnh đề quan hệ thay thế cho cả câu đứng trước (dùng "which"):',
              'formula': 'Clause 1, WHICH + V + O/A...',
              'example': 'Plastic takes hundreds of years to decompose, which harms marine ecosystems.',
            },
            {
              'rule': '2. Cụm động từ môi trường (Phrasal verbs):',
              'formula': 'throw away (vứt bỏ), cut down on (cắt giảm), run out of (cạn kiệt), clear up (dọn sạch)',
              'example': 'We need to cut down on single-use plastics to protect our planet.',
            },
          ],
          'questions': [
            {
              'question': '1. Many students recycle cans and paper, ______ helps keep the school clean.',
              'options': ['which', 'that', 'who', 'whom'],
              'correctIndex': 0,
              'explanation': 'Đại từ quan hệ "which" đứng sau dấu phẩy để thay thế cho toàn bộ mệnh đề phía trước.',
            },
            {
              'question': '2. We should ______ single-use plastics to reduce our carbon footprint.',
              'options': ['cut down on', 'run out of', 'look up to', 'catch up with'],
              'correctIndex': 0,
              'explanation': '"Cut down on" có nghĩa là cắt giảm, tiêu giảm số lượng sử dụng.',
            },
            {
              'question': '3. If we don\'t conserve fresh water, we will soon ______ natural resources.',
              'options': ['run out of', 'get along with', 'put up with', 'come down with'],
              'correctIndex': 0,
              'explanation': '"Run out of" có nghĩa là dùng hết, cạn kiệt nguồn tài nguyên.',
            },
          ],
        };
        break;

      case 4:
        _grammarData = {
          'title': 'The Subjunctive in that-clauses (Thể giả định sau động từ đề xuất)',
          'rules': [
            {
              'rule': '1. Cấu trúc giả định thức với động từ đề xuất/yêu cầu:',
              'formula': 'S + suggest / recommend / demand / insist + THAT + S + (should) + V-infinitive',
              'example': 'The government recommends that urban planning (should) prioritize green public spaces.',
            },
            {
              'rule': '2. Dạng bị động của giả định thức:',
              'formula': 'S + recommend + THAT + S + (should) + BE + V-pII',
              'example': 'They suggested that electric buses be introduced to reduce smog.',
            },
          ],
          'questions': [
            {
              'question': '1. City planners suggest that public transport ______ upgraded immediately.',
              'options': ['be', 'is', 'was', 'are'],
              'correctIndex': 0,
              'explanation': 'Sau động từ "suggest that", động từ ở mệnh đề sau ở dạng nguyên thể không to (be).',
            },
            {
              'question': '2. Residents insisted that the municipal council ______ air pollution strictly.',
              'options': ['monitor', 'monitors', 'monitored', 'is monitoring'],
              'correctIndex': 0,
              'explanation': 'Cấu trúc giả định thức: insist that + S + V-inf (monitor).',
            },
            {
              'question': '3. It is recommended that every citizen ______ public bins properly.',
              'options': ['use', 'uses', 'used', 'using'],
              'correctIndex': 0,
              'explanation': 'It is recommended that + S + (should) use.',
            },
          ],
        };
        break;

      case 5:
        _grammarData = {
          'title': 'Reported Speech with Reporting Verbs (Câu gián tiếp với động từ tường thuật)',
          'rules': [
            {
              'rule': '1. Reporting verbs đi với to-infinitive:',
              'formula': 'agree / offer / promise / refuse + TO-V\nadvise / encourage / invite / remind / warn + O + TO-V',
              'example': 'The manager promised to give him a promotion next month.',
            },
            {
              'rule': '2. Reporting verbs đi với V-ing / Giới từ + V-ing:',
              'formula': 'admit / deny / suggest + V-ING\napologize for / thank for / congratulate on / insist on + V-ING',
              'example': 'He admitted making a mistake during the interview.',
            },
          ],
          'questions': [
            {
              'question': '1. The interviewer encouraged Lan ______ her strengths confidently.',
              'options': ['to highlight', 'highlighting', 'highlight', 'highlighted'],
              'correctIndex': 0,
              'explanation': 'Cấu trúc: encourage + O + to-V.',
            },
            {
              'question': '2. The factory manager apologized for ______ the shift schedule late.',
              'options': ['announcing', 'to announce', 'announce', 'announced'],
              'correctIndex': 0,
              'explanation': 'Cấu trúc: apologize for + V-ing.',
            },
            {
              'question': '3. Nam promised ______ on time for his vocational training course.',
              'options': ['to arrive', 'arriving', 'arrive', 'arrived'],
              'correctIndex': 0,
              'explanation': 'Cấu trúc: promise + to-V.',
            },
          ],
        };
        break;

      case 6:
        _grammarData = {
          'title': 'Active and Passive Causatives (Cấu trúc nhờ bảo, sai khiến)',
          'rules': [
            {
              'rule': '1. Cấu trúc chủ động (Active causative):',
              'formula': 'HAVE + someone + V-infinitive (nhờ ai làm gì)\nGET + someone + TO-V (thuyết phục ai làm gì)',
              'example': 'I will have the technician check my laptop.\nShe got the robot to assist her with housework.',
            },
            {
              'rule': '2. Cấu trúc bị động (Passive causative):',
              'formula': 'HAVE / GET + something + V-pII (có cái gì được làm bởi ai)',
              'example': 'The hospital had the medical records digitalized by an AI system.',
            },
          ],
          'questions': [
            {
              'question': '1. We should have the AI technician ______ the security software.',
              'options': ['update', 'to update', 'updating', 'updated'],
              'correctIndex': 0,
              'explanation': 'Cấu trúc chủ động với have: have + someone + V-inf (update).',
            },
            {
              'question': '2. Nam got his teacher ______ his robotics project presentation.',
              'options': ['to review', 'review', 'reviewing', 'reviewed'],
              'correctIndex': 0,
              'explanation': 'Cấu trúc chủ động với get: get + someone + to-V (to review).',
            },
            {
              'question': '3. The high-tech centre had all their surveillance cameras ______ yesterday.',
              'options': ['replaced', 'replace', 'to replace', 'replacing'],
              'correctIndex': 0,
              'explanation': 'Cấu trúc bị động: have + something + V-pII (replaced).',
            },
          ],
        };
        break;

      case 7:
        _grammarData = {
          'title': 'Prepositions after Verbs (Giới từ theo sau động từ)',
          'rules': [
            {
              'rule': '1. Động từ đi với giới từ cố định trong chủ đề truyền thông:',
              'formula': 'rely on / depend on (phụ thuộc vào), focus on (tập trung vào), search for (tìm kiếm), interact with (tương tác với), benefit from (hưởng lợi từ), prevent from (ngăn chặn khỏi)',
              'example': 'Many teenagers rely on social media for daily news updates.',
            },
          ],
          'questions': [
            {
              'question': '1. Young people should not rely too much ______ unverified news on the internet.',
              'options': ['on', 'in', 'at', 'with'],
              'correctIndex': 0,
              'explanation': 'Cụm động từ cố định: rely on (tin cậy, dựa dẫm vào).',
            },
            {
              'question': '2. The marketing team focused ______ creating viral video content for the charity event.',
              'options': ['on', 'for', 'about', 'to'],
              'correctIndex': 0,
              'explanation': 'Cụm động từ cố định: focus on + V-ing.',
            },
            {
              'question': '3. Strong privacy settings can prevent users ______ online scams.',
              'options': ['from', 'against', 'out of', 'off'],
              'correctIndex': 0,
              'explanation': 'Cấu trúc: prevent someone from something / V-ing.',
            },
          ],
        };
        break;

      case 8:
        _grammarData = {
          'title': 'Adverbial Clauses of Concession & Condition (Mệnh đề nhượng bộ & điều kiện)',
          'rules': [
            {
              'rule': '1. Mệnh đề trạng ngữ chỉ sự nhượng bộ:',
              'formula': 'ALTHOUGH / EVEN THOUGH / THOUGH + Clause (S + V)\nIN SPITE OF / DESPITE + Noun Phrase / V-ing',
              'example': 'Although rangers face great danger, they continue to protect wildlife.\nDespite strict laws, illegal poaching still occurs.',
            },
          ],
          'questions': [
            {
              'question': '1. ______ the conservation efforts, some rare species are still on the brink of extinction.',
              'options': ['Despite', 'Although', 'Even though', 'Because'],
              'correctIndex': 0,
              'explanation': '"Despite" đi với một cụm danh từ ("the conservation efforts").',
            },
            {
              'question': '2. The rescue centre released the gibbons into the wild ______ they had fully recovered.',
              'options': ['after', 'although', 'despite', 'unless'],
              'correctIndex': 0,
              'explanation': '"After" diễn tả trình tự thời gian: thả linh trưởng sau khi đã bình phục hoàn toàn.',
            },
            {
              'question': '3. Wildlife cannot survive ______ human destruction of natural habitats is stopped.',
              'options': ['unless', 'if', 'provided that', 'as long as'],
              'correctIndex': 0,
              'explanation': '"Unless" = If not (trừ phi sự tàn phá môi trường sống được chấm dứt).',
            },
          ],
        };
        break;

      case 9:
        _grammarData = {
          'title': 'Phrasal Verbs in Career and Work Context (Cụm động từ hướng nghiệp)',
          'rules': [
            {
              'rule': '1. Các cụm động từ quan trọng trong nghề nghiệp:',
              'formula': 'apply for (nộp đơn xin việc), take up (bắt đầu học/làm nghề), carry out (tiến hành), look forward to (mong đợi), burn out (kiệt sức)',
              'example': 'After graduation, he applied for an apprenticeship at an engineering firm.',
            },
          ],
          'questions': [
            {
              'question': '1. Nam decided to ______ a vocational course in electrical engineering.',
              'options': ['take up', 'give up', 'look into', 'put off'],
              'correctIndex': 0,
              'explanation': '"Take up" có nghĩa là bắt đầu học hoặc theo đuổi một sở thích/khóa học.',
            },
            {
              'question': '2. She ______ over twenty job applications before receiving an interview offer.',
              'options': ['sent out', 'brought up', 'called off', 'turned down'],
              'correctIndex': 0,
              'explanation': '"Send out" có nghĩa là gửi đi (đơn xin việc).',
            },
            {
              'question': '3. Working without regular breaks can cause employees to ______ quickly.',
              'options': ['burn out', 'carry out', 'drop out', 'break down'],
              'correctIndex': 0,
              'explanation': '"Burn out" có nghĩa là kiệt sức do làm việc quá sức.',
            },
          ],
        };
        break;

      case 10:
        _grammarData = {
          'title': 'Conditionals Review & Mixed Conditionals (Ôn tập & Câu điều kiện hỗn hợp)',
          'rules': [
            {
              'rule': '1. Câu điều kiện hỗn hợp (Mixed Conditionals):',
              'formula': 'If + S + had + V-pII (quá khứ), S + would / could + V-inf (hiện tại)',
              'example': 'If I had learned computer skills when I was younger, I would feel more confident with laptops now.',
            },
          ],
          'questions': [
            {
              'question': '1. If Mark ______ his grandma how to use the laptop, she wouldn\'t be able to read the news now.',
              'options': ['hadn\'t shown', 'doesn\'t show', 'didn\'t show', 'hasn\'t shown'],
              'correctIndex': 0,
              'explanation': 'Mệnh đề If chỉ giả thiết trái với quá khứ (hadn\'t shown), mệnh đề chính chỉ kết quả ở hiện tại (wouldn\'t be able... now).',
            },
            {
              'question': '2. If people continuously update their knowledge, they ______ competitive in the job market.',
              'options': ['will remain', 'remained', 'had remained', 'would have remained'],
              'correctIndex': 0,
              'explanation': 'Câu điều kiện loại 1 diễn tả sự việc có thể xảy ra ở hiện tại/tương lai.',
            },
            {
              'question': '3. Lifelong learning ______ possible if online courses were not accessible.',
              'options': ['would not be', 'will not be', 'is not', 'had not been'],
              'correctIndex': 0,
              'explanation': 'Câu điều kiện loại 2 giả định trái với thực tế hiện tại (would not be).',
            },
          ],
        };
        break;

      default:
        _grammarData = {
          'title': 'Ôn tập ngữ pháp tổng hợp',
          'rules': [
            {
              'rule': 'Quy tắc ngữ pháp ôn luyện thi tốt nghiệp THPT:',
              'formula': 'Nắm vững các thì của động từ, mệnh đề quan hệ và câu điều kiện.',
              'example': 'Luyện tập giải đề thường xuyên để thành thạo các cấu trúc biến đổi câu.',
            },
          ],
          'questions': [
            {
              'question': '1. She ______ in this city since she graduated from university.',
              'options': ['has lived', 'lives', 'lived', 'is living'],
              'correctIndex': 0,
              'explanation': 'Dấu hiệu "since + mốc thời gian" dùng thì hiện tại hoàn thành (has lived).',
            },
          ],
        };
        break;
    }

    final qList = (_grammarData['questions'] as List).cast<Map<String, dynamic>>();
    _grammarAnswers = List<int?>.filled(qList.length, null);
    _grammarChecked = List<bool>.filled(qList.length, false);
  }

  Future<void> _openTextbookOriginal() async {
    try {
      final repo = TextbookRepository();
      final book = await repo.load();
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TextbookReader(
            book: book,
            initialPage: widget.startPage + 1,
            start: widget.startPage,
            end: widget.startPage + 11,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể tải trang in SGK. Vui lòng thử lại.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Language · Từ vựng & Ngữ pháp',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTokens.primary),
            ),
            Text(
              'Unit ${widget.unitNumber}: ${widget.unitTitle}',
              style: const TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.menu_book_rounded, size: 16, color: AppTokens.primary),
            label: const Text(
              'Trang in SGK',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTokens.primary,
              ),
            ),
            onPressed: _openTextbookOriginal,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTokens.primary,
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: AppTokens.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontFamily: 'BeVietnamPro',
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
          tabs: [
            Tab(text: '1. Từ vựng SGK (${_words.length} từ)'),
            const Tab(text: '2. Ngữ pháp trọng tâm'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildVocabularyTab(),
          _buildGrammarTab(),
        ],
      ),
    );
  }

  Widget _buildVocabularyTab() {
    if (_isLoadingWords) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_words.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.menu_book_outlined, size: 48, color: Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            const Text('Chưa có danh sách từ vựng cho Unit này.'),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _openTextbookOriginal,
              child: const Text('Xem trang in SGK gốc'),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Audio bản thu SGK nguyên bản của Vocabulary Activity 1
        if (_vocabTrack != null) ...[
          AppAudioPlayerWidget(
            track: _vocabTrack!,
            title: 'Audio phát âm danh sách từ (Vocabulary Activity 1)',
            subtitle: 'Bản thu người bản ngữ đọc danh mục từ vựng trọng tâm',
            compact: true,
          ),
          const SizedBox(height: 14),
        ],

        // Các nút hành động nhanh: Flashcard, Quiz & Ghép Thẻ
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFD97706),
                  side: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.dashboard_customize_rounded, size: 18),
                label: const Text('Ghép Thẻ', style: TextStyle(fontWeight: FontWeight.w700)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MatchGameScreen(
                        initialUnit: widget.unitNumber,
                        customWords: _words,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTokens.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.style_rounded, size: 18),
                label: const Text('Học Flashcard', style: TextStyle(fontWeight: FontWeight.w700)),
                onPressed: () {
                  if (_topic != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FlashcardScreen(
                          words: _words,
                          topicTitle: _topic!.title,
                          topic: _topic,
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTokens.primary,
                  side: const BorderSide(color: AppTokens.primary, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.quiz_outlined, size: 18),
                label: const Text('Quiz từ vựng', style: TextStyle(fontWeight: FontWeight.w700)),
                onPressed: () {
                  if (_topic != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TopicQuizScreen(topic: _topic!),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Danh sách thẻ từ vựng chi tiết
        ..._words.map((w) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x04000000),
                  offset: Offset(0, 2),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            w.english,
                            style: const TextStyle(
                              fontFamily: 'BeVietnamPro',
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            w.ipa,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.volume_up_rounded, color: AppTokens.primary),
                      tooltip: 'Phát âm chuẩn',
                      onPressed: () => _speak(w.english),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  w.meaningVi,
                  style: const TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF1E40AF),
                  ),
                ),
                if (w.example.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                    ),
                    child: Text(
                      'Ví dụ: "${w.example}"',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontStyle: FontStyle.italic,
                        color: Color(0xFF475569),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildGrammarTab() {
    final rules = (_grammarData['rules'] as List).cast<Map<String, String>>();
    final questions = (_grammarData['questions'] as List).cast<Map<String, dynamic>>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Tiêu đề chủ điểm ngữ pháp
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Row(
            children: [
              const Icon(Icons.psychology_outlined, color: AppTokens.primary, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _grammarData['title'] as String,
                  style: const TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    color: Color(0xFF1E40AF),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Các khối quy tắc & công thức
        ...rules.map((r) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r['rule'] ?? '',
                  style: const TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    r['formula'] ?? '',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
                if ((r['example'] ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '• Ví dụ SGK: "${r['example']}"',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF475569),
                    ),
                  ),
                ],
              ],
            ),
          );
        }),

        const SizedBox(height: 10),
        const Text(
          'Luyện tập trắc nghiệm ngữ pháp SGK',
          style: TextStyle(
            fontFamily: 'BeVietnamPro',
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 12),

        // Bài tập trắc nghiệm ngữ pháp
        ...questions.asMap().entries.map((entry) {
          final qIndex = entry.key;
          final q = entry.value;
          final qText = q['question'] as String;
          final options = (q['options'] as List).cast<String>();
          final correctIdx = q['correctIndex'] as int;
          final explanation = q['explanation'] as String;
          final selected = _grammarAnswers[qIndex];
          final isChecked = _grammarChecked[qIndex];

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  qText,
                  style: const TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 10),

                ...options.asMap().entries.map((optEntry) {
                  final optIdx = optEntry.key;
                  final optText = optEntry.value;
                  final isSelected = selected == optIdx;

                  Color bg = Colors.white;
                  Color border = const Color(0xFFE2E8F0);
                  if (isChecked) {
                    if (optIdx == correctIdx) {
                      bg = const Color(0xFFF0FDF4);
                      border = const Color(0xFF22C55E);
                    } else if (isSelected) {
                      bg = const Color(0xFFFEF2F2);
                      border = AppTokens.errorRed;
                    }
                  } else if (isSelected) {
                    bg = const Color(0xFFEFF6FF);
                    border = AppTokens.primary;
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: isChecked
                          ? null
                          : () {
                              setState(() {
                                _grammarAnswers[qIndex] = optIdx;
                                _grammarChecked[qIndex] = true;
                              });
                            },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: border, width: isSelected ? 1.5 : 1.0),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                              size: 18,
                              color: isSelected ? AppTokens.primary : const Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                optText,
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  fontSize: 13.5,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

                if (isChecked) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: selected == correctIdx
                          ? const Color(0xFFF0FDF4)
                          : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          selected == correctIdx
                              ? Icons.check_circle_outline_rounded
                              : Icons.info_outline_rounded,
                          size: 16,
                          color: selected == correctIdx
                              ? const Color(0xFF16A34A)
                              : AppTokens.errorRed,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            explanation,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
        const SizedBox(height: 20),
      ],
    );
  }
}
