import 'package:flutter/material.dart';

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  final List<String> _diseases = ['당뇨', '고혈압', '고지혈증', '통풍', '신장질환'];
  final List<String> _selectedDiseases = [];
  final TextEditingController _foodController = TextEditingController();

  String _aiResult = '';
  bool _isLoading = false;

  // 🌟 핵심 추가 포인트: 질환 선택창을 접고 펼치는 스위치! (처음엔 무조건 펼쳐둠)
  bool _isDiseaseExpanded = true;

  void _analyzeFood() async {
    if (_foodController.text.isEmpty) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _aiResult = '';
      // 분석을 시작하면 질환 선택창이 열려있더라도 자동으로 닫아줍니다. (공간 확보)
      _isDiseaseExpanded = false;
    });

    await Future.delayed(const Duration(milliseconds: 1500));

    setState(() {
      _isLoading = false;
      if (_selectedDiseases.isEmpty) {
        _aiResult = '질환을 선택하지 않으셨네요!\n"${_foodController.text}"은(는) 편하게 드셔도 좋습니다.';
      } else if (_selectedDiseases.contains('당뇨') && _foodController.text.contains('빵')) {
        _aiResult = '⚠️ 주의가 필요합니다!\n당뇨가 있으시므로 "${_foodController.text}" 같은 탄수화물/당류는 혈당을 급격히 올릴 수 있습니다. 통밀로 만든 것을 드시거나 섭취량을 반으로 줄이세요.';
      } else if (_selectedDiseases.contains('고혈압') && _foodController.text.contains('찌개')) {
        _aiResult = '⚠️ 나트륨 주의!\n고혈압에는 국물 요리가 좋지 않습니다. "${_foodController.text}"의 국물은 남기시고 건더기 위주로 드시는 것을 권장합니다.';
      } else {
        _aiResult = '✅ 적당량 드시는 것은 괜찮습니다.\n"${_selectedDiseases.join(', ')}"에 특별히 치명적인 성분은 없지만, 과식은 피해주세요!';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: const Text('건강 관리 & 체조', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.green[100], // 배경을 다른 색상도 사용해봄
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==========================================
              // 파트 1: 인체 부위별 건강 체조
              // ==========================================
              const Text('🏃‍♂️ 부위별 맞춤 체조', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),

              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ExpansionTile(
                  leading: const Icon(Icons.accessibility_new, color: Colors.blue, size: 32),
                  title: const Text('상반신 (어깨, 목, 허리)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  children: [
                    _buildExerciseLink('💆‍♂️ 목/어깨 스트레칭', 'https://youtube.com/...'),
                    _buildExerciseLink('💪 굽은 등 펴기 체조', 'https://youtube.com/...'),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ExpansionTile(
                  leading: const Icon(Icons.directions_walk, color: Colors.green, size: 32),
                  title: const Text('하반신 (무릎, 발목, 골반)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  children: [
                    _buildExerciseLink('🦵 무릎 관절염 예방 운동', 'https://youtube.com/...'),
                    _buildExerciseLink('🦶 발목 펌프 운동', 'https://youtube.com/...'),
                  ],
                ),
              ),

              const SizedBox(height: 30),
              const Divider(thickness: 2),
              const SizedBox(height: 20),

              // ==========================================
              // 파트 2: AI 질환/식단 분석기
              // ==========================================
              const Text('🤖 AI 맞춤 식단 분석', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),

              // 🌟 1. 질환 선택창이 열려있을 때 (Expanded 상태)
              if (_isDiseaseExpanded) ...[
                const Text('가지고 계신 만성질환을 모두 선택해 주세요.', style: TextStyle(fontSize: 16, color: Colors.grey)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: _diseases.map((disease) {
                    final isSelected = _selectedDiseases.contains(disease);
                    return FilterChip(
                      label: Text(disease, style: const TextStyle(fontSize: 16)),
                      selected: isSelected,
                      selectedColor: Colors.green[200],
                      checkmarkColor: Colors.green[900],
                      onSelected: (bool selected) {
                        setState(() {
                          if (selected) {
                            _selectedDiseases.add(disease);
                          } else {
                            _selectedDiseases.remove(disease);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                // 선택 완료 버튼
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _isDiseaseExpanded = false; // 버튼을 누르면 접힙니다!
                      });
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green[600]),
                    child: const Text('선택 완료', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ]
              // 🌟 2. 질환 선택창이 닫혀있을 때 (Collapsed 상태)
              else ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedDiseases.isEmpty
                              ? '선택된 질환이 없습니다.'
                              : '나의 질환: ${_selectedDiseases.join(', ')}',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green[800]),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _isDiseaseExpanded = true; // 다시 누르면 펼쳐집니다!
                          });
                        },
                        icon: const Icon(Icons.edit, size: 18, color: Colors.green),
                        label: const Text('수정', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),
              const Text('지금 드시려는 음식을 알려주세요.', style: TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _foodController,
                      decoration: InputDecoration(
                        hintText: '예: 김치찌개, 단팥빵',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.mic, color: Colors.blue, size: 28),
                          onPressed: () {},
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _analyzeFood,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('분석', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              if (_isLoading)
                const Center(child: CircularProgressIndicator(color: Colors.green))
              else if (_aiResult.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade300, width: 2),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.smart_toy, color: Colors.green, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(_aiResult, style: const TextStyle(fontSize: 18, height: 1.5, color: Colors.black87)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExerciseLink(String title, String link) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 4.0),
      title: Text(title, style: const TextStyle(fontSize: 18)),
      trailing: const Icon(Icons.play_circle_fill, color: Colors.red, size: 30),
      onTap: () {},
    );
  }
}