// lib/screens/group_detail_screen.dart
import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../models/group.dart';

// Import 3 tab con
import 'tabs/group_files_tab.dart';
import 'tabs/group_chat_tab.dart';
import 'tabs/group_members_tab.dart';
import 'tabs/group_comments_tab.dart'; // <-- ĐÃ THÊM IMPORT MỚI

// Import màn hình tải lên
import 'upload_file_screen.dart';

class GroupDetailScreen extends StatefulWidget {
  final Group group;
  const GroupDetailScreen({Key? key, required this.group}) : super(key: key);

  @override
  _GroupDetailScreenState createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // ---- SỬA: Tăng length từ 3 lên 4 ----
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF2FBF6), Color(0xFFFFFFFF)],
          begin: Alignment.topCenter,
          end: Alignment(0.0, 0.75),
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: _buildAppBar(context),
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(child: _buildGroupHeader(widget.group)),
              SliverToBoxAdapter(
                  child: _buildActions(context)), // Sẽ truyền group
              SliverToBoxAdapter(child: _buildSearch()),
              SliverPersistentHeader(
                delegate: _SliverTabBarDelegate(
                  TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(text: "Tệp"),
                      Tab(text: "Chat"),
                      Tab(text: "Thành viên"),
                      Tab(text: "Bình luận"), // <-- THÊM TAB MỚI
                    ],
                    // (Styling giữ nguyên)
                    labelColor: Colors.white,
                    unselectedLabelColor: AppColors.greenText,
                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: AppColors.primaryGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.25),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        )
                      ],
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12),
                    unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.normal, fontSize: 12),
                    overlayColor: MaterialStateProperty.all(
                        AppColors.primary.withOpacity(0.1)),
                    splashBorderRadius: BorderRadius.circular(999),
                  ),
                  containerColor: Colors.transparent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                pinned: true,
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              GroupFilesTab(groupId: widget.group.id),
              GroupChatTab(groupId: widget.group.id),
              GroupMembersTab(groupId: widget.group.id),
              // ---- THÊM VIEW MỚI VÀ TRUYỀN ID ----
              GroupCommentsTab(groupId: widget.group.id),
            ],
          ),
        ),
      ),
    );
  }

  // (Hàm _buildAppBar giữ nguyên)
  AppBar _buildAppBar(BuildContext context) {
    // ... (Giữ nguyên code)
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: InkWell(
          onTap: () => Navigator.of(context).pop(),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.greenLight,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.greenLightBorder),
            ),
            child: const Icon(Icons.arrow_back_ios_new,
                color: AppColors.greenText, size: 16),
          ),
        ),
      ),
      leadingWidth: 90,
      title: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield_outlined, color: AppColors.greenText, size: 20),
          SizedBox(width: 8),
          Text(
            "Linkshare",
            style:
                TextStyle(color: AppColors.text, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      centerTitle: true,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12.0),
          child: InkWell(
            onTap: () {},
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.greenLight,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.greenLightBorder),
              ),
              child: const Icon(Icons.more_horiz,
                  color: AppColors.greenText, size: 18),
            ),
          ),
        ),
      ],
    );
  }

  // (Hàm _buildGroupHeader giữ nguyên)
  Widget _buildGroupHeader(Group group) {
    // ... (Giữ nguyên code)
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.greenLight,
                    child: const Icon(Icons.shield,
                        color: AppColors.greenText, size: 22),
                  ),
                  const SizedBox(height: 6),
                  Text(group.name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.greenText)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(group.name,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(
                      "12 tệp · 8 thành viên · Hoạt động 2 phút trước", // (demo)
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.greenLight,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.greenLightBorder),
              ),
              child: const Text("v3",
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.greenText)),
            ),
          ],
        ),
      ),
    );
  }

  // (Hàm _buildActions giữ nguyên)
  Widget _buildActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: [
          ElevatedButton.icon(
            onPressed: () {
              // ---- SỬA LOGIC ĐIỀU HƯỚNG ----
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      UploadFileScreen(groupId: widget.group.id),
                ),
              );
              // -----------------------------
            },
            icon: const Icon(Icons.upload, size: 18),
            label: const Text("Tải lên"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              textStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.link, size: 18),
            label: const Text("Chia sẻ"),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.text,
              backgroundColor: AppColors.card,
              side: const BorderSide(color: AppColors.line),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              textStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // (Hàm _buildSearch và _SliverTabBarDelegate giữ nguyên)
  Widget _buildSearch() {
    // ... (Giữ nguyên code)
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: Container(
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
                  hintText: "Tìm tệp, bình luận…",
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: AppColors.muted),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  // ... (Giữ nguyên code)
  _SliverTabBarDelegate(this.tabBar,
      {required this.containerColor, this.padding});

  final TabBar tabBar;
  final Color containerColor;
  final EdgeInsetsGeometry? padding;

  @override
  double get minExtent =>
      tabBar.preferredSize.height + (padding?.vertical ?? 0);
  @override
  double get maxExtent =>
      tabBar.preferredSize.height + (padding?.vertical ?? 0);

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      padding: padding,
      color: containerColor,
      child: Container(
        decoration: BoxDecoration(
            color: AppColors.chipBg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.chipBorder)),
        child: tabBar,
      ),
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar;
  }
}
