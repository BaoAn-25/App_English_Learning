import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/ipa_sound.dart';
import '../theme/components/app_button.dart';
import 'minimal_pairs_quiz_screen.dart';
import 'pronunciation_controller.dart';

/// Màn hình Trung tâm Phát âm Tiếng Anh chuẩn Quốc tế IPA phong cách Duolingo
class PronunciationScreen extends StatefulWidget {
  const PronunciationScreen({super.key});

  @override
  State<PronunciationScreen> createState() => _PronunciationScreenState();
}

class _PronunciationScreenState extends State<PronunciationScreen> {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PronunciationController>(
      create: (_) => PronunciationController(),
      child: Scaffold(
        backgroundColor: const Color(0xFF131F24), // Tông màu tối đặc trưng Duolingo
        appBar: AppBar(
          backgroundColor: const Color(0xFF131F24),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white70),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Phát âm IPA',
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: Colors.white,
            ),
          ),
          centerTitle: true,
        ),
        body: Consumer<PronunciationController>(
          builder: (context, controller, child) {
            if (controller.isLoading) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF1CB0F6)),
              );
            }

            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Tiêu đề & Lời dẫn chuẩn Duolingo
                    const Text(
                      'Cùng học phát âm tiếng Anh!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Tập nghe và học phát âm các âm trong tiếng Anh',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 13.5,
                        color: Color(0xFF8E9EA7),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Nút BẮT ĐẦU +10 KN (Màu xanh Cyan Duolingo)
                    AppButton(
                      label: 'BẮT ĐẦU +10 KN',
                      isFullWidth: true,
                      height: 52,
                      variant: AppButtonVariant.primary,
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MinimalPairsQuizScreen(),
                          ),
                        );
                        // Refresh lại tiến độ sau khi làm quiz
                        controller.loadData();
                      },
                    ),
                    const SizedBox(height: 28),

                    // --- PHẦN 1: NGUYÊN ÂM ---
                    _buildSectionHeader('Nguyên âm'),
                    const SizedBox(height: 12),
                    _buildSoundGrid(
                      sounds: [...controller.vowels, ...controller.diphthongs],
                      controller: controller,
                    ),
                    const SizedBox(height: 32),

                    // --- PHẦN 2: PHỤ ÂM ---
                    _buildSectionHeader('Phụ âm'),
                    const SizedBox(height: 12),
                    _buildSoundGrid(
                      sounds: controller.consonants,
                      controller: controller,
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFF2B3A42), thickness: 1.5)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            title,
            style: const TextStyle(
              fontFamily: 'BeVietnamPro',
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: Color(0xFF8E9EA7),
              letterSpacing: 0.5,
            ),
          ),
        ),
        const Expanded(child: Divider(color: Color(0xFF2B3A42), thickness: 1.5)),
      ],
    );
  }

  Widget _buildSoundGrid({
    required List<IpaSound> sounds,
    required PronunciationController controller,
  }) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.05,
      ),
      itemCount: sounds.length,
      itemBuilder: (context, index) {
        final sound = sounds[index];
        final isPlaying = controller.activePlayingSound?.id == sound.id;

        return _buildIpaCard(
          sound: sound,
          isPlaying: isPlaying,
          onTap: () => controller.speakSound(sound),
          onLongPress: () => _showSoundDetailModal(context, sound, controller),
        );
      },
    );
  }

  Widget _buildIpaCard({
    required IpaSound sound,
    required bool isPlaying,
    required VoidCallback onTap,
    required VoidCallback onLongPress,
  }) {
    final hasMastery = sound.masteryLevel > 0;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isPlaying ? const Color(0xFF1CB0F6).withValues(alpha: 0.2) : const Color(0xFF1B2A32),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPlaying
                ? const Color(0xFF1CB0F6)
                : (hasMastery ? const Color(0xFF58CC02) : const Color(0xFF37464F)),
            width: isPlaying ? 2.2 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isPlaying
                  ? const Color(0xFF1CB0F6).withValues(alpha: 0.3)
                  : const Color(0xFF131F24),
              offset: const Offset(0, 3),
              blurRadius: 0,
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ký hiệu IPA
            Text(
              sound.symbol,
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontWeight: FontWeight.w900,
                fontSize: 22,
                color: isPlaying ? const Color(0xFF1CB0F6) : Colors.white,
              ),
            ),
            const SizedBox(height: 2),

            // Từ ví dụ
            Text(
              sound.exampleWord,
              style: const TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF778D97),
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),

            // Thanh tiến độ % độ thuần thục
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Container(
                height: 4,
                width: 38,
                color: const Color(0xFF37464F),
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: (sound.masteryLevel / 100).clamp(0.08, 1.0),
                  child: Container(
                    color: sound.masteryLevel >= 60
                        ? const Color(0xFF58CC02)
                        : (sound.masteryLevel > 0 ? const Color(0xFFFFC800) : const Color(0xFF52656D)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSoundDetailModal(
    BuildContext context,
    IpaSound sound,
    PronunciationController controller,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1B2A32),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFF37464F),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1CB0F6).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF1CB0F6)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      sound.symbol,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1CB0F6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sound.name,
                          style: const TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          sound.isVowel
                              ? 'Nguyên âm đơn'
                              : (sound.isDiphthong ? 'Nguyên âm đôi' : 'Phụ âm'),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF8E9EA7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.volume_up_rounded, color: Color(0xFF1CB0F6), size: 28),
                    onPressed: () => controller.speakSound(sound),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF202F36),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFFFFC800), size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Từ ví dụ: ${sound.exampleWord} ${sound.exampleIpa} (${sound.exampleMeaning})',
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              AppButton(
                label: 'Nghe phát âm từ mẫu',
                isFullWidth: true,
                variant: AppButtonVariant.primary,
                height: 48,
                onPressed: () {
                  controller.speakWord(sound.exampleWord);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}

