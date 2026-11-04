import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/interest_topic.dart';
import 'interest_controller.dart';
import 'interest_topic_detail_screen.dart';

/// Màn hình Khám phá Thư viện Chủ đề Sở thích Đa dạng (Phong cách Quizlet Explore x Duolingo)
class InterestTopicsScreen extends StatelessWidget {
  const InterestTopicsScreen({super.key});

  IconData _getIconData(String name) {
    switch (name) {
      case 'sports_soccer_rounded':
        return Icons.sports_soccer_rounded;
      case 'fitness_center_rounded':
        return Icons.fitness_center_rounded;
      case 'sports_esports_rounded':
        return Icons.sports_esports_rounded;
      case 'local_cafe_rounded':
        return Icons.local_cafe_rounded;
      case 'restaurant_rounded':
        return Icons.restaurant_rounded;
      case 'shopping_bag_rounded':
        return Icons.shopping_bag_rounded;
      case 'movie_filter_rounded':
        return Icons.movie_filter_rounded;
      case 'music_note_rounded':
        return Icons.music_note_rounded;
      case 'flight_takeoff_rounded':
        return Icons.flight_takeoff_rounded;
      case 'hotel_rounded':
        return Icons.hotel_rounded;
      case 'waving_hand_rounded':
        return Icons.waving_hand_rounded;
      case 'groups_rounded':
        return Icons.groups_rounded;
      case 'terminal_rounded':
        return Icons.terminal_rounded;
      case 'pets_rounded':
        return Icons.pets_rounded;
      default:
        return Icons.auto_awesome_rounded;
    }
  }

  Color _getCategoryColor(String categoryId) {
    switch (categoryId) {
      case 'cat_sports':
        return const Color(0xFF16A34A); // Xanh lá thể thao
      case 'cat_food':
        return const Color(0xFFF59E0B); // Vàng cam ẩm thực
      case 'cat_entertainment':
        return const Color(0xFFEC4899); // Hồng giải trí
      case 'cat_travel':
        return const Color(0xFF0EA5E9); // Xanh biển du lịch
      case 'cat_social':
        return const Color(0xFF8B5CF6); // Tím giao tiếp
      case 'cat_career':
        return const Color(0xFF2563EB); // Xanh dương công nghệ
      case 'cat_nature':
        return const Color(0xFF10B981); // Xanh ngọc thú cưng
      default:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ChangeNotifierProvider<InterestController>(
      create: (_) => InterestController(),
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
            'Học theo sở thích',
            style: TextStyle(
              fontFamily: 'BeVietnamPro',
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          centerTitle: true,
        ),
        body: Consumer<InterestController>(
          builder: (context, controller, child) {
            if (controller.isLoading) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)));
            }

            final topics = controller.filteredTopics;

            return SafeArea(
              child: Column(
                children: [
                  // 1. Thanh tìm kiếm chủ đề
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: TextField(
                      onChanged: controller.setSearchQuery,
                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        hintText: 'Tìm chủ đề (bóng đá, cafe, du lịch, code...)',
                        hintStyle: TextStyle(fontSize: 13.5, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                        prefixIcon: Icon(Icons.search_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E2430) : Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.8),
                        ),
                      ),
                    ),
                  ),

                  // 2. Thanh lọc ngang theo danh mục
                  SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      children: [
                        _buildCategoryChip(context, controller, 'all', 'Tất cả'),
                        _buildCategoryChip(context, controller, 'cat_sports', '⚽ Thể thao'),
                        _buildCategoryChip(context, controller, 'cat_food', '🍕 Ẩm thực & Cafe'),
                        _buildCategoryChip(context, controller, 'cat_travel', '✈️ Du lịch'),
                        _buildCategoryChip(context, controller, 'cat_entertainment', '🎬 Giải trí'),
                        _buildCategoryChip(context, controller, 'cat_social', '💬 Giao tiếp'),
                        _buildCategoryChip(context, controller, 'cat_career', '🎓 Công nghệ'),
                        _buildCategoryChip(context, controller, 'cat_nature', '🐾 Thú cưng'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),

                  // 3. Danh sách thẻ chủ đề
                  Expanded(
                    child: topics.isEmpty
                        ? const Center(
                            child: Text(
                              'Không tìm thấy chủ đề phù hợp.',
                              style: TextStyle(color: Color(0xFF64748B)),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            itemCount: topics.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final topic = topics[index];
                              return _buildTopicCard(context, topic);
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCategoryChip(BuildContext context, InterestController controller, String catId, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = controller.selectedCategory == catId;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => controller.setCategory(catId),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF1E2430) : Colors.white),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'BeVietnamPro',
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 12.5,
                color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopicCard(BuildContext context, InterestTopic topic) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = _getCategoryColor(topic.categoryId);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2430) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0x20000000) : const Color(0x080F172A),
            offset: const Offset(0, 3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => InterestTopicDetailScreen(topic: topic),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon tròn theo màu danh mục
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Icon(_getIconData(topic.iconName), color: iconColor, size: 26),
                  ),
                ),
                const SizedBox(width: 14),

                // Nội dung chủ đề
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              topic.title,
                              style: TextStyle(
                                fontFamily: 'BeVietnamPro',
                                fontWeight: FontWeight.w800,
                                fontSize: 15.5,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              topic.level,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        topic.titleVi,
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: iconColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        topic.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
