class InterestTopic {
  final String id;
  final String categoryId;
  final String categoryName;
  final String title;
  final String titleVi;
  final String iconName;
  final String description;
  final int order;
  final String level;
  final int wordCount;

  const InterestTopic({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.title,
    required this.titleVi,
    required this.iconName,
    required this.description,
    required this.order,
    this.level = 'A1-B1',
    this.wordCount = 0,
  });

  factory InterestTopic.fromMap(Map<String, dynamic> map, {int wordCount = 0}) {
    return InterestTopic(
      id: map['id'] as String,
      categoryId: map['categoryId'] as String,
      categoryName: map['categoryName'] as String,
      title: map['title'] as String,
      titleVi: map['titleVi'] as String,
      iconName: map['iconName'] as String,
      description: map['description'] as String? ?? '',
      order: (map['order'] as num?)?.toInt() ?? 0,
      level: map['level'] as String? ?? 'A1-B1',
      wordCount: wordCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'title': title,
      'titleVi': titleVi,
      'iconName': iconName,
      'description': description,
      'order': order,
      'level': level,
    };
  }
}
