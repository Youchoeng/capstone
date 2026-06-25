import 'package:flutter/material.dart';

class TimelineScheduleTile extends StatefulWidget {
  final String scheduleId;
  final String time;
  final String title;
  final bool isLast;
  final bool isDeleteMode;
  final bool isSelected;
  final VoidCallback onSelectTap;

  const TimelineScheduleTile({
    super.key,
    required this.scheduleId,
    required this.time,
    required this.title,
    required this.isLast,
    required this.isDeleteMode,
    required this.isSelected,
    required this.onSelectTap,
  });

  @override
  State<TimelineScheduleTile> createState() => _TimelineScheduleTileState();
}

class _TimelineScheduleTileState extends State<TimelineScheduleTile> {
  bool _isCompleted = false;

  bool get _isMedicine =>
      widget.title.contains('약') || widget.title.contains('복용');

  Widget _buildTimeText() {
    final value = widget.time.trim();

    if (value.startsWith('오전 ') || value.startsWith('오후 ')) {
      final parts = value.split(' ');
      final period = parts[0];
      final clock = parts.sublist(1).join(' ');

      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '$period ',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextSpan(
                text: clock,
                style: const TextStyle(
                  fontSize: 28,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        value,
        maxLines: 1,
        style: const TextStyle(
          fontSize: 28,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSelectionButton() {
    if (!widget.isDeleteMode) {
      return const SizedBox(width: 0);
    }

    // 🌟 [수정] 박스가 위아래로 늘어날 때 체크 버튼이 찌그러지지 않도록 Align 추가!
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(right: 10, top: 12),
        child: GestureDetector(
          onTap: widget.onSelectTap,
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.isSelected ? Colors.white : Colors.transparent,
              border: Border.all(
                color: Colors.white,
                width: 2.5,
              ),
            ),
            child: widget.isSelected
                ? const Icon(
              Icons.check,
              size: 18,
              color: Colors.blue,
            )
                : null,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onTileTap = widget.isDeleteMode
        ? widget.onSelectTap
        : () {
      setState(() {
        _isCompleted = !_isCompleted;
      });
    };

    return InkWell(
      onTap: onTileTap,
      // 🌟 [수정 1] 고정 높이(SizedBox height: 105)를 지우고 IntrinsicHeight로 감쌉니다!
      // 이제 안쪽에 있는 '글자 박스'의 높이에 맞춰 전체 상자 높이가 유연하게 변합니다.
      child: IntrinsicHeight(
        child: Row(
          // 🌟 [수정 2] 자식들을 위아래로 쭉 늘려줍니다.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.isDeleteMode) _buildSelectionButton(),
            SizedBox(
              width: widget.isDeleteMode ? 84 : 110,
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: _buildTimeText(),
                ),
              ),
            ),

            // 🌟 [수정 3] 타임라인 점선과 동그라미를 Stack으로 변경!
            // 이렇게 하면 글자 박스가 두 줄, 세 줄이 되어 밑으로 쭉 늘어나도
            // 점선이 에러 없이 바닥까지 완벽하게 이어집니다.
            SizedBox(
              width: 30,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  if (!widget.isLast)
                    Positioned(
                      top: 24, // 동그라미 바로 밑에서부터 시작
                      bottom: 0, // 상자 끝까지 쫙 늘어남
                      child: Container(
                        width: 3,
                        color: Colors.white70,
                      ),
                    ),
                  Container(
                    width: 16,
                    height: 16,
                    margin: const EdgeInsets.only(top: 14),
                    decoration: BoxDecoration(
                      color: _isCompleted ? Colors.greenAccent : Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: _isCompleted ? Colors.green[400] : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _isCompleted ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isMedicine
                          ? (_isCompleted ? '복용완료' : '복용전')
                          : (_isCompleted ? '완료' : '예정'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _isCompleted ? Colors.white : Colors.blueGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}