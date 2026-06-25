import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class HomeAddAppointmentScreen extends StatefulWidget {
  const HomeAddAppointmentScreen({super.key});

  @override
  State<HomeAddAppointmentScreen> createState() =>
      _HomeAddAppointmentScreenState();
}

class _HomeAddAppointmentScreenState extends State<HomeAddAppointmentScreen> {
  TimeOfDay? _selectedTime;
  DateTime? _selectedDate;
  final TextEditingController _placeController = TextEditingController();

  final List<String> _days = ['월', '화', '수', '목', '금', '토', '일'];
  final Set<String> _selectedDays = {};

  String _repeatType = 'temporary'; // temporary: 한 번만 / regular: 반복해서

  bool get _isEverydaySelected => _selectedDays.length == _days.length;

  @override
  void dispose() {
    _placeController.dispose();
    super.dispose();
  }

  void _pickTimeWithCupertinoWheel() {
    DateTime tempDateTime = DateTime(
      2024,
      1,
      1,
      _selectedTime?.hour ?? 9,
      _selectedTime?.minute ?? 0,
    );

    showCupertinoModalPopup(
      context: context,
      builder: (context) {
        return Container(
          height: 320,
          color: Colors.white,
          child: Column(
            children: [
              Container(
                height: 60,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Color(0xFFE0E0E0),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        '취소',
                        style: TextStyle(fontSize: 20),
                      ),
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          '시간 선택',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        setState(() {
                          _selectedTime = TimeOfDay(
                            hour: tempDateTime.hour,
                            minute: tempDateTime.minute,
                          );
                        });
                        Navigator.pop(context);
                      },
                      child: const Text(
                        '완료',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: false,
                  initialDateTime: tempDateTime,
                  onDateTimeChanged: (DateTime newDateTime) {
                    tempDateTime = newDateTime;
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.blue),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return '시간을 선택해주세요';

    final isAm = time.hour < 12;
    final period = isAm ? '오전' : '오후';

    int hour = time.hour % 12;
    if (hour == 0) hour = 12;

    final minute = time.minute.toString().padLeft(2, '0');

    return '$period $hour:$minute';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '날짜를 선택해주세요';
    return '${date.year}년 ${date.month}월 ${date.day}일';
  }

  void _toggleDay(String day) {
    setState(() {
      if (_selectedDays.contains(day)) {
        _selectedDays.remove(day);
      } else {
        _selectedDays.add(day);
      }
    });
  }

  void _toggleEveryday() {
    setState(() {
      if (_isEverydaySelected) {
        _selectedDays.clear();
      } else {
        _selectedDays
          ..clear()
          ..addAll(_days);
      }
    });
  }

  void _setRepeatType(String type) {
    setState(() {
      _repeatType = type;
    });
  }

  Widget _buildDayButton(String day) {
    final isSelected = _selectedDays.contains(day);

    return GestureDetector(
      onTap: () => _toggleDay(day),
      child: Container(
        width: 56,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.blue.shade300,
            width: 2,
          ),
        ),
        child: Text(
          day,
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.blue,
          ),
        ),
      ),
    );
  }

  void _saveAppointmentSchedule() {
    if (_repeatType == 'temporary' && _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('날짜를 선택해주세요.')),
      );
      return;
    }

    if (_repeatType == 'regular' && _selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('요일을 한 개 이상 선택해주세요.')),
      );
      return;
    }

    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('시간을 선택해주세요.')),
      );
      return;
    }

    if (_placeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('장소를 입력해주세요.')),
      );
      return;
    }

    Navigator.pop(context, {
      'type': 'appointment',
      'time': _formatTime(_selectedTime),
      'repeatType': _repeatType,
      'date': _selectedDate?.toIso8601String(),
      'days': _selectedDays.toList(),
      'placeName': _placeController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final isTemporary = _repeatType == 'temporary';
    final isRegular = _repeatType == 'regular';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '약속 장소 추가',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue[100],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '어떻게 추가할까요?',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _RepeatTypeButton(
                            title: '한 번만',
                            isSelected: isTemporary,
                            onTap: () => _setRepeatType('temporary'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _RepeatTypeButton(
                            title: '반복해서',
                            isSelected: isRegular,
                            onTap: () => _setRepeatType('regular'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (isTemporary) ...[
                      const Text(
                        '날짜를 선택해주세요',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.blue.shade200,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_month,
                                size: 28,
                                color: Colors.blue,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _formatDate(_selectedDate),
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const Icon(Icons.chevron_right, size: 28),
                            ],
                          ),
                        ),
                      ),
                    ],

                    if (isRegular) ...[
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              '요일을 선택해주세요',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: _toggleEveryday,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: _isEverydaySelected
                                    ? Colors.blue
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.blue.shade300,
                                  width: 2,
                                ),
                              ),
                              child: Text(
                                '매일',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: _isEverydaySelected
                                      ? Colors.white
                                      : Colors.blue,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildDayButton('월'),
                          const SizedBox(width: 8),
                          _buildDayButton('화'),
                          const SizedBox(width: 8),
                          _buildDayButton('수'),
                          const SizedBox(width: 8),
                          _buildDayButton('목'),
                          const SizedBox(width: 8),
                          _buildDayButton('금'),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildDayButton('토'),
                          const SizedBox(width: 8),
                          _buildDayButton('일'),
                        ],
                      ),
                    ],

                    const SizedBox(height: 16),
                    const Text(
                      '몇시에 가시나요?',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _pickTimeWithCupertinoWheel,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.blue.shade200,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              size: 28,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _formatTime(_selectedTime),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Icon(Icons.expand_more, size: 28),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    const Text(
                      '어디로 가시나요?',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _placeController,
                      style: const TextStyle(fontSize: 22),
                      decoration: InputDecoration(
                        hintText: '예: 서울아산병원',
                        hintStyle: const TextStyle(fontSize: 20),
                        filled: true,
                        fillColor: Colors.blue[50],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: Colors.blue.shade200,
                            width: 2,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: Colors.blue.shade200,
                            width: 2,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: Colors.blue.shade400,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              color: Colors.white,
              child: SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _saveAppointmentSchedule,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    '저장하기',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RepeatTypeButton extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _RepeatTypeButton({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? Colors.blue : Colors.blue[50],
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.blue.shade300,
              width: 2,
            ),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : Colors.blue,
            ),
          ),
        ),
      ),
    );
  }
}