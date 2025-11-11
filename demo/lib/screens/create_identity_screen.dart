// demo/lib/screens/create_identity_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:demo/services/identity_service.dart';

class CreateIdentityScreen extends StatelessWidget {
  const CreateIdentityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chào mừng!')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Đây là lần đầu bạn sử dụng ứng dụng.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 20),
              const Text(
                'Chúng tôi cần tạo một "Định danh Phi tập trung" (DID) an toàn cho bạn. Quá trình này sẽ tạo một cặp khóa Public/Private duy nhất trên thiết bị của bạn.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () {
                  // Khi nhấn, service sẽ tạo khóa và lưu lại
                  // AuthWrapper sẽ tự động nhận biết và chuyển màn hình
                  context.read<IdentityService>().initializeIdentity();
                },
                child: const Text('Tạo Định danh An toàn'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
