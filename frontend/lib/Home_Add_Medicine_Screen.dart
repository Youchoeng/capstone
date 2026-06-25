import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class HomeAddMedicineScreen extends StatefulWidget {
  const HomeAddMedicineScreen({super.key});

  @override
  State<HomeAddMedicineScreen> createState() => _HomeAddMedicineScreenState();
}

class _HomeAddMedicineScreenState extends State<HomeAddMedicineScreen> {
  TimeOfDay? _selectedTime;
  final TextEditingController _medicineController = TextEditingController();

  final List<String> _days = ['월', '화', '수', '목', '금', '토', '일'];
  final Set<String> _selectedDays = {};

  bool get _isEverydaySelected => _selectedDays.length == _days.length;

  @override
  void dispose() {
    _medicineController.dispose();
    super.dispose();
  }

  void _pickTimeWithCupertinoWheel() {
    DateTime tempDateTime = DateTime(
      2024,
      1,
      1,
      _selectedTime?.hour ?? 8,
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

  String _formatTime(TimeOfDay? time) {
    if (time == null) return '시간을 선택해주세요';

    final isAm = time.hour < 12;
    final period = isAm ? '오전' : '오후';

    int hour = time.hour % 12;
    if (hour == 0) hour = 12;

    final minute = time.minute.toString().padLeft(2, '0');

    return '$period $hour:$minute';
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

  void _saveMedicineSchedule() {
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('요일을 한 개 이상 선택해주세요.')),
      );
      return;
    }

    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('복용 시간을 선택해주세요.')),
      );
      return;
    }

    if (_medicineController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('약 이름을 입력해주세요.')),
      );
      return;
    }

    Navigator.pop(context, {
      'type': 'medicine',
      'time': _formatTime(_selectedTime),
      'days': _selectedDays.toList(),
      'medicineName': _medicineController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '약 복용 추가',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue[100],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                              vertical: 9,
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
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _days.map((day) {
                        final isSelected = _selectedDays.contains(day);

                        return GestureDetector(
                          onTap: () => _toggleDay(day),
                          child: Container(
                            width: 60,
                            height: 60,
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
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.blue,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      '몇시에 드시는 약인가요?',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: _pickTimeWithCupertinoWheel,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 16,
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
                              size: 30,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _formatTime(_selectedTime),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Icon(Icons.expand_more, size: 30),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      '어떤 약을 드시나요?',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _medicineController,
                      style: const TextStyle(fontSize: 22),
                      decoration: InputDecoration(
                        hintText: '예: 혈압약',
                        hintStyle: const TextStyle(fontSize: 20),
                        filled: true,
                        fillColor: Colors.blue[50],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
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
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
              color: Colors.white,
              child: SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _saveMedicineSchedule,
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