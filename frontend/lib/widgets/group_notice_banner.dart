import 'package:flutter/material.dart';
import '../Group_Model.dart';

class GroupNoticeBanner extends StatelessWidget {
  final GroupPost post;
  final VoidCallback onTap;

  const GroupNoticeBanner({super.key, required this.post, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: InkWell(
        onTap: onTap,
        child: Container(
          color: Colors.red[50],
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.campaign, color: Colors.red),
                  SizedBox(width: 8),
                  Text('모임장 공지사항', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                post.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, color: Colors.black87),
              ),
            ],
          ),
        ),
      ),
    );
  }
}