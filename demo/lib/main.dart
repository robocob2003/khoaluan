// demo/lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/identity_service.dart';
import '../services/websocket_service.dart';
import '../services/p2p_service.dart';
import '../screens/main_layout.dart'; // File cũ của bạn
import '../screens/create_identity_screen.dart'; // File mới
import '../config/app_colors.dart'; // File cũ của bạn

void main() async {
  // Cần thiết để khởi tạo service trước khi run app
  WidgetsFlutterBinding.ensureInitialized();

  // --- Khởi tạo các Service Cốt lõi ---
  final identityService = IdentityService();
  await identityService.initializeIdentity(); // Tải hoặc tạo khóa

  final webSocketService = WebSocketService();

  final p2pService = P2PService(identityService, webSocketService);
  // --- (P2PService đã lắng nghe WebSocketService) ---

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: identityService),
        ChangeNotifierProvider.value(value: webSocketService),
        ChangeNotifierProvider.value(value: p2pService),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'P2P Share App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: AppColors.background,
      ),
      debugShowCheckedModeBanner: false,
      home: const AuthWrapper(), // Bọc bởi một Wrapper
    );
  }
}

// Wrapper này kiểm tra xem người dùng đã có định danh chưa
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // Lắng nghe IdentityService
    final isInitialized = context.watch<IdentityService>().isInitialized;

    if (isInitialized) {
      // Nếu đã có định danh, vào app
      return const MainLayout();
    } else {
      // Nếu chưa, yêu cầu tạo
      return const CreateIdentityScreen();
    }
  }
}
