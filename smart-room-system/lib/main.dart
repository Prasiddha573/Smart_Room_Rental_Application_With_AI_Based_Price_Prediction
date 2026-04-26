import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:smart_room/screens/home/splash_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Import Supabase
import 'package:permission_handler/permission_handler.dart'; // Import Permission Handler
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import 'controllers/auth_controller.dart';
import 'controllers/loader_controller.dart';
import 'controllers/show_password_controller.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/toast_service.dart';
import 'config.dart'; // Import your config file
import 'chat/services/chat_service.dart';

/// Main Application Entry Point
Future<void> main() async {
  /// Ensure Flutter Framework Is Initialized Before Any Async Operations
  WidgetsFlutterBinding.ensureInitialized();

  /// Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  /// Initialize Supabase
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
    debug: false, // Set to true for debugging in development
  );

  /// Initialize Permission Handler
  await _initializePermissionHandler();

  /// Set Transparent Status Bar With Dark Icons (Black Icons)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, // Transparent Status Bar
      statusBarIconBrightness: Brightness.dark, // Black Icons For Android
      statusBarBrightness: Brightness.light, // Black Icons For iOS
      systemNavigationBarColor: Colors.white, // White Navigation Bar
      systemNavigationBarIconBrightness:
          Brightness.dark, // Black Navigation Icons
    ),
  );

  runApp(const MyApp());
}

/// Initialize Permission Handler and request necessary permissions
Future<void> _initializePermissionHandler() async {
  try {
    // Request location permissions if needed (for location picker)
    await Permission.location.request();

    // Request storage permissions for image picking (if needed)
    if (await Permission.storage.isDenied) {
      await Permission.storage.request();
    }

    // Request camera permissions (if your app uses camera)
    if (await Permission.camera.isDenied) {
      await Permission.camera.request();
    }

    // Request notification permissions (if your app uses notifications)
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    // You can add more permissions based on your app's needs

    debugPrint('Permission Handler initialized successfully');
  } catch (e) {
    debugPrint('Error initializing Permission Handler: $e');
  }
}

/// Root Application Widget
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Smart Room',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
      ),
      initialBinding: AppBindings(),
      home: const AppHome(),
    );
  }
}

/// Dependency Injection Binding Class
class AppBindings extends Bindings {
  @override
  void dependencies() {
    // Register Controllers
    Get.lazyPut(() => LoaderController(), fenix: true);
    Get.lazyPut(() => ShowPasswordController(), fenix: true);
    Get.lazyPut(() => AuthController(), fenix: true);

    // Register Services
    Get.lazyPut(() => AuthService(), fenix: true);
    Get.lazyPut(() => ToastService(), fenix: true);

    // Register ChatService
    Get.lazyPut(() => ChatService(), fenix: true);

    // Register Permission Handler Service
    Get.lazyPut(() => PermissionHandlerService(), fenix: true);

    // Get Supabase client instance
    Get.lazyPut(() => Supabase.instance.client, fenix: true);
  }
}

/// Permission Handler Service (Optional - for managing permissions via GetX)
class PermissionHandlerService extends GetxService {
  /// Check if location permission is granted
  Future<bool> get isLocationGranted async {
    final status = await Permission.location.status;
    return status.isGranted;
  }

  /// Request location permission
  Future<PermissionStatus> requestLocationPermission() async {
    return await Permission.location.request();
  }

  /// Check if storage permission is granted
  Future<bool> get isStorageGranted async {
    final status = await Permission.storage.status;
    return status.isGranted;
  }

  /// Request storage permission
  Future<PermissionStatus> requestStoragePermission() async {
    return await Permission.storage.request();
  }

  /// Check if camera permission is granted
  Future<bool> get isCameraGranted async {
    final status = await Permission.camera.status;
    return status.isGranted;
  }

  /// Request camera permission
  Future<PermissionStatus> requestCameraPermission() async {
    return await Permission.camera.request();
  }

  /// Open app settings for manual permission enabling
  Future<void> openAppSettings() async {
    await openAppSettings();
  }

  /// Check all required permissions at once
  Future<Map<String, bool>> checkAllPermissions() async {
    return {
      'location': await Permission.location.isGranted,
      'storage': await Permission.storage.isGranted,
      'camera': await Permission.camera.isGranted,
    };
  }
}

/// Main Application Home Widget
class AppHome extends StatefulWidget {
  const AppHome({super.key});

  @override
  State<AppHome> createState() => _AppHomeState();
}

class _AppHomeState extends State<AppHome> {
  @override
  void initState() {
    super.initState();
    // Initialize chat system after app starts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeChat();
    });
  }

  Future<void> _initializeChat() async {
  await Future.delayed(const Duration(seconds: 2));
  try {
    final chatService = Get.find<ChatService>();
    
    // Debug current user using alias
    final firebase_auth.User? currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      print('👤 Current Firebase Auth user:');
      print('   UID: ${currentUser.uid}');
      print('   Email: ${currentUser.email}');
    } else {
      print('👤 No user logged in');
    }
    
    print('✅ Chat system initialized');
  } catch (e) {
    print('❌ Error initializing chat: $e');
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Colors.white, body: SplashScreen());
  }
}