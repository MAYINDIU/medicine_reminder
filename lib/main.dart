import 'package:flutter/material.dart';
import 'package:smart_medicine_reminder_new/screens/splash_screen.dart';
import 'package:smart_medicine_reminder_new/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // ✅ required for async calls
  await NotificationService().initNotification(); // ✅ initialize notifications

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(), // ✅ SplashScreen as initial page
    );
  }
}
