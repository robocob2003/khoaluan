// lib/screens/tabs/friends_tab.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/friend_provider.dart';

class FriendsTab extends StatefulWidget {
  const FriendsTab({Key? key}) : super(key: key);

  @override
  _FriendsTabState createState() => _FriendsTabState();
}

class _FriendsTabState extends State<FriendsTab> {
  @override
  void initState() {
    super.initState();
    // Tải lại danh sách bạn bè mỗi khi tab này được mở
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FriendProvider>().loadFriendships();
    });
  }

  @override
  Widget build(BuildContext context) {
    final friendProvider = context.watch<FriendProvider>();
    final authProvider = context.watch<AuthProvider>();

    final friends = friendProvider.friends;
    final pendingRequests = friendProvider.pendingRequests;

    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.screenGradient,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: _buildAppBar(context, authProvider),
        body: RefreshIndicator(
          onRefresh: () => friendProvider.loadFriendships(),
          child: ListView(
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            children: [
              _buildSearch(),

              // ---- PHẦN YÊU CẦU KẾT BẠN ----
              if (pendingRequests.isNotEmpty)
                ..._buildPendingRequests(
                    context, friendProvider, pendingRequests),

              // ---- PHẦN DANH SÁCH BẠN BÈ ----
              _buildSectionTitle(title: "Bạn bè", count: friends.length),
              _buildFriendList(context, friends),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGETS CON ---

  AppBar _buildAppBar(BuildContext context, AuthProvider authProvider) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 12.0,
      title: const Text("Bạn bè",
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.text)),
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: ElevatedButton.icon(
            onPressed: () {
              // ---- SỬA: Tải lại user trước khi mở ----
              _showAddFriendDialog(context);
            },
            icon: const Icon(Icons.person_add_alt_1, size: 18),
            label: const Text("Thêm bạn"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 8.0, right: 12.0),
          child: InkWell(
            onTap: () {},
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.line),
              ),
              child: const Icon(Icons.settings_outlined,
                  color: AppColors.text, size: 18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearch() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBF9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.line, width: 1.4),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: AppColors.greenText, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: "Tìm bạn bè...",
                border: InputBorder.none,
                hintStyle: TextStyle(color: AppColors.muted),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle({required String title, required int count}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 12.0),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const Spacer(),
          Text(
            "$count",
            style: const TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // -- PHẦN HIỂN THỊ YÊU CẦU --
  List<Widget> _buildPendingRequests(
      BuildContext context, FriendProvider provider, List<UserModel> requests) {
    return [
      _buildSectionTitle(title: "Yêu cầu kết bạn", count: requests.length),
      ListView.builder(
        itemCount: requests.length,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          final user = requests[index];
          return _buildPendingCard(context, provider, user);
        },
      ),
    ];
  }

  Widget _buildPendingCard(
      BuildContext context, FriendProvider provider, UserModel user) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Image.network(
                  "https://i.pravatar.cc/150?u=${user.username}",
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.username,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                    Text(user.email,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.muted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    // TODO: Logic từ chối
                  },
                  child: Text("Từ chối"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.text,
                    side: BorderSide(color: AppColors.line),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    provider.acceptFriendRequest(user);
                  },
                  child: Text("Chấp nhận"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shadowColor: AppColors.primary.withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  // -- PHẦN HIỂN THỊ BẠN BÈ --
  Widget _buildFriendList(BuildContext context, List<UserModel> friends) {
    if (friends.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            "Chưa có bạn bè.\nHãy nhấn 'Thêm bạn' để tìm kiếm.",
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted),
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: friends.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final user = friends[index];
        return _buildFriendCard(context, user);
      },
    );
  }

  Widget _buildFriendCard(BuildContext context, UserModel user) {
    return InkWell(
      onTap: () {
        // Mở màn hình chat 1-1
        Navigator.of(context).pushNamed(
          '/chat',
          arguments: {'username': user.username},
        );
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Image.network(
                "https://i.pravatar.cc/150?u=${user.username}",
                width: 44,
                height: 44,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.username,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                  Text(user.email,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.muted)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.chevron_right, color: AppColors.greenText, size: 22),
          ],
        ),
      ),
    );
  }

  // ---- HÀM ĐÃ ĐƯỢC CẬP NHẬT ----
  void _showAddFriendDialog(BuildContext context) async {
    // <-- Thêm async
    // Lấy provider (read, không listen)
    final authProvider = context.read<AuthProvider>();
    final friendProvider = context.read<FriendProvider>();

    // 1. Tải lại danh sách user tổng
    await authProvider.refreshConnection();

    // 2. Lọc danh sách (logic cũ)
    final myId = authProvider.user!.id;
    final friendIds = friendProvider.friends.map((u) => u.id).toSet();
    final sentIds = friendProvider.sentRequests.map((u) => u.id).toSet();

    final users = authProvider.availableUsers.where((user) {
      return user.id != myId &&
          !friendIds.contains(user.id) &&
          !sentIds.contains(user.id);
    }).toList();

    // 3. Hiển thị dialog (chỉ khi context còn mounted)
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      builder: (ctx) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.all(16),
            height: MediaQuery.of(context).size.height * 0.6,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Thêm bạn bè",
                    style: Theme.of(context).textTheme.titleLarge),
                Text("Chọn người dùng để gửi yêu cầu kết bạn:"),
                const SizedBox(height: 16),
                Expanded(
                  child: users.isEmpty
                      ? Center(child: Text("Đã kết bạn với tất cả mọi người."))
                      : ListView.builder(
                          itemCount: users.length,
                          itemBuilder: (context, index) {
                            final user = users[index];
                            return ListTile(
                              title: Text(user.username),
                              leading: Icon(Icons.person_add_outlined,
                                  color: AppColors.greenText),
                              onTap: () {
                                friendProvider.sendFriendRequest(user);
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(
                                  content: Text(
                                      "Đã gửi yêu cầu đến ${user.username}"),
                                  backgroundColor: AppColors.primary,
                                ));
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
