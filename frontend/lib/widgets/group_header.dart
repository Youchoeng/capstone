import 'dart:io';
import 'package:flutter/material.dart';

// 🌟 별도의 파일로 분리된 GroupHeader 위젯
class GroupHeader extends StatelessWidget {
  final File? headerImage;
  final bool isLeader;
  final VoidCallback onPickImage;

  const GroupHeader({
    super.key, // super.key 추가 권장
    required this.headerImage,
    required this.isLeader,
    required this.onPickImage,
  });

  @override
  Widget build(BuildContext context) {
    // build 메서드 내부는 승혁님이 작성하신 코드 그대로 유지
    return SliverToBoxAdapter(
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            height: 200,
            color: Colors.grey[300],
            child: headerImage != null
                ? Image.file(headerImage!, fit: BoxFit.cover)
                : const Center(
              child: Icon(Icons.image, size: 50, color: Colors.grey),
            ),
          ),
          if (isLeader)
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton.small(
                backgroundColor: Colors.white,
                onPressed: onPickImage,
                child: const Icon(Icons.camera_alt, color: Colors.black),
              ),
            ),
        ],
      ),
    );
  }
}