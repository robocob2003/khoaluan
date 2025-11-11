// lib/config/app_colors.dart
import 'package:flutter/material.dart';

// Bảng màu được "dịch" từ tệp CSS của bạn
class AppColors {
  static const Color background = Color(0xFFF3FBF7); // --bg
  static const Color screenBackground = Color(0xFFF2FBF6); // nền screen
  static const Color card = Color(0xFFFFFFFF); // --card
  static const Color text = Color(0xFF0F172A); // --ink
  static const Color muted = Color(0xFF6B7280); // --muted
  static const Color line = Color(0xFFE6F1ED); // --line
  static const Color chipBg = Color(0xFFEDF7F3); // --chip
  static const Color chipBorder = Color(0xFFD8EEE6); // --chipBorder
  static const Color primary = Color(0xFF22C55E); // --primary
  static const Color primaryDark = Color(0xFF10B981); // --primary2
  static const Color greenText = Color(0xFF0B3B2A);
  static const Color greenLight = Color(0xFFEAF6F1);
  static const Color greenLightBorder = Color(0xFFCFE8DE);

  // Gradient cho các nút chính
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ---- THÊM DÒNG BỊ THIẾU VÀO ĐÂY ----
  // Gradient cho nền màn hình
  static const LinearGradient screenGradient = LinearGradient(
    colors: [Color(0xFFF2FBF6), Color(0xFFFFFFFF)],
    begin: Alignment.topCenter,
    end: Alignment(0.0, 0.75), // 75% giống trong HTML
  );
  // -----------------------------------
}
