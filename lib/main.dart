import 'package:flutter/material.dart';
import 'package:smart_medicine_reminder_new/screens/login_page.dart';
import 'package:smart_medicine_reminder_new/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // ✅ required before async calls
  await NotificationService().initNotification(); // ✅ initialize notification

  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: LoginPage(),
  ));
}
