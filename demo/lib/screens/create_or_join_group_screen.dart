// lib/screens/create_or_join_group_screen.dart
import 'package:flutter/material.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:provider/provider.dart';
import '../config/app_colors.dart';
import '../providers/group_provider.dart';
import '../services/error_handler.dart';

class CreateOrJoinGroupScreen extends StatefulWidget {
  const CreateOrJoinGroupScreen({Key? key}) : super(key: key);

  @override
  _CreateOrJoinGroupScreenState createState() =>
      _CreateOrJoinGroupScreenState();
}

// ---- BỎ "with SingleTickerProviderStateMixin" ----
class _CreateOrJoinGroupScreenState extends State<CreateOrJoinGroupScreen> {
  // Bỏ: late TabController _tabController;

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // Bỏ: _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    // Bỏ: _tabController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateGroup() async {
    // (Hàm này giữ nguyên)
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final groupProvider = context.read<GroupProvider>();
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();

    final newGroup = await groupProvider.createGroup(name, description);

    if (newGroup != null && context.mounted) {
      ErrorHandler.showSuccess(context, "Đã tạo nhóm: ${newGroup.name}");
      Navigator.of(context).pop();
    } else if (context.mounted) {
      ErrorHandler.showError(context, "Tạo nhóm thất bại");
    }
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
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Column(
            children: [
              const Text("Tạo nhóm mới", // <-- SỬA TIÊU ĐỀ
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text(
                "Điền thông tin bên dưới để tạo nhóm mới.", // <-- SỬA MÔ TẢ
                style: TextStyle(color: AppColors.muted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // ---- BỎ _buildSegmentedControl(context) ----

              // ---- CHỈ HIỂN THỊ TRỰC TIẾP TAB "TẠO" ----
              Expanded(
                child: _buildCreateTab(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // (Hàm _buildAppBar giữ nguyên)
  AppBar _buildAppBar(BuildContext context) {
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
              child: const Icon(Icons.help_outline,
                  color: AppColors.greenText, size: 18),
            ),
          ),
        ),
      ],
    );
  }

  // ---- BỎ HÀM _buildSegmentedControl ----

  // (Hàm _buildCreateTab giữ nguyên)
  Widget _buildCreateTab() {
    return ListView(
      padding: const EdgeInsets.all(4.0),
      children: [
        Form(
          key: _formKey,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line, width: 1.4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel("Tên nhóm"),
                _buildTextField(
                  controller: _nameController,
                  hintText: "VD: Nhóm Marketing",
                  validator: (value) => (value?.trim().isEmpty ?? true)
                      ? "Tên nhóm không được trống"
                      : null,
                ),
                const SizedBox(height: 10),
                _buildLabel("Mô tả"),
                _buildTextField(
                  controller: _descriptionController,
                  hintText: "Nhóm này dùng để làm gì?",
                  isTextArea: true,
                ),
                _buildHint("Không bắt buộc, hiển thị cho thành viên."),
                const SizedBox(height: 10),
                _buildLabel("Quyền riêng tư"),
                _buildPrivacyToggle(),
                _buildHint("Nhóm riêng tư cần quản trị viên phê duyệt."),
                const SizedBox(height: 10),
                _buildLabel("Biểu tượng nhóm"),
                _buildIconDropZone(),
                const SizedBox(height: 10),
                _buildPrimaryButton(
                  label: "Tạo nhóm",
                  icon: Icons.add,
                  onPressed: _handleCreateGroup,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---- BỎ HÀM _buildJoinTab ----

  // --- CÁC WIDGET HELPER (Giữ nguyên) ---

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 6),
      child: Text(text,
          style: const TextStyle(fontSize: 12, color: AppColors.muted)),
    );
  }

  Widget _buildHint(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 0),
      child: Text(text,
          style: const TextStyle(fontSize: 12, color: AppColors.muted)),
    );
  }

  Widget _buildTextField({
    required String hintText,
    bool isTextArea = false,
    TextEditingController? controller,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: isTextArea ? 3 : 1,
      minLines: isTextArea ? 3 : 1,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: AppColors.muted),
        filled: true,
        fillColor: const Color(0xFFF7FBF9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.line, width: 1.6),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.line, width: 1.6),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400, width: 1.6),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400, width: 1.6),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _buildPrivacyToggle() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFFEEF7F3),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.chipBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.greenLightBorder),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.15),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  )
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_person, size: 16, color: Color(0xFF065F46)),
                  SizedBox(width: 6),
                  Text("Riêng tư",
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF065F46))),
                ],
              ),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.public, size: 16, color: AppColors.text),
                const SizedBox(width: 6),
                Text("Công khai",
                    style: TextStyle(
                        fontWeight: FontWeight.w800, color: AppColors.text)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconDropZone() {
    return DottedBorder(
      color: AppColors.greenLightBorder,
      strokeWidth: 1.6,
      borderType: BorderType.RRect,
      radius: const Radius.circular(12),
      dashPattern: const [6, 6],
      child: Container(
        height: 100,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F7F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text("Nhấn để tải ảnh lên",
              style: TextStyle(color: AppColors.muted)),
        ),
      ),
    );
  }

  // Bỏ: _buildQrScanZone
  // Bỏ: _buildProfileMini

  Widget _buildPrimaryButton(
      {required String label,
      required IconData icon,
      VoidCallback? onPressed}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
