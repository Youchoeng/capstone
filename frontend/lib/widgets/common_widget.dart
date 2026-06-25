// lib/widgets/common_widgets.dart
// 공통으로 사용하는 위젯 따로 만들기
import 'package:flutter/material.dart';

Widget buildProfileAvatar({
  required String name,
  String? imageUrl,
  double radius = 22,
}) {
  // 이름 첫 글자 가져오는 로직 포함
  String initial = name.trim().isNotEmpty ? name.trim().substring(0, 1) : '?';

  if (imageUrl != null && imageUrl.isNotEmpty) {
    return CircleAvatar(
      radius: radius,
      backgroundImage: NetworkImage(imageUrl),
      backgroundColor: Colors.grey[200],
    );
  }
  return CircleAvatar(
    radius: radius,
    backgroundColor: Colors.green[200],
    child: Text(
      initial,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    ),
  );
}