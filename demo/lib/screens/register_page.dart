// lib/screens/register_page.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../config/app_colors.dart'; // Import bảng màu mới

class RegisterPage extends StatefulWidget {
  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true; // toggle ẩn/hiện mật khẩu

  void _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.register(
      _usernameController.text.trim(),
      _emailController.text.trim(),
      _passwordController.text,
      context,
    );

    if (success && mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade500,
          content: const Text('Đăng ký thất bại. Vui lòng kiểm tra thông tin.'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Nền gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFF4FBF8), Color(0xFFEBF6F2)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // Blob mờ tạo chiều sâu
          Positioned(
            top: -50,
            left: -40,
            child:
                _blurBlob(size: 160, color: AppColors.primary.withOpacity(.18)),
          ),
          Positioned(
            bottom: -40,
            right: -40,
            child: _blurBlob(
                size: 200, color: const Color(0xFF74D6AF).withOpacity(.15)),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header nhỏ gọn
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppColors.primaryGradient,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(.25),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.white,
                              child: Icon(Icons.person_add_alt_1_outlined,
                                  size: 28, color: AppColors.greenText),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Create your account',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.greenText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Tham gia không gian làm việc của bạn chỉ trong vài giây.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 13.5, color: AppColors.muted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),

                      // Segmented giữ nguyên luồng, làm đẹp hiệu ứng
                      _buildSegmentedControl(context),
                      const SizedBox(height: 20),

                      // FORM trong glass card
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(.75),
                              borderRadius: BorderRadius.circular(20),
                              border:
                                  Border.all(color: const Color(0xFFE6F1ED)),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x1A000000),
                                  blurRadius: 24,
                                  offset: Offset(0, 12),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Username
                                  Text("Username", style: _labelStyle()),
                                  const SizedBox(height: 6),
                                  _buildTextFormField(
                                    controller: _usernameController,
                                    hintText: "your_username",
                                    prefixIcon: const Icon(
                                        Icons.alternate_email_outlined),
                                    validator: (value) =>
                                        value!.trim().length < 3
                                            ? 'Username phải có ít nhất 3 ký tự'
                                            : null,
                                  ),
                                  const SizedBox(height: 16),

                                  // Email
                                  Text("Email", style: _labelStyle()),
                                  const SizedBox(height: 6),
                                  _buildTextFormField(
                                    controller: _emailController,
                                    hintText: "name@domain.com",
                                    keyboardType: TextInputType.emailAddress,
                                    prefixIcon:
                                        const Icon(Icons.email_outlined),
                                    validator: (value) {
                                      final v = value?.trim() ?? '';
                                      final ok = RegExp(
                                        r"^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,}$",
                                      ).hasMatch(v);
                                      return ok ? null : 'Email không hợp lệ';
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // Password
                                  Text("Password", style: _labelStyle()),
                                  const SizedBox(height: 6),
                                  _buildTextFormField(
                                    controller: _passwordController,
                                    hintText: "••••••••",
                                    obscureText: _obscure,
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      onPressed: () =>
                                          setState(() => _obscure = !_obscure),
                                      icon: Icon(
                                        _obscure
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                      ),
                                    ),
                                    validator: (value) {
                                      final v = value ?? '';
                                      if (v.length < 8) {
                                        return 'Password phải có ít nhất 8 ký tự';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 10),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12.0),
                                    child: Text(
                                      "Dùng 8+ ký tự với một số và một ký hiệu.",
                                      style: _hintStyle(),
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  // Nút Create account (giữ logic Provider)
                                  _buildPrimaryButton(context),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ======= Blob helper =======
  Widget _blurBlob({required double size, required Color color}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color, blurRadius: 48, spreadRadius: 10)],
      ),
    );
  }

  // Helper "dịch" .segmented (UI mượt hơn, logic giữ nguyên)
  Widget _buildSegmentedControl(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE4F4EE), // CSS: background:#e4f4ee
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.greenLightBorder.withOpacity(0.5)),
      ),
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          // Nút Login (không active)
          Expanded(
            child: TextButton(
              style: TextButton.styleFrom(
                backgroundColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onPressed: () {
                Navigator.of(context).pushReplacementNamed('/login');
              },
              child: const Text(
                "Login",
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.greenText,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Nút Sign Up (active)
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient, // CSS: .pill
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.20),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  )
                ],
              ),
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onPressed: null, // Đã active
                child: const Text(
                  "Sign Up",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper "dịch" .field label
  TextStyle _labelStyle() {
    return const TextStyle(
      fontSize: 12,
      color: AppColors.muted,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.4,
    );
  }

  // Helper "dịch" .hint
  TextStyle _hintStyle() {
    return const TextStyle(
      fontSize: 12,
      color: AppColors.muted,
    );
  }

  // Helper "dịch" .input — giữ API cũ, chỉ thêm icon & state lỗi
  Widget _buildTextFormField({
    required TextEditingController controller,
    required String hintText,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: AppColors.muted),
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFFF7FAF9), // CSS: --input
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE6F1ED)), // CSS: --line
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE6F1ED)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.red.shade400, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.red.shade400, width: 1.2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  // Helper "dịch" .primary-btn — giữ logic Consumer, chỉ làm đẹp
  Widget _buildPrimaryButton(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.35),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: auth.isLoading ? null : _handleRegister,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: auth.isLoading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    "Create account",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
          ),
        );
      },
    );
  }
}
