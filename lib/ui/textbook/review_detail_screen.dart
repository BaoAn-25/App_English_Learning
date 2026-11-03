import 'package:flutter/material.dart';
import '../../data/app_repository.dart';
import '../audio/app_audio_controller.dart';
import '../auth/auth_controller.dart';
import '../theme/app_tokens.dart';

class ReviewInfo {
  final int reviewNumber;
  final String title;
  final String unitsCovered;
  final String pages;
  final String listeningTrackId;
  final String listeningAsset;
  final String pronunciationFocus;
  final String grammarFocus;
  final String readingPassage;
  final List<ReviewQuestion> languageQuestions;
  final List<ReviewQuestion> listeningQuestions;
  final List<ReviewQuestion> readingQuestions;
  final String speakingTask;
  final String writingPrompt;
  final String writingOutline;

  const ReviewInfo({
    required this.reviewNumber,
    required this.title,
    required this.unitsCovered,
    required this.pages,
    required this.listeningTrackId,
    required this.listeningAsset,
    required this.pronunciationFocus,
    required this.grammarFocus,
    required this.readingPassage,
    required this.languageQuestions,
    required this.listeningQuestions,
    required this.readingQuestions,
    required this.speakingTask,
    required this.writingPrompt,
    required this.writingOutline,
  });
}

class ReviewQuestion {
  final String id;
  final String prompt;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  const ReviewQuestion({
    required this.id,
    required this.prompt,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });
}

class ReviewDetailScreen extends StatefulWidget {
  final int reviewNumber; // 1, 2, 3, 4

  const ReviewDetailScreen({super.key, required this.reviewNumber});

  @override
  State<ReviewDetailScreen> createState() => _ReviewDetailScreenState();
}

class _ReviewDetailScreenState extends State<ReviewDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AppRepository _repo = AppRepository();
  final AppAudioController _audioController = AppAudioController.instance;

  late final ReviewInfo _info;
  final Map<String, int> _userAnswers = {};
  final TextEditingController _writingController = TextEditingController();
  int _wordCount = 0;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _info = _getReviewInfo(widget.reviewNumber);
    _writingController.addListener(() {
      final text = _writingController.text.trim();
      final words = text.isEmpty ? 0 : text.split(RegExp(r'\s+')).length;
      if (words != _wordCount) {
        setState(() => _wordCount = words);
      }
    });
    _loadSavedData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _writingController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedData() async {
    final auth = AuthController.instance;
    final ownerId = auth.isAuthenticated && !auth.user.isGuest
        ? auth.user.id
        : await _repo.getOrCreateGuestSessionId();
    final savedEssay = await _repo.getSetting('review_${widget.reviewNumber}_writing_$ownerId');
    if (savedEssay != null && mounted) {
      _writingController.text = savedEssay;
    }
  }

  Future<void> _saveProgress() async {
    final auth = AuthController.instance;
    final ownerId = auth.isAuthenticated && !auth.user.isGuest
        ? auth.user.id
        : await _repo.getOrCreateGuestSessionId();

    if (_writingController.text.trim().isNotEmpty) {
      await _repo.setSetting(
        'review_${widget.reviewNumber}_writing_$ownerId',
        _writingController.text.trim(),
      );
    }

    // Ghi nhận hoàn thành bài Review
    await _repo.setSetting('review_${widget.reviewNumber}_completed_$ownerId', 'true');

    if (mounted) {
      setState(() => _isSaved = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã lưu bài ôn tập và tiến độ thành công!'),
          backgroundColor: AppTokens.successGreen,
        ),
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
            Text(
              _info.title,
              style: const TextStyle(
                fontFamily: 'BeVietnamPro',
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: Color(0xFF0F172A),
              ),
            ),
            Text(
              '${_info.unitsCovered} • SGK trang ${_info.pages}',
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTokens.primary,
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: AppTokens.primary,
          indicatorWeight: 3,
          isScrollable: true,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.menu_book_rounded, size: 18), text: 'Language'),
            Tab(icon: Icon(Icons.headphones_rounded, size: 18), text: 'Listening'),
            Tab(icon: Icon(Icons.article_rounded, size: 18), text: 'Reading'),
            Tab(icon: Icon(Icons.edit_note_rounded, size: 18), text: 'Writing & Speaking'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLanguageTab(),
          _buildListeningTab(),
          _buildReadingTab(),
          _buildWritingAndSpeakingTab(),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              offset: const Offset(0, -2),
              blurRadius: 6,
            ),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTokens.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            label: Text(
              _isSaved ? 'Đã lưu kết quả' : 'Lưu bài ôn tập (+50 XP)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
            ),
            onPressed: _saveProgress,
          ),
        ),
      ),
    );
  }

  // --- TAB 1: LANGUAGE REVIEW ---
  Widget _buildLanguageTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildInfoBanner(
          'Trọng tâm ôn tập Ngôn ngữ',
          '• Phát âm: ${_info.pronunciationFocus}\n• Ngữ pháp: ${_info.grammarFocus}',
          Icons.psychology_rounded,
          const Color(0xFFEFF6FF),
          AppTokens.primary,
        ),
        const SizedBox(height: 16),
        const Text(
          'Bài tập trắc nghiệm Ngữ pháp & Từ vựng SGK',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 10),
        ..._info.languageQuestions.asMap().entries.map((entry) {
          final idx = entry.key;
          final q = entry.value;
          return _buildQuestionCard(idx + 1, q);
        }),
      ],
    );
  }

  // --- TAB 2: LISTENING REVIEW ---
  Widget _buildListeningTab() {
    return AnimatedBuilder(
      animation: _audioController,
      builder: (context, _) {
        final isPlayingCurrent = _audioController.isPlaying &&
            _audioController.currentAssetPath == _info.listeningAsset;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Card Trình phát Audio SGK
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: const [
                  BoxShadow(color: Color(0x06000000), offset: Offset(0, 2), blurRadius: 6),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.headphones_rounded, color: AppTokens.primary, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Track: ${_info.title} Listening',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            Text(
                              'File gốc: ${_info.listeningAsset.split('/').last}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        iconSize: 42,
                        color: AppTokens.primary,
                        icon: Icon(isPlayingCurrent
                            ? Icons.pause_circle_filled_rounded
                            : Icons.play_circle_fill_rounded),
                        onPressed: () {
                          if (isPlayingCurrent) {
                            _audioController.pause();
                          } else {
                            _audioController.playAsset(
                              assetPath: _info.listeningAsset,
                              trackId: _info.listeningTrackId,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  if (_audioController.errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _audioController.errorMessage!,
                      style: const TextStyle(color: AppTokens.errorRed, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Câu hỏi kiểm tra kỹ năng nghe',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 10),
            ..._info.listeningQuestions.asMap().entries.map((entry) {
              final idx = entry.key;
              final q = entry.value;
              return _buildQuestionCard(idx + 1, q);
            }),
          ],
        );
      },
    );
  }

  // --- TAB 3: READING REVIEW ---
  Widget _buildReadingTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Đoạn văn bài đọc SGK
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.menu_book_rounded, color: AppTokens.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Đoạn đọc SGK Review ${_info.reviewNumber}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              const Divider(height: 20),
              Text(
                _info.readingPassage,
                style: const TextStyle(fontSize: 13.5, height: 1.6, color: Color(0xFF1E293B)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Câu hỏi đọc hiểu',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 10),
        ..._info.readingQuestions.asMap().entries.map((entry) {
          final idx = entry.key;
          final q = entry.value;
          return _buildQuestionCard(idx + 1, q);
        }),
      ],
    );
  }

  // --- TAB 4: WRITING & SPEAKING REVIEW ---
  Widget _buildWritingAndSpeakingTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Nhiệm vụ nói (Speaking)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.record_voice_over_rounded, color: Color(0xFF16A34A), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Chủ đề luyện nói (Speaking Task)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF166534)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _info.speakingTask,
                style: const TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF14532D)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Nhiệm vụ viết (Writing)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.draw_rounded, color: AppTokens.primary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Đề bài Viết (Writing Prompt)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _info.writingPrompt,
                style: const TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 12),
              ExpansionTile(
                title: const Text('Gợi ý dàn ý (Outline)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                tilePadding: EdgeInsets.zero,
                children: [
                  Text(
                    _info.writingOutline,
                    style: const TextStyle(fontSize: 12.5, height: 1.5, color: Color(0xFF475569)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Bài làm của bạn:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(
                    'Số từ: $_wordCount / 120-150 từ',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _wordCount >= 100 ? AppTokens.successGreen : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _writingController,
                maxLines: 8,
                decoration: InputDecoration(
                  hintText: 'Nhập bài viết bằng tiếng Anh của bạn tại đây...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.all(14),
                ),
                style: const TextStyle(fontSize: 13.5, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionCard(int questionNum, ReviewQuestion q) {
    final selectedOption = _userAnswers[q.id];
    final isAnswered = selectedOption != null;

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
            'Câu $questionNum: ${q.prompt}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, height: 1.4),
          ),
          const SizedBox(height: 10),
          ...q.options.asMap().entries.map((entry) {
            final optIdx = entry.key;
            final optText = entry.value;
            final isChosen = selectedOption == optIdx;
            final isCorrect = optIdx == q.correctIndex;

            Color border = const Color(0xFFE2E8F0);
            Color bg = Colors.white;
            if (isAnswered) {
              if (isCorrect) {
                border = AppTokens.successGreen;
                bg = const Color(0xFFF0FDF4);
              } else if (isChosen) {
                border = AppTokens.errorRed;
                bg = const Color(0xFFFFF1F2);
              }
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: isAnswered
                    ? null
                    : () {
                        setState(() {
                          _userAnswers[q.id] = optIdx;
                        });
                      },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: border, width: isChosen || (isAnswered && isCorrect) ? 1.5 : 1.0),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isChosen ? AppTokens.primary : const Color(0xFFF1F5F9),
                        ),
                        child: Center(
                          child: Text(
                            String.fromCharCode(65 + optIdx),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isChosen ? Colors.white : const Color(0xFF475569),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          optText,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          if (isAnswered) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                'Giải thích: ${q.explanation}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoBanner(String title, String content, IconData icon, Color bg, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: iconColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: iconColor)),
                const SizedBox(height: 4),
                Text(content, style: const TextStyle(fontSize: 12.5, height: 1.4, color: Color(0xFF334155))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  ReviewInfo _getReviewInfo(int rev) {
    switch (rev) {
      case 1:
        return const ReviewInfo(
          reviewNumber: 1,
          title: 'Review 1 (Units 1 - 3)',
          unitsCovered: 'Life Stories • Multicultural World • Green Living',
          pages: '44 - 47',
          listeningTrackId: 'rev1_listen',
          listeningAsset: 'assets/audio/global_success_12/listening/004.mp3',
          pronunciationFocus: 'Nguyên âm đôi /eɪ/, /aɪ/, /ɔɪ/, /əʊ/, /aʊ/ và lược âm (elision)',
          grammarFocus: 'Quá khứ đơn vs. Quá khứ tiếp diễn; Mạo từ (a/an/the/Ø); Động từ chỉ trạng thái',
          readingPassage: 'Preserving our planet requires active participation from everyone. In recent years, young environmental activists have founded numerous grassroots movements that inspire local communities to reduce carbon footprints, minimize single-use plastics, and adopt renewable energy sources. Through educational campaigns, they prove that sustainable habits can be easily integrated into daily life.',
          languageQuestions: [
            ReviewQuestion(
              id: 'r1_q1',
              prompt: 'While the volunteers _______ trees in the park, heavy rain began to fall.',
              options: ['planted', 'were planting', 'had planted', 'are planting'],
              correctIndex: 1,
              explanation: 'Hành động đang diễn ra trong quá khứ (were planting) thì hành động khác xen vào (began to fall).',
            ),
            ReviewQuestion(
              id: 'r1_q2',
              prompt: 'Dr. Dang Thuy Tram dedicated _______ life to helping wounded soldiers during the war.',
              options: ['her', 'hers', 'she', 'himself'],
              correctIndex: 0,
              explanation: 'Tính từ sở hữu "her" bổ nghĩa cho danh từ "life".',
            ),
            ReviewQuestion(
              id: 'r1_q3',
              prompt: 'We should bring reusable bags instead of asking for _______ plastic bags at the supermarket.',
              options: ['a', 'an', 'the', 'Ø (no article)'],
              correctIndex: 3,
              explanation: 'Danh từ số nhiều chỉ chung chung không dùng mạo từ (Ø).',
            ),
          ],
          listeningQuestions: [
            ReviewQuestion(
              id: 'r1_l1',
              prompt: 'What is the main topic of the conversation?',
              options: ['A green lifestyle campaign at school', 'A historical documentary', 'A graduation trip', 'A traditional culinary festival'],
              correctIndex: 0,
              explanation: 'Đoạn băng thảo luận về chiến dịch lối sống xanh tại trường học.',
            ),
            ReviewQuestion(
              id: 'r1_l2',
              prompt: 'What did the speaker suggest students do every Wednesday?',
              options: ['Plant a tree', 'Walk or ride bicycles to school', 'Collect plastic bottles', 'Attend a science workshop'],
              correctIndex: 1,
              explanation: 'Di chuyển bằng xe đạp hoặc đi bộ vào thứ Tư xanh.',
            ),
          ],
          readingQuestions: [
            ReviewQuestion(
              id: 'r1_r1',
              prompt: 'According to the passage, who has founded grassroots movements recently?',
              options: ['Professional scientists', 'Young environmental activists', 'Government officials', 'Commercial enterprises'],
              correctIndex: 1,
              explanation: 'Đoạn 1 nêu rõ: "young environmental activists have founded numerous grassroots movements".',
            ),
          ],
          speakingTask: 'Thảo luận cùng bạn bè về những hành động nhỏ giúp bảo vệ môi trường trong trường học của bạn.',
          writingPrompt: 'Viết một đoạn văn ngắn (120 - 150 từ) về một nhân vật truyền cảm hứng mà bạn ngưỡng mộ (tương tự như trong Unit 1).',
          writingOutline: '1. Mở đoạn: Giới thiệu người truyền cảm hứng và lý do ngưỡng mộ.\n2. Thân đoạn: Những đóng góp, nỗ lực và thành tựu nổi bật.\n3. Kết đoạn: Bài học cuộc sống bạn rút ra được.',
        );
      case 2:
        return const ReviewInfo(
          reviewNumber: 2,
          title: 'Review 2 (Units 4 - 5)',
          unitsCovered: 'Urbanisation • The World of Work',
          pages: '72 - 75',
          listeningTrackId: 'rev2_listen',
          listeningAsset: 'assets/audio/global_success_12/listening/007.mp3',
          pronunciationFocus: 'Nguyên âm đôi /ɪə/, /eə/, /ʊə/ & Trọng âm từ 3 âm tiết',
          grammarFocus: 'Thể giả định trong mệnh đề That; Cụm động từ (Phrasal Verbs); Câu tường thuật',
          readingPassage: 'Rapid urbanisation has dramatically changed career landscapes globally. High-tech smart cities demand modern workforces with digital literacy, adaptability, and cross-cultural communication skills. Conventional office roles are transforming into flexible remote positions, making continuous skill upgrading vital for future job seekers.',
          languageQuestions: [
            ReviewQuestion(
              id: 'r2_q1',
              prompt: 'It is essential that every applicant _______ their resume before the interview deadline.',
              options: ['submits', 'submit', 'submitted', 'will submit'],
              correctIndex: 1,
              explanation: 'Cấu trúc giả định "It is essential that + S + V(nguyên thể)" -> submit.',
            ),
            ReviewQuestion(
              id: 'r2_q2',
              prompt: 'She decided to _______ the lucrative job offer because it required too much overseas travel.',
              options: ['turn down', 'give up', 'look after', 'take off'],
              correctIndex: 0,
              explanation: '"Turn down" nghĩa là từ chối (lời mời nhận việc).',
            ),
          ],
          listeningQuestions: [
            ReviewQuestion(
              id: 'r2_l1',
              prompt: 'What job skill is emphasized most by the speaker?',
              options: ['Manual labor', 'Digital competence and flexibility', 'Accounting calculations', 'Language translation only'],
              correctIndex: 1,
              explanation: 'Kỹ năng số và sự linh hoạt trong thị trường việc làm hiện đại.',
            ),
          ],
          readingQuestions: [
            ReviewQuestion(
              id: 'r2_r1',
              prompt: 'What makes continuous skill upgrading vital for modern job seekers?',
              options: ['Rising tuition fees', 'The transformation into flexible and high-tech positions', 'Retirement policies', 'Reduced work hours'],
              correctIndex: 1,
              explanation: 'Sự chuyển đổi sang các vị trí công việc công nghệ cao và làm việc từ xa.',
            ),
          ],
          speakingTask: 'Thảo luận về nghề nghiệp mơ ước trong tương lai và những kỹ năng bạn cần chuẩn bị.',
          writingPrompt: 'Viết một bài luận ngắn (120 - 150 từ) về ưu và nhược điểm của quá trình đô thị hóa.',
          writingOutline: '1. Mở đoạn: Định nghĩa đô thị hóa.\n2. Thân đoạn: Lợi ích (việc làm, tiện ích) và thách thức (kẹt xe, ô nhiễm).\n3. Kết đoạn: Giải pháp phát triển bền vững.',
        );
      case 3:
        return const ReviewInfo(
          reviewNumber: 3,
          title: 'Review 3 (Units 6 - 8)',
          unitsCovered: 'Artificial Intelligence • Mass Media • Wildlife Conservation',
          pages: '112 - 115',
          listeningTrackId: 'rev3_listen',
          listeningAsset: 'assets/audio/global_success_12/listening/011.mp3',
          pronunciationFocus: 'Ngữ điệu trong câu hỏi đuôi (Tag questions) và câu hỏi Wh-',
          grammarFocus: 'Thể truyền khiến (Causative form); Mệnh đề trạng ngữ chỉ cách thức & kết quả',
          readingPassage: 'Artificial intelligence is revolutionising wildlife protection programs around the world. Drones equipped with computer vision can monitor endangered habitats without disturbing animals, while acoustic sensors analyse forest noises to detect illegal chainsawing or poaching activities in real time.',
          languageQuestions: [
            ReviewQuestion(
              id: 'r3_q1',
              prompt: 'The park rangers had cameras _______ along the animal trails to monitor rare tigers.',
              options: ['install', 'installed', 'installing', 'to install'],
              correctIndex: 1,
              explanation: 'Cấu trúc bị động truyền khiến: have something done -> installed.',
            ),
            ReviewQuestion(
              id: 'r3_q2',
              prompt: 'The news was broadcast so quickly _______ millions of viewers learned about the event instantly.',
              options: ['that', 'such that', 'in order that', 'as though'],
              correctIndex: 0,
              explanation: 'Cấu trúc so ... that chỉ kết quả.',
            ),
          ],
          listeningQuestions: [
            ReviewQuestion(
              id: 'r3_l1',
              prompt: 'How is AI helping wildlife rangers according to the recording?',
              options: ['By feeding animals', 'By detecting poachers through acoustic sensors and drones', 'By predicting weather', 'By building fences'],
              correctIndex: 1,
              explanation: 'Cảm biến âm thanh và thiết bị bay thông minh phát hiện kẻ săn trộm.',
            ),
          ],
          readingQuestions: [
            ReviewQuestion(
              id: 'r3_r1',
              prompt: 'What advantage do drones with computer vision offer in wildlife monitoring?',
              options: ['They disturb animal habitats', 'They work only during daytime', 'They monitor habitats without disturbing animals', 'They capture poachers physically'],
              correctIndex: 2,
              explanation: 'Theo bài: "monitor endangered habitats without disturbing animals".',
            ),
          ],
          speakingTask: 'Thảo luận về tác động tích cực và tiêu cực của mạng xã hội đối với lối sống của giới trẻ.',
          writingPrompt: 'Viết bài văn ngắn (120 - 150 từ) đề xuất các giải pháp bảo vệ các loài động vật có nguy cơ tuyệt chủng.',
          writingOutline: '1. Mở đoạn: Tình trạng suy giảm đa dạng sinh học.\n2. Thân đoạn: Các biện pháp (luật pháp, công nghệ AI, nâng cao nhận thức).\n3. Kết đoạn: Lời kêu gọi hành động chung.',
        );
      case 4:
      default:
        return const ReviewInfo(
          reviewNumber: 4,
          title: 'Review 4 (Units 9 - 10)',
          unitsCovered: 'Career Paths • Lifelong Learning',
          pages: '140 - 143',
          listeningTrackId: 'rev4_listen',
          listeningAsset: 'assets/audio/global_success_12/listening/014.mp3',
          pronunciationFocus: 'Ngữ điệu trong danh sách liệt kê & câu hỏi lựa chọn',
          grammarFocus: 'Câu điều kiện hỗn hợp; Đảo ngữ với phó từ phủ định; Câu chẻ (Cleft sentences)',
          readingPassage: 'Lifelong learning is no longer an optional luxury; it has become an essential prerequisite for enduring professional success. In a rapidly changing technological landscape, individuals must continuously cultivate new capabilities, embrace micro-credentials, and maintain an inquisitive mindset throughout their careers.',
          languageQuestions: [
            ReviewQuestion(
              id: 'r4_q1',
              prompt: 'Seldom _______ such rapid technological changes in such a short period.',
              options: ['have we witnessed', 'we have witnessed', 'did we witnessed', 'we witnessed'],
              correctIndex: 0,
              explanation: 'Đảo ngữ với phó từ phủ định "Seldom" đứng đầu câu -> trợ động từ "have" đảo lên trước chủ ngữ "we".',
            ),
            ReviewQuestion(
              id: 'r4_q2',
              prompt: 'It was my teacher _______ inspired me to pursue lifelong education.',
              options: ['who', 'which', 'whom', 'whose'],
              correctIndex: 0,
              explanation: 'Cấu trúc câu chẻ nhấn mạnh người: It was + O (người) + who + V.',
            ),
          ],
          listeningQuestions: [
            ReviewQuestion(
              id: 'r4_l1',
              prompt: 'What advice does the career counselor offer to university graduates?',
              options: ['Stop studying after graduation', 'Never stop acquiring new skills and knowledge', 'Only pursue traditional jobs', 'Avoid technology'],
              correctIndex: 1,
              explanation: 'Lời khuyên tiếp tục học hỏi không ngừng sau khi tốt nghiệp.',
            ),
          ],
          readingQuestions: [
            ReviewQuestion(
              id: 'r4_r1',
              prompt: 'Why is lifelong learning considered essential in modern careers?',
              options: ['Because college degrees never expire', 'Because technology changes rapidly, requiring new capabilities', 'Because exams are easier', 'Because companies do not care about skills'],
              correctIndex: 1,
              explanation: 'Do công nghệ thay đổi nhanh chóng, đòi hỏi liên tục bồi dưỡng năng lực mới.',
            ),
          ],
          speakingTask: 'Thảo luận về kế hoạch học tập của bạn sau khi hoàn thành kỳ thi Tốt nghiệp THPT.',
          writingPrompt: 'Viết một bài luận ngắn (120 - 150 từ) về tầm quan trọng của việc học tập suốt đời (Lifelong Learning).',
          writingOutline: '1. Mở đoạn: Định nghĩa học tập suốt đời.\n2. Thân đoạn: Tác động đến sự nghiệp, tư duy và khả năng thích ứng.\n3. Kết đoạn: Cam kết phát triển bản thân của bạn.',
        );
    }
  }
}
