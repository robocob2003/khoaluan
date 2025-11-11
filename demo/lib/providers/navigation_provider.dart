// lib/providers/navigation_provider.dart
import 'package:flutter/material.dart';

class NavigationProvider with ChangeNotifier {
  int _currentIndex = 0;
  int get currentIndex => _currentIndex;

  // Dùng hàm này để thay đổi tab từ bất cứ đâu
  void changeTab(int index) {
    _currentIndex = index;
    notifyListeners();
  }
}
