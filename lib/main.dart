import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/feedback_service.dart';
import 'core/platform_bridge.dart';
import 'core/room_controller.dart';
import 'core/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final settings = Settings();
  await settings.load();
  final feedback = FeedbackService();
  await feedback.init();
  final platform = PlatformBridge();
  platform.init();
  final room = RoomController(settings, feedback, platform);

  runApp(ComboioApp(settings: settings, room: room, feedback: feedback, platform: platform));
}
