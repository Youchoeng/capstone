import 'package:flutter/material.dart';
import 'Home_Add_Medicine_Screen.dart';
import 'Home_Add_Appointment_Screen.dart';

class HomeAddScreen extends StatelessWidget {
  const HomeAddScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '할 일 종류 선택',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue[100],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 12),
            const Text(
              '추가할 할 일 종류를 선택하세요',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            _SelectTypeCard(
              icon: Icons.medication,
              title: '약 복용',
              subtitle: '복약 일정을 추가합니다.',
              onTap: () async {
                final result = await Navigator.push<Map<String, dynamic>>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HomeAddMedicineScreen(),
                  ),
                );

                if (!context.mounted || result == null) return;
                Navigator.pop(context, result);
              },
            ),
            const SizedBox(height: 16),
            _SelectTypeCard(
              icon: Icons.place,
              title: '약속 장소 가기',
              subtitle: '병원, 모임, 외출 일정을\n추가합니다.',
              onTap: () async {
                final result = await Navigator.push<Map<String, dynamic>>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HomeAddAppointmentScreen(),
                  ),
                );

                if (!context.mounted || result == null) return;
                Navigator.pop(context, result);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectTypeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SelectTypeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.blue[50],
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.blue.shade200, width: 2),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white,
                child: Icon(
                  icon,
                  size: 30,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 17,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 34,
              ),
            ],
          ),
        ),
      ),
    );
  }
}