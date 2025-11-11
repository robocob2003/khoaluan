// lib/screens/upload_file_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../config/app_colors.dart';
import '../providers/file_transfer_provider.dart';
import '../providers/auth_provider.dart';
import '../services/error_handler.dart';

class UploadFileScreen extends StatefulWidget {
  final int groupId;
  const UploadFileScreen({Key? key, required this.groupId}) : super(key: key);

  @override
  _UploadFileScreenState createState() => _UploadFileScreenState();
}

class _UploadFileScreenState extends State<UploadFileScreen> {
  bool _isEncrypted = false;
  bool _needsApproval = false;
  final TextEditingController _tagController = TextEditingController();
  // ---- SỬA: BẮT ĐẦU VỚI DANH SÁCH RỖNG ----
  final List<String> _tags = [];
  // ----------------------------------------

  PlatformFile? _pickedFile;
  bool _isUploading = false;

  @override
  void dispose() {
    _tagController.dispose();
    super.dispose();
  }

  void _addTag() {
    final tag = _tagController.text.trim().toLowerCase(); // Chuẩn hóa tag
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result != null && result.files.single.path != null) {
        setState(() {
          _pickedFile = result.files.single;
        });
      }
    } catch (e) {
      if (mounted) ErrorHandler.showError(context, 'Failed to pick file: $e');
    }
  }

  // ---- CẬP NHẬT HÀM TẢI LÊN ----
  Future<void> _handleUpload() async {
    if (_pickedFile == null || _pickedFile!.path == null) {
      ErrorHandler.showWarning(context, "Vui lòng chọn một tệp để tải lên.");
      return;
    }
    if (_isUploading) return;

    setState(() {
      _isUploading = true;
    });

    final fileProvider = context.read<FileTransferProvider>();
    final authProvider = context.read<AuthProvider>();
    final senderId = authProvider.user?.id;

    if (senderId == null) {
      ErrorHandler.showError(context, "Lỗi xác thực người dùng.");
      setState(() {
        _isUploading = false;
      });
      return;
    }

    // 1. Tải tệp lên
    final metadata = await fileProvider.sendFileToGroup(
      filePath: _pickedFile!.path!,
      groupId: widget.groupId,
      senderId: senderId,
      // ---- THÊM THAM SỐ NÀY ----
      isEncrypted: _isEncrypted,
      // ---------------------------
    );

    if (metadata != null) {
      // 2. Nếu tải tệp thành công, GỬI TAGS
      if (_tags.isNotEmpty) {
        // Không cần await, cứ gửi đi
        fileProvider.sendFileTags(metadata.id, widget.groupId, _tags);
      }

      setState(() {
        _isUploading = false;
      });
      ErrorHandler.showSuccess(context, "Đã tải tệp lên: ${metadata.fileName}");
      if (mounted) Navigator.of(context).pop();
    } else {
      setState(() {
        _isUploading = false;
      });
      ErrorHandler.showError(context, "Tải tệp lên thất bại.");
    }
  }
  // -------------------------

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
        body: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(
                  12.0, 8.0, 12.0, 100.0), // Padding cho nút
              children: [
                const Text(
                  "Tải tài liệu lên",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                _buildFilePickerCard(),

                _buildTextField(
                  label: "Tiêu đề",
                  controller:
                      TextEditingController(text: _pickedFile?.name ?? ""),
                  readOnly: _pickedFile != null, // Khóa sau khi chọn
                ),
                _buildTextField(
                  label: "Mô tả",
                  hint: "Phạm vi, mốc, và tác động...",
                  isTextArea: true,
                ),
                _buildGroupFolderRow(),
                _buildTagsSection(),
                _buildToggle(
                  title: "Mã hóa đầu-cuối",
                  subtitle: "Chỉ thành viên có khóa mới xem được",
                  value: _isEncrypted,
                  onChanged: (val) => setState(() => _isEncrypted = val),
                ),
                _buildToggle(
                  title: "Yêu cầu phê duyệt",
                  subtitle: "Admin duyệt trước khi hiển thị",
                  value: _needsApproval,
                  onChanged: (val) => setState(() => _needsApproval = val),
                ),
                _buildSectionTitle("Quyền truy cập"),
                _buildLinkRow(
                  title: "Chia sẻ với",
                  subtitle: "Core Team, Design Guild",
                ),
                _buildLinkRow(title: "Hết hạn", subtitle: "Không có"),
                _buildLinkRow(
                  title: "Cài đặt liên kết",
                  subtitle: "Ai có liên kết đều xem",
                ),
                const SizedBox(height: 20), // Thêm khoảng trống
              ],
            ),
            _buildBottomActions(),
          ],
        ),
      ),
    );
  }

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
              child: const Icon(Icons.more_horiz,
                  color: AppColors.greenText, size: 18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilePickerCard() {
    String title = _pickedFile == null ? "Chọn tệp" : _pickedFile!.name;
    String subtitle = _pickedFile == null
        ? "PDF, DOCX, PNG tối đa 50MB"
        : "Kích thước: ${(_pickedFile!.size / 1024 / 1024).toStringAsFixed(2)} MB";
    IconData icon = _pickedFile == null ? Icons.add : Icons.check_circle;
    Color color = _pickedFile == null ? AppColors.greenText : Colors.green;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: InkWell(
        onTap: _pickFile,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FAF6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFD9EFE6), width: 1.5),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    Text(subtitle,
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 12)),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 6),
      child: Text(text,
          style: const TextStyle(fontSize: 12, color: AppColors.muted)),
    );
  }

  Widget _buildTextField(
      {required String label,
      TextEditingController? controller,
      String? initialValue,
      String? hint,
      bool isTextArea = false,
      bool readOnly = false,
      String? Function(String?)? validator}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel(label),
          TextFormField(
            controller: controller,
            initialValue: initialValue,
            validator: validator,
            readOnly: readOnly,
            maxLines: isTextArea ? 3 : 1,
            minLines: isTextArea ? 3 : 1,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: AppColors.muted),
              filled: true,
              fillColor:
                  readOnly ? const Color(0xFFF3F7F5) : const Color(0xFFF7FBF9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.line, width: 1.6),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.line, width: 1.6),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                    color: readOnly ? AppColors.line : AppColors.primary,
                    width: 1.6),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.red.shade400, width: 1.6),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.red.shade400, width: 1.6),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupFolderRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        children: [
          Expanded(
              child: _buildPill(
                  icon: Icons.folder_copy_outlined, label: "Core Team")),
          const SizedBox(width: 10),
          Expanded(
              child: _buildPill(
                  icon: Icons.folder_open_outlined, label: "/Docs/Planning")),
        ],
      ),
    );
  }

  Widget _buildPill({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBF9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line, width: 1.6),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.greenText, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagsSection() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel("Thẻ"),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tags.map((tag) => _buildTag(tag)).toList(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tagController,
                  decoration: InputDecoration(
                    hintText: "+ Thêm thẻ",
                    hintStyle: const TextStyle(color: AppColors.muted),
                    filled: true,
                    fillColor: const Color(0xFFF7FBF9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: AppColors.line, width: 1.6),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: AppColors.line, width: 1.6),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 1.6),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _addTag,
                child: Text("Thêm"),
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.card,
                  foregroundColor: AppColors.text,
                  side: const BorderSide(color: AppColors.line),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.chipBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.chipBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(color: AppColors.greenText, fontSize: 12)),
          const SizedBox(width: 4),
          InkWell(
            onTap: () => _removeTag(label),
            child: const Icon(Icons.close, size: 14, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBF9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line, width: 1.6),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(subtitle,
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withOpacity(0.5),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.black12,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
      ),
    );
  }

  Widget _buildLinkRow({required String title, required String subtitle}) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line, width: 1.2),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppColors.greenText, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: AppColors.card.withOpacity(0.95), // Nền mờ
          border: const Border(top: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.refresh, size: 18), // Sửa icon
                label: const Text("Chọn lại"), // Sửa text
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.text,
                  backgroundColor: AppColors.card,
                  side: const BorderSide(color: AppColors.line),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _isUploading ? null : _handleUpload,
                icon: _isUploading
                    ? Container(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.upload, size: 18),
                label: Text(_isUploading ? "Đang tải lên..." : "Tải lên"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700),
                  elevation: 5,
                  shadowColor: AppColors.primary.withOpacity(0.3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
