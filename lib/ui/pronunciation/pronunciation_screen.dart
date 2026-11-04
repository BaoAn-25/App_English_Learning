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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ChangeNotifierProvider<PronunciationController>(
      create: (_) => PronunciationController(),
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF121620) : const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF1E2430) : Colors.white,
          elevation: 0.5,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: isDark ? Colors.white : const Color(0xFF0F172A)),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Phát âm IPA',
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          centerTitle: true,
        ),
        body: Consumer<PronunciationController>(
          builder: (context, controller, child) {
            if (controller.isLoading) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF2563EB)),
              );
            }

            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Tiêu đề & Lời dẫn chuẩn Duolingo
                    Text(
                      'Cùng học phát âm tiếng Anh!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tập nghe và học phát âm các âm trong tiếng Anh',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 13.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Nút BẮT ĐẦU +10 KN (Màu xanh Cyan Duolingo)
                    AppButton(
                      label: 'BẮT ĐẦU +10 XP',
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
                    _buildSectionHeader(context, 'Nguyên âm'),
                    const SizedBox(height: 12),
                    _buildSoundGrid(
                      sounds: [...controller.vowels, ...controller.diphthongs],
                      controller: controller,
                    ),
                    const SizedBox(height: 32),

                    // --- PHẦN 2: PHỤ ÂM ---
                    _buildSectionHeader(context, 'Phụ âm'),
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

  Widget _buildSectionHeader(BuildContext context, String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(child: Divider(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), thickness: 1.5)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            title,
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
        ),
        Expanded(child: Divider(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), thickness: 1.5)),
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
          context,
          sound: sound,
          isPlaying: isPlaying,
          onTap: () => controller.speakSound(sound),
          onLongPress: () => _showSoundDetailModal(context, sound, controller),
        );
      },
    );
  }

  Widget _buildIpaCard(
    BuildContext context, {
    required IpaSound sound,
    required bool isPlaying,
    required VoidCallback onTap,
    required VoidCallback onLongPress,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasMastery = sound.masteryLevel > 0;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isPlaying
              ? (isDark ? const Color(0xFF1E3A8A).withAlpha(120) : const Color(0xFFEFF6FF))
              : (isDark ? const Color(0xFF1E2430) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPlaying
                ? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB))
                : (hasMastery ? const Color(0xFF16A34A) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
            width: isPlaying ? 2.0 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? const Color(0x20000000) : (isPlaying
                  ? const Color(0xFF2563EB).withValues(alpha: 0.18)
                  : const Color(0x0A0F172A)),
              offset: const Offset(0, 2),
              blurRadius: 4,
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
                color: isPlaying
                    ? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB))
                    : (isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
            ),
            const SizedBox(height: 2),

            // Từ ví dụ
            Text(
              sound.exampleWord,
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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
                color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: (sound.masteryLevel / 100).clamp(0.08, 1.0),
                  child: Container(
                    color: sound.masteryLevel >= 60
                        ? const Color(0xFF16A34A)
                        : (sound.masteryLevel > 0 ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1)),
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
                    color: const Color(0xFFE2E8F0),
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
                      color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF2563EB)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      sound.symbol,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF2563EB),
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
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          sound.isVowel
                              ? 'Nguyên âm đơn'
                              : (sound.isDiphthong ? 'Nguyên âm đôi' : 'Phụ âm'),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.volume_up_rounded, color: Color(0xFF2563EB), size: 28),
                    onPressed: () => controller.speakSound(sound),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
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
                          color: Color(0xFF0F172A),
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

