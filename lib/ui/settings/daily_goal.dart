const defaultDailyGoal = 20;

int? validDailyGoal(String? value) {
  final goal = int.tryParse(value?.trim() ?? '');
  return goal != null && goal >= 1 && goal <= 200 ? goal : null;
}
