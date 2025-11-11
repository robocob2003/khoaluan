// lib/screens/tabs/groups_tab.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../models/group.dart';
import '../../providers/group_provider.dart';
import '../group_detail_screen.dart';
import '../create_or_join_group_screen.dart';

class GroupsTab extends StatelessWidget {
  const GroupsTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Lấy provider
    final groupProvider = context.watch<GroupProvider>();
    final groups = groupProvider.groups;

    // Nền gradient cho toàn bộ tab
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
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          children: [
            _buildSearch(),
            const SizedBox(height: 12),
            _buildFilterChips(),
            const SizedBox(height: 12),
            _buildSectionTitle(title: "Nhóm của bạn", count: groups.length),
            _buildGroupList(context, groups),
          ],
        ),
      ),
    );
  }

  // "Dịch" từ class="top"
  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 12.0,
      title: const Text("Nhóm",
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.text)),
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const CreateOrJoinGroupScreen(),
                ),
              );
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text("Nhóm mới"),
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

  // "Dịch" từ class="search"
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
                hintText: "Tìm nhóm, thành viên…",
                border: InputBorder.none,
                hintStyle: TextStyle(color: AppColors.muted),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // "Dịch" từ class="chips"
  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: Row(
        children: [
          _buildChip("Tất cả", isActive: true),
          _buildChip("Yêu thích", isActive: false),
          _buildChip("Đã tham gia", isActive: false),
          _buildChip("Lời mời", isActive: false),
        ],
      ),
    );
  }

  // "Dịch" từ class="chip"
  Widget _buildChip(String label, {required bool isActive}) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? null : AppColors.chipBg,
        gradient: isActive ? AppColors.primaryGradient : null,
        borderRadius: BorderRadius.circular(999),
        border: isActive ? null : Border.all(color: AppColors.chipBorder),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.25),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                )
              ]
            : [],
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: isActive ? Colors.white : AppColors.greenText,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  // "Dịch" từ class="section"
  Widget _buildSectionTitle({required String title, required int count}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 8.0),
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

  // "Dịch" từ class="list"
  Widget _buildGroupList(BuildContext context, List<Group> groups) {
    if (groups.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(
            "Bạn chưa tham gia nhóm nào. \nHãy nhấn 'Nhóm mới' để tạo hoặc tham gia.",
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted),
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: groups.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final group = groups[index];
        return _buildGroupCard(
          context: context,
          group: group, // <-- Dùng group thật
        );
      },
    );
  }

  // "Dịch" từ class="card" (trong list)
  Widget _buildGroupCard({
    required BuildContext context,
    required Group group, // <-- Nhận Group object
  }) {
    return InkWell(
      onTap: () {
        // Điều hướng đến màn hình chi tiết
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) =>
                GroupDetailScreen(group: group), // <-- TRUYỀN GROUP VÀO
          ),
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
                // Avatar demo
                "https://i.pravatar.cc/150?u=${group.id}",
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
                  Text(group.name, // <-- Tên thật
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                  Text(group.description ?? "Chưa có mô tả", // <-- Mô tả thật
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.muted)),
                  const SizedBox(height: 6),
                  Wrap(
                    // (Tags vẫn là demo)
                    spacing: 6,
                    runSpacing: 6,
                    children: ["Demo", "Tag"]
                        .map((tag) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF2FAF6),
                                borderRadius: BorderRadius.circular(999),
                                border:
                                    Border.all(color: const Color(0xFFDEF1EA)),
                              ),
                              child: Text(
                                tag,
                                style: const TextStyle(
                                    color: AppColors.greenText,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500),
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.greenLight,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.greenLightBorder),
                  ),
                  child: Text(
                    // (Số file vẫn là demo)
                    "0 tệp",
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.greenText),
                  ),
                ),
                const SizedBox(height: 10),
                const Icon(Icons.chevron_right,
                    color: AppColors.greenText, size: 22),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
