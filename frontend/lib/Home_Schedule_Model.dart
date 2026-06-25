class ScheduleItem {
  final String id;
  final String title;
  final String time;
  final DateTime? specificDate;
  final List<String>? repeatDays;
  final bool isCustom;
  final DateTime? startDate;

  const ScheduleItem({
    required this.id,
    required this.title,
    required this.time,
    this.specificDate,
    this.repeatDays,
    this.isCustom = false,
    this.startDate,
  });

  int timeToMinutes() {
    final value = time.trim();

    if (value.startsWith('오전') || value.startsWith('오후')) {
      final isAm = value.startsWith('오전');
      final timePart =
      value.replaceFirst('오전', '').replaceFirst('오후', '').trim();
      final parts = timePart.split(':');

      int hour = int.tryParse(parts[0]) ?? 0;
      final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;

      if (isAm) {
        if (hour == 12) hour = 0;
      } else {
        if (hour != 12) hour += 12;
      }

      return hour * 60 + minute;
    }

    final parts = value.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return hour * 60 + minute;
  }
}