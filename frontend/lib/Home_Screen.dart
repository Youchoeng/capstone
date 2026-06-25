import 'package:flutter/material.dart';
import 'Home_Settings_Screen.dart';
import 'Home_Add_Screen.dart';
import 'Home_Schedule_Model.dart';
import 'Home_Timeline_Tile.dart';

class HomeScreen extends StatefulWidget {
  final String userName;

  const HomeScreen({super.key, required this.userName});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _selectedDate = DateTime.now();
  final List<ScheduleItem> _customSchedules = [];

  bool _isDeleteMode = false;
  final Set<String> _selectedScheduleIds = {};

  final Set<String> _deletedDefaultScheduleKeys = {};

  final int _stepGoal = 5000;
  final List<int> _weeklySteps = [4200, 5100, 3800, 6000, 4500, 2000, 3500];

  Widget _buildWeeklyStepChart() {
    int maxSteps = _stepGoal;
    for (int s in _weeklySteps) {
      if (s > maxSteps) maxSteps = s;
    }

    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.blue[800]?.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (index) {
          final steps = _weeklySteps[index];
          final isToday = index == 6;
          final isGoalMet = steps >= _stepGoal;

          final double barHeight = (steps / maxSteps) * 70;
          final date = DateTime.now().subtract(Duration(days: 6 - index));
          final weekday = _weekdayLabel(date.weekday);

          final formattedSteps = steps.toString().replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},',
          );

          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                formattedSteps,
                style: TextStyle(
                  color: isToday ? Colors.yellow : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 20,
                height: barHeight == 0 ? 4 : barHeight,
                decoration: BoxDecoration(
                  color: isToday
                      ? Colors.yellow
                      : (isGoalMet ? Colors.greenAccent : Colors.white54),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isToday ? '오늘' : weekday,
                style: TextStyle(
                  color: isToday ? Colors.yellow : Colors.white,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const HomeSettingsScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.ease;

          final tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  DateTime _baseDateForRecurring() {
    final today = _dateOnly(DateTime.now());
    final selected = _dateOnly(_selectedDate);
    return selected.isBefore(today) ? today : selected;
  }

  Future<void> _openAddScreen() async {
    if (_isDeleteMode) return;

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (context) => const HomeAddScreen()),
    );

    if (!mounted || result == null) return;

    final type = (result['type'] ?? '').toString();

    if (type == 'medicine') {
      final medicineName = (result['medicineName'] ?? '').toString().trim();
      final time = (result['time'] ?? '').toString().trim();
      final days = List<String>.from(result['days'] ?? const []);

      if (medicineName.isEmpty || time.isEmpty || days.isEmpty) return;

      final today = _dateOnly(DateTime.now());

      final newItem = ScheduleItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: '$medicineName 복용',
        time: time,
        repeatDays: days,
        isCustom: true,
        startDate: today,
      );

      setState(() {
        _customSchedules.add(newItem);

        final baseDate = _baseDateForRecurring();
        final baseDayLabel = _weekdayLabel(baseDate.weekday);

        if (days.contains(baseDayLabel)) {
          _selectedDate = baseDate;
        } else {
          _selectedDate = _findNextMatchingDate(baseDate, days);
        }
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('복약 일정이 홈 화면에 추가되었습니다.')));
      return;
    }

    if (type == 'appointment') {
      final placeName = (result['placeName'] ?? '').toString().trim();
      final time = (result['time'] ?? '').toString().trim();
      final repeatType = (result['repeatType'] ?? '').toString();
      final days = List<String>.from(result['days'] ?? const []);
      final dateString = (result['date'] ?? '').toString().trim();

      if (placeName.isEmpty || time.isEmpty || repeatType.isEmpty) return;

      if (repeatType == 'temporary') {
        final parsedDate = DateTime.tryParse(dateString);
        if (parsedDate == null) return;

        final targetDate = _dateOnly(parsedDate);

        final newItem = ScheduleItem(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: '$placeName 가기',
          time: time,
          specificDate: targetDate,
          isCustom: true,
        );

        setState(() {
          _customSchedules.add(newItem);
          _selectedDate = targetDate;
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('약속 일정이 홈 화면에 추가되었습니다.')));
        return;
      }

      if (repeatType == 'regular') {
        if (days.isEmpty) return;

        final today = _dateOnly(DateTime.now());

        final newItem = ScheduleItem(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: '$placeName 가기',
          time: time,
          repeatDays: days,
          isCustom: true,
          startDate: today,
        );

        setState(() {
          _customSchedules.add(newItem);

          final baseDate = _baseDateForRecurring();
          final baseDayLabel = _weekdayLabel(baseDate.weekday);

          if (days.contains(baseDayLabel)) {
            _selectedDate = baseDate;
          } else {
            _selectedDate = _findNextMatchingDate(baseDate, days);
          }
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('약속 일정이 홈 화면에 추가되었습니다.')));
      }
    }
  }

  void _cancelDeleteMode() {
    setState(() {
      _isDeleteMode = false;
      _selectedScheduleIds.clear();
    });
  }

  Future<void> _toggleDeleteModeOrDeleteSelected() async {
    final visibleSchedules = _getSchedulesForDate(_selectedDate);

    if (!_isDeleteMode) {
      if (visibleSchedules.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('삭제할 일정이 없습니다.')));
        return;
      }

      setState(() {
        _isDeleteMode = true;
        _selectedScheduleIds.clear();
      });
      return;
    }

    if (_selectedScheduleIds.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('삭제할 일정을 선택해주세요.')));
      return;
    }

    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            '일정 삭제',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text('선택한 일정을 정말 삭제하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('삭제', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;
    if (!mounted) return;

    setState(() {
      final visibleById = {for (final item in visibleSchedules) item.id: item};

      for (final selectedId in _selectedScheduleIds) {
        final item = visibleById[selectedId];
        if (item == null) continue;

        if (item.isCustom) {
          _customSchedules.removeWhere((e) => e.id == item.id);
        } else {
          _deletedDefaultScheduleKeys.add(
            _buildDefaultOccurrenceKey(item, _selectedDate),
          );
        }
      }

      _selectedScheduleIds.clear();
      _isDeleteMode = false;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('선택한 일정이 삭제되었습니다.')));
  }

  void _toggleScheduleSelection(String scheduleId) {
    setState(() {
      if (_selectedScheduleIds.contains(scheduleId)) {
        _selectedScheduleIds.remove(scheduleId);
      } else {
        _selectedScheduleIds.add(scheduleId);
      }
    });
  }

  String _buildDefaultOccurrenceKey(ScheduleItem item, DateTime date) {
    return '${item.id}_${date.year}_${date.month}_${date.day}';
  }

  List<ScheduleItem> _getCustomSchedulesForDate(DateTime date) {
    final weekday = _weekdayLabel(date.weekday);
    final targetDate = _dateOnly(date);

    return _customSchedules.where((item) {
      if (item.specificDate != null) {
        return _isSameDate(item.specificDate!, targetDate);
      }

      if (item.repeatDays != null && item.repeatDays!.isNotEmpty) {
        if (!item.repeatDays!.contains(weekday)) return false;

        if (item.startDate != null) {
          final start = _dateOnly(item.startDate!);
          if (targetDate.isBefore(start)) return false;
        }

        return true;
      }

      return false;
    }).toList();
  }

  DateTime _findNextMatchingDate(DateTime fromDate, List<String> days) {
    for (int i = 0; i < 7; i++) {
      final candidate = fromDate.add(Duration(days: i));
      if (days.contains(_weekdayLabel(candidate.weekday))) {
        return candidate;
      }
    }
    return fromDate;
  }

  String _weekdayLabel(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return '월';
      case DateTime.tuesday:
        return '화';
      case DateTime.wednesday:
        return '수';
      case DateTime.thursday:
        return '목';
      case DateTime.friday:
        return '금';
      case DateTime.saturday:
        return '토';
      case DateTime.sunday:
        return '일';
      default:
        return '';
    }
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _goToPreviousDay() {
    setState(() {
      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
      _selectedScheduleIds.clear();
      _isDeleteMode = false;
    });
  }

  void _goToNextDay() {
    setState(() {
      _selectedDate = _selectedDate.add(const Duration(days: 1));
      _selectedScheduleIds.clear();
      _isDeleteMode = false;
    });
  }

  String _getRelativeDayText(DateTime date) {
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);

    final difference = target.difference(today).inDays;

    switch (difference) {
      case -2:
        return '그저께';
      case -1:
        return '어제';
      case 0:
        return '오늘';
      case 1:
        return '내일';
      case 2:
        return '모레';
      case 3:
        return '글피';
      default:
        return '';
    }
  }

  String _formatDate(DateTime date) {
    final relativeText = _getRelativeDayText(date);

    if (relativeText.isEmpty) {
      return '${date.month}월 ${date.day}일';
    }

    return '${date.month}월 ${date.day}일 · $relativeText';
  }

  List<ScheduleItem> _getDefaultSchedulesForDate(DateTime date) {
    switch (date.weekday) {
      case DateTime.monday:
        return const [
          ScheduleItem(id: 'default_mon_1', title: '아침약 복용', time: '오전 8:00'),
          ScheduleItem(id: 'default_mon_2', title: '병원 방문', time: '오전 11:00'),
          ScheduleItem(id: 'default_mon_3', title: '점심약 복용', time: '오후 1:00'),
          ScheduleItem(id: 'default_mon_4', title: '저녁약 복용', time: '오후 7:00'),
        ];
      case DateTime.tuesday:
        return const [
          ScheduleItem(id: 'default_tue_1', title: '아침약 복용', time: '오전 8:00'),
          ScheduleItem(id: 'default_tue_2', title: '산책', time: '오전 10:30'),
          ScheduleItem(id: 'default_tue_3', title: '저녁약 복용', time: '오후 7:00'),
        ];
      case DateTime.wednesday:
        return const [
          ScheduleItem(id: 'default_wed_1', title: '아침약 복용', time: '오전 8:00'),
          ScheduleItem(id: 'default_wed_2', title: '건강 체크', time: '오후 2:00'),
          ScheduleItem(id: 'default_wed_3', title: '저녁약 복용', time: '오후 7:00'),
        ];
      case DateTime.thursday:
        return const [
          ScheduleItem(id: 'default_thu_1', title: '아침약 복용', time: '오전 8:00'),
          ScheduleItem(id: 'default_thu_2', title: '병원 방문', time: '오후 3:00'),
          ScheduleItem(id: 'default_thu_3', title: '저녁약 복용', time: '오후 7:00'),
        ];
      case DateTime.friday:
        return const [
          ScheduleItem(id: 'default_fri_1', title: '아침약 복용', time: '오전 8:00'),
          ScheduleItem(id: 'default_fri_2', title: '장보기', time: '오후 12:00'),
          ScheduleItem(id: 'default_fri_3', title: '점심약 복용', time: '오후 1:00'),
          ScheduleItem(id: 'default_fri_4', title: '저녁약 복용', time: '오후 7:00'),
        ];
      case DateTime.saturday:
        return const [
          ScheduleItem(id: 'default_sat_1', title: '아침약 복용', time: '오전 8:30'),
          ScheduleItem(id: 'default_sat_2', title: '가족 약속', time: '오후 4:00'),
          ScheduleItem(id: 'default_sat_3', title: '저녁약 복용', time: '오후 7:00'),
        ];
      case DateTime.sunday:
        return const [
          ScheduleItem(id: 'default_sun_1', title: '아침약 복용', time: '오전 8:30'),
          ScheduleItem(id: 'default_sun_2', title: '외출 일정', time: '오전 10:00'),
          ScheduleItem(id: 'default_sun_3', title: '저녁약 복용', time: '오후 7:00'),
        ];
      default:
        return const [];
    }
  }

  List<ScheduleItem> _getSchedulesForDate(DateTime date) {
    final defaultSchedules = _getDefaultSchedulesForDate(date)
        .where(
          (item) => !_deletedDefaultScheduleKeys.contains(
            _buildDefaultOccurrenceKey(item, date),
          ),
        )
        .toList();

    final customSchedules = _getCustomSchedulesForDate(date);

    final allSchedules = [...defaultSchedules, ...customSchedules];
    allSchedules.sort((a, b) => a.timeToMinutes().compareTo(b.timeToMinutes()));

    return allSchedules;
  }

  @override
  Widget build(BuildContext context) {
    final schedules = _getSchedulesForDate(_selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '안녕하세요 ${widget.userName} 님!',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue[100],
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: TextButton(
                onPressed: () => _openSettings(context),
                child: const Text(
                  '설정',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: Colors.blue[600],
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 24.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        '내 건강 비서',
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Icon(
                        Icons.directions_walk,
                        color: Colors.white,
                        size: 28,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        '3,500',
                        style: TextStyle(
                          fontSize: 42,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 4.0),
                        child: Text(
                          '걸음',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Text(
                          '목표 $_stepGoal',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ),
                  _buildWeeklyStepChart(),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              color: Colors.blue[700],
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '복약 및 일정',
                            style: TextStyle(
                              fontSize: 20,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _isDeleteMode
                              ? _cancelDeleteMode
                              : _openAddScreen,
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: _isDeleteMode
                                ? Colors.black
                                : Colors.blue,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: Icon(_isDeleteMode ? Icons.close : Icons.add),
                          label: Text(
                            _isDeleteMode ? '취소' : '추가',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: _toggleDeleteModeOrDeleteSelected,
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text(
                            '삭제',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: _goToPreviousDay,
                          icon: const Icon(
                            Icons.chevron_left,
                            color: Colors.white,
                            size: 34,
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              _formatDate(_selectedDate),
                              style: const TextStyle(
                                fontSize: 22,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _goToNextDay,
                          icon: const Icon(
                            Icons.chevron_right,
                            color: Colors.white,
                            size: 34,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (schedules.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: Center(
                        child: Text(
                          '일정이 없습니다.',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        children: List.generate(schedules.length, (index) {
                          final item = schedules[index];
                          final isLast = index == schedules.length - 1;

                          return TimelineScheduleTile(
                            key: ValueKey(
                              '${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}-${item.id}-$index',
                            ),
                            scheduleId: item.id,
                            time: item.time,
                            title: item.title,
                            isLast: isLast,
                            isDeleteMode: _isDeleteMode,
                            isSelected: _selectedScheduleIds.contains(item.id),
                            onSelectTap: () =>
                                _toggleScheduleSelection(item.id),
                          );
                        }),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
