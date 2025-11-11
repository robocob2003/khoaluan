// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io' show Platform;

import 'package:video_player_win/video_player_win.dart';

import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/websocket_provider.dart';
import 'providers/file_transfer_provider.dart';
import 'providers/group_provider.dart';
import 'providers/navigation_provider.dart';
import 'providers/comment_provider.dart';
// ---- THÊM IMPORT MỚI ----
import 'providers/friend_provider.dart';
// -------------------------

import 'models/group.dart';
import 'models/comment.dart';

import 'screens/login_page.dart';
import 'screens/register_page.dart';
import 'screens/main_layout.dart';
import 'screens/chat_screen.dart';
import 'screens/file_manager_screen.dart';
import 'services/db_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    WindowsVideoPlayer.registerWith();
  }

  await DBService.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Provider cơ bản
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),

        // Provider phụ thuộc (Proxy)
        ChangeNotifierProxyProvider<AuthProvider, GroupProvider>(
          create: (context) => GroupProvider(),
          update: (context, auth, groupProvider) {
            if (groupProvider == null)
              throw ArgumentError.notNull('groupProvider');
            groupProvider.setAuthProvider(auth);
            return groupProvider;
          },
        ),

        ChangeNotifierProxyProvider<AuthProvider, CommentProvider>(
          create: (context) => CommentProvider(),
          update: (context, auth, commentProvider) {
            if (commentProvider == null)
              throw ArgumentError.notNull('commentProvider');
            commentProvider.setAuthProvider(auth);
            return commentProvider;
          },
        ),

        // ---- THÊM FRIEND PROVIDER ----
        ChangeNotifierProxyProvider<AuthProvider, FriendProvider>(
          create: (context) => FriendProvider(),
          update: (context, auth, friendProvider) {
            if (friendProvider == null)
              throw ArgumentError.notNull('friendProvider');
            friendProvider.setAuthProvider(auth);
            return friendProvider;
          },
        ),
        // -----------------------------

        ChangeNotifierProxyProvider<AuthProvider, FileTransferProvider>(
          create: (context) => FileTransferProvider(),
          update: (context, auth, fileProvider) {
            if (fileProvider == null)
              throw ArgumentError.notNull('fileProvider');
            fileProvider.setAuthProvider(auth);
            return fileProvider;
          },
        ),

        // ---- SỬA WEBSOCKET PROVIDER (Giờ phụ thuộc 5 provider) ----
        ChangeNotifierProxyProvider5<AuthProvider, FileTransferProvider,
            GroupProvider, CommentProvider, FriendProvider, WebSocketProvider>(
          create: (context) => WebSocketProvider(),
          update: (context, authProvider, fileProvider, groupProvider,
              commentProvider, friendProvider, wsProvider) {
            // Thêm friendProvider
            if (wsProvider == null) throw ArgumentError.notNull('wsProvider');
            if (fileProvider == null)
              throw ArgumentError.notNull('fileProvider');
            if (groupProvider == null)
              throw ArgumentError.notNull('groupProvider');
            if (commentProvider == null)
              throw ArgumentError.notNull('commentProvider');
            if (friendProvider == null) // Thêm
              throw ArgumentError.notNull('friendProvider');

            wsProvider.setAuthProvider(authProvider);
            wsProvider.setupFileTransferListeners(fileProvider);
            wsProvider.setGroupProvider(groupProvider);
            wsProvider.setCommentProvider(commentProvider);
            wsProvider.setFriendProvider(friendProvider); // Thêm

            fileProvider.setWebSocketService(wsProvider.webSocketService);
            groupProvider.setWebSocketService(wsProvider.webSocketService);
            friendProvider
                .setWebSocketService(wsProvider.webSocketService); // Thêm

            return wsProvider;
          },
        ),
        // -----------------------------------------------------
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, child) {
          return MaterialApp(
            title: 'Flutter Chat App',
            debugShowCheckedModeBanner: false,
            theme: theme.theme,
            initialRoute: '/login',
            routes: {
              '/login': (_) => LoginPage(),
              '/register': (_) => RegisterPage(),
              '/home': (_) => MainLayout(),
              '/chat': (context) {
                final args = ModalRoute.of(context)?.settings.arguments
                    as Map<String, dynamic>?;
                return ChatScreen(
                  initialRecipientUsername: args?['username'] as String?,
                );
              },
              '/file-manager': (_) => const FileManagerScreen(),
            },
          );
        },
      ),
    );
  }
}
