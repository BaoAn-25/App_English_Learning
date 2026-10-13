class Topic {
  final String id;
  final int grade;
  final String title;
  final int order;

  const Topic({
    required this.id,
    required this.grade,
    required this.title,
    required this.order,
  });

  factory Topic.fromMap(Map<String, dynamic> map) {
    return Topic(
      id: map['id'] as String,
      grade: (map['grade'] as num).toInt(),
      title: map['title'] as String,
      order: (map['order'] as num).toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'grade': grade,
      'title': title,
      'order': order,
    };
  }
}
