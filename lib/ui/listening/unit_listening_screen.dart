import 'package:flutter/material.dart';
import '../../data/app_repository.dart';
import '../../data/audio_repository.dart';
import '../../data/listening_repository.dart';
import '../audio/app_audio_controller.dart';
import '../audio/app_audio_player_widget.dart';
import '../auth/auth_controller.dart';
import '../theme/app_tokens.dart';

class UnitListeningScreen extends StatefulWidget {
  final String lessonKey;
  final String? initialTitle;
  final int? printedPage;

  const UnitListeningScreen({
    super.key,
    required this.lessonKey,
    this.initialTitle,
    this.printedPage,
  });

  @override
  State<UnitListeningScreen> createState() => _UnitListeningScreenState();
}

class _UnitListeningScreenState extends State<UnitListeningScreen> {
  final AudioRepository _audioRepo = AudioRepository.instance;
  final ListeningRepository _listeningRepo = ListeningRepository.instance;
  final AppRepository _appRepo = AppRepository();

  ListeningLesson? _lesson;
  int _currentActivityIndex = 0;
  bool _isLoading = true;
  String? _ownerId;

  // Trạng thái bài làm của activity đang chọn
  final Map<String, String> _userAnswers = {};
  bool _isSubmitted = false;
  int _score = 0;
  bool _showTranscript = false;
  bool _usedTranscript = false;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    // Dừng phát audio ngay khi rời khỏi màn hình
    AppAudioController.instance.stop();
    super.dispose();
  }

  Future<void> _initData() async {
    setState(() => _isLoading = true);

    if (!_audioRepo.isLoaded) {
      await _audioRepo.load();
    }

    _ownerId = await _getEffectiveOwnerId();
    _lesson = _listeningRepo.getLesson(widget.lessonKey);

    if (_lesson != null && _lesson!.activities.isNotEmpty) {
      await _loadActivityProgress(0);
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<String> _getEffectiveOwnerId() async {
    final auth = AuthController.instance;
    if (auth.isAuthenticated && !auth.user.isGuest) {
      return auth.user.id;
    }
    var guestId = await _appRepo.getSetting('guest_session_id');
    if (guestId == null || guestId.isEmpty) {
      guestId = 'guest_${DateTime.now().millisecondsSinceEpoch}';
      await _appRepo.setSetting('guest_session_id', guestId);
    }
    return guestId;
  }

  Future<void> _loadActivityProgress(int index) async {
    if (_lesson == null || index >= _lesson!.activities.length) return;
    final act = _lesson!.activities[index];

    _userAnswers.clear();
    _isSubmitted = false;
    _score = 0;
    _showTranscript = false;
    _usedTranscript = false;

    // Dừng track cũ khi chuyển activity
    await AppAudioController.instance.stop();

    if (_ownerId != null) {
      final sub = await _listeningRepo.getSubmission(
        ownerId: _ownerId!,
        lessonKey: _lesson!.lessonKey,
        activityId: act.activityId,
      );
      if (sub != null) {
        _userAnswers.addAll(sub.answers);
        _score = sub.score;
        _isSubmitted = true;
        _usedTranscript = sub.usedTranscript;
      }
    }

    if (mounted) {
      setState(() {
        _currentActivityIndex = index;
      });
    }
  }

  void _submitAnswers() async {
    if (_lesson == null || _ownerId == null) return;
    final act = _lesson!.activities[_currentActivityIndex];

    int correct = 0;
    for (final item in act.items) {
      final ans = _userAnswers[item.id] ?? '';
      if (ListeningRepository.checkAnswer(item, ans)) {
        correct++;
      }
    }

    setState(() {
      _score = correct;
      _isSubmitted = true;
    });

    await _listeningRepo.saveSubmission(
      ownerId: _ownerId!,
      lessonKey: _lesson!.lessonKey,
      activityId: act.activityId,
      answers: _userAnswers,
      score: correct,
      maxScore: act.items.length,
      usedTranscript: _usedTranscript,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(
          child: CircularProgressIndicator(color: AppTokens.primary),
        ),
      );
    }

    if (_lesson == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Bài học nghe')),
        body: const Center(child: Text('Không tìm thấy nội dung bài học nghe.')),
      );
    }

    final currentAct = _lesson!.activities[_currentActivityIndex];
    final track = _audioRepo.getListeningTrack(
      lessonKey: _lesson!.lessonKey,
      activityNumber: currentAct.activityNumber,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context, true),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _lesson!.title,
              style: const TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            Text(
              'Listening • SGK trang ${_lesson!.printedPage}',
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Tabs chọn Hoạt động (Activity 2, Activity 3...)
            if (_lesson!.activities.length > 1) ...[
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: List.generate(_lesson!.activities.length, (idx) {
                    final act = _lesson!.activities[idx];
                    final isSelected = idx == _currentActivityIndex;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('Hoạt động ${act.activityNumber}'),
                        selected: isSelected,
                        selectedColor: AppTokens.primary,
                        backgroundColor: const Color(0xFFF1F5F9),
                        labelStyle: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : const Color(0xFF475569),
                        ),
                        onSelected: (val) {
                          if (val && idx != _currentActivityIndex) {
                            _loadActivityProgress(idx);
                          }
                        },
                      ),
                    );
                  }),
                ),
              ),
              const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
            ],

            // Nội dung chính có cuộn
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Trình phát âm thanh SGK
                  if (track != null) ...[
                    AppAudioPlayerWidget(
                      track: track,
                      title: 'Audio: ${_lesson!.topic}',
                      subtitle: 'Hoạt động ${currentAct.activityNumber} • SGK trang ${_lesson!.printedPage}',
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Đang cập nhật bản thu MP3 cho hoạt động này.',
                              style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Khung hướng dẫn đề bài SGK
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Hoạt động ${currentAct.activityNumber}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFB45309),
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (_isSubmitted)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _score == currentAct.items.length
                                      ? const Color(0xFFE6F7F0)
                                      : const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Điểm: $_score / ${currentAct.items.length}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _score == currentAct.items.length
                                        ? AppTokens.successGreen
                                        : AppTokens.errorRed,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          currentAct.instruction,
                          style: const TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currentAct.instructionVi,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF64748B),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Danh sách câu hỏi
                  ...List.generate(currentAct.items.length, (idx) {
                    final item = currentAct.items[idx];
                    return _buildQuestionItem(item, idx, currentAct.interactionType);
                  }),

                  const SizedBox(height: 12),

                  // Hộp xem Transcript bài nghe
                  if (currentAct.transcript != null) ...[
                    Card(
                      elevation: 0,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          initiallyExpanded: _showTranscript,
                          onExpansionChanged: (val) {
                            setState(() {
                              _showTranscript = val;
                              if (val) _usedTranscript = true;
                            });
                          },
                          leading: const Icon(Icons.description_outlined, color: AppTokens.primary, size: 20),
                          title: const Text(
                            'Xem Lời thoại bài nghe (Transcript)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    currentAct.transcript!,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      height: 1.5,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                  if (currentAct.transcriptVi != null) ...[
                                    const SizedBox(height: 10),
                                    const Divider(color: Color(0xFFE2E8F0)),
                                    const SizedBox(height: 6),
                                    Text(
                                      currentAct.transcriptVi!,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        height: 1.45,
                                        color: Color(0xFF64748B),
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Nút Nộp bài / Làm lại
                  Row(
                    children: [
                      if (_isSubmitted)
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              setState(() {
                                _isSubmitted = false;
                                _userAnswers.clear();
                              });
                            },
                            child: const Text('Làm lại'),
                          ),
                        ),
                      if (_isSubmitted) const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTokens.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _submitAnswers,
                          child: Text(
                            _isSubmitted ? 'Cập nhật bài làm' : 'Kiểm tra & Nộp bài',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionItem(
    ListeningItem item,
    int index,
    ListeningInteractionType type,
  ) {
    final userAnswer = _userAnswers[item.id] ?? '';
    final isCorrect = _isSubmitted && ListeningRepository.checkAnswer(item, userAnswer);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isSubmitted
              ? (isCorrect ? const Color(0xFF10B981) : const Color(0xFFEF4444))
              : const Color(0xFFE2E8F0),
          width: _isSubmitted ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Prompt
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.prompt,
                  style: const TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              if (_isSubmitted) ...[
                const SizedBox(width: 8),
                Icon(
                  isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: isCorrect ? AppTokens.successGreen : AppTokens.errorRed,
                  size: 20,
                ),
              ],
            ],
          ),

          const SizedBox(height: 10),

          // Tương tác theo loại
          if (type == ListeningInteractionType.singleChoice) ...[
            ...item.options.map((opt) {
              final optKey = opt.trim().split('.').first.trim();
              final isSelected = userAnswer.toUpperCase() == optKey.toUpperCase();
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _isSubmitted
                      ? null
                      : () {
                          setState(() {
                            _userAnswers[item.id] = optKey;
                          });
                        },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? AppTokens.primary : const Color(0xFFE2E8F0),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                          size: 16,
                          color: isSelected ? AppTokens.primary : const Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            opt,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFF334155),
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ] else if (type == ListeningInteractionType.trueFalse) ...[
            Row(
              children: ['T', 'F'].map((val) {
                final isSelected = userAnswer.toUpperCase() == val;
                final label = val == 'T' ? 'True (Đúng)' : 'False (Sai)';
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: val == 'T' ? 8 : 0),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: _isSubmitted
                          ? null
                          : () {
                              setState(() {
                                _userAnswers[item.id] = val;
                              });
                            },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? AppTokens.primary : const Color(0xFFE2E8F0),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? AppTokens.primary : const Color(0xFF475569),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ] else if (type == ListeningInteractionType.gapFill ||
              type == ListeningInteractionType.ordering) ...[
            TextFormField(
              initialValue: userAnswer,
              enabled: !_isSubmitted,
              decoration: InputDecoration(
                hintText: type == ListeningInteractionType.ordering
                    ? 'Nhập số thứ tự (ví dụ: 1, 2...)'
                    : 'Nhập câu trả lời vào đây...',
                hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              onChanged: (val) {
                _userAnswers[item.id] = val;
              },
            ),
          ],

          // Lời giải và căn cứ bài nghe khi đã nộp
          if (_isSubmitted) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isCorrect ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Đáp án đúng: ${item.answer}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: isCorrect ? const Color(0xFF166534) : const Color(0xFF991B1B),
                    ),
                  ),
                  if (item.explanationVi != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.explanationVi!,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

