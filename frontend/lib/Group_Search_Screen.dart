import 'package:flutter/material.dart';
import 'Group_Detail_Screen.dart';
import 'Group_Main_Screen.dart';
import 'Group_Model.dart';
import 'api_service.dart';

class GroupSearchScreen extends StatefulWidget {
  const GroupSearchScreen({super.key});

  @override
  State<GroupSearchScreen> createState() => _GroupSearchScreenState();
}

class _GroupSearchScreenState extends State<GroupSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<Group> _allGroups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() => _isLoading = true);
    final data = await ApiService.getGroups(query: _searchQuery);
    if (data != null && mounted) {
      setState(() {
        _allGroups = data.map<Group>((item) {
          return Group(
            id: (item['id'] ?? 0).toString(),
            name: item['name'] ?? '',
            description: item['description'] ?? '',
            imageUrl: (item['image_url'] ?? '').toString().isNotEmpty
                ? item['image_url']
                : 'https://via.placeholder.com/150',
            memberCount: item['member_count'] ?? 0,
            members: [],
          );
        }).toList();
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  List<Group> get _popularGroups {
    final copied = List<Group>.from(_allGroups);
    copied.sort((a, b) => b.memberCount.compareTo(a.memberCount));
    return copied.take(4).toList();
  }

  List<Group> get _filteredGroups {
    if (_searchQuery.trim().isEmpty) {
      return _popularGroups;
    }
    return _allGroups;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
        _loadGroups();
      },
      decoration: InputDecoration(
        hintText: '새로운 모임에 가입해보세요',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
          onPressed: () {
            _searchController.clear();
            setState(() {
              _searchQuery = '';
            });
            _loadGroups();
          },
          icon: const Icon(Icons.close),
        )
            : null,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.green.shade400, width: 2),
        ),
      ),
    );
  }

  Widget _buildGroupTile(Group group) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            group.imageUrl,
            width: 60,
            height: 60,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              width: 60,
              height: 60,
              color: Colors.grey[300],
              child: const Icon(Icons.group, color: Colors.grey),
            ),
          ),
        ),
        title: Text(
          group.name,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('${group.description}\n멤버 ${group.memberCount}명'),
        ),
        trailing: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GroupDetailScreen(
                  group: group,
                  groupName: group.name,
                  userName: currentUserName,
                  isMember: false,
                ),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[600],
          ),
          child: const Text(
            '둘러보기',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptySearchResult() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      alignment: Alignment.center,
      child: const Column(
        children: [
          Icon(Icons.search_off, size: 50, color: Colors.grey),
          SizedBox(height: 12),
          Text(
            '검색 결과가 없습니다.',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          SizedBox(height: 6),
          Text(
            '모임 이름이나 소개글로 다시 검색해보세요.',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupsToShow = _filteredGroups;
    final bool isSearching = _searchQuery.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('새로운 모임 찾기'),
        backgroundColor: Colors.green[100],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildSearchField(),
          const SizedBox(height: 20),
          Text(
            isSearching ? '🔎 검색 결과' : '🔥 지금 뜨는 인기 모임',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (groupsToShow.isEmpty)
            _buildEmptySearchResult()
          else
            ...groupsToShow.map(_buildGroupTile),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}