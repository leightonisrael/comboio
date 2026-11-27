import 'package:material_ui/material_ui.dart';

import 'core/feedback_service.dart';
import 'core/platform_bridge.dart';
import 'core/room_controller.dart';
import 'core/settings_store.dart';
import 'design/theme.dart';
import 'features/home_screen.dart';
import 'features/onboarding_screen.dart';
import 'features/room_screen.dart';

/// Dependências compartilhadas pelas telas.
class Deps extends InheritedWidget {
  const Deps({
    super.key,
    required this.settings,
    required this.room,
    required this.feedback,
    required this.platform,
    required super.child,
  });

  final Settings settings;
  final RoomController room;
  final FeedbackService feedback;
  final PlatformBridge platform;

  static Deps of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<Deps>()!;

  @override
  bool updateShouldNotify(Deps oldWidget) => false;
}

class ComboioApp extends StatelessWidget {
  const ComboioApp({
    super.key,
    required this.settings,
    required this.room,
    required this.feedback,
    required this.platform,
  });

  final Settings settings;
  final RoomController room;
  final FeedbackService feedback;
  final PlatformBridge platform;

  @override
  Widget build(BuildContext context) {
    return Deps(
      settings: settings,
      room: room,
      feedback: feedback,
      platform: platform,
      child: ListenableBuilder(
        listenable: settings,
        builder: (context, _) {
          feedback.voiceEnabled = settings.voiceAlerts;
          return MaterialApp(
            title: 'Comboio',
            debugShowCheckedModeBanner: false,
            theme: buildTheme(Brightness.light),
            darkTheme: buildTheme(Brightness.dark),
            themeMode: settings.themeMode,
            home: settings.onboarded ? const _Root() : const OnboardingScreen(),
          );
        },
      ),
    );
  }
}

/// Mostra a sala enquanto houver uma ativa; caso contrário, a Home.
class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final room = Deps.of(context).room;
    return _RoomSwitch(room: room);
  }
}

class _RoomSwitch extends StatefulWidget {
  const _RoomSwitch({required this.room});

  final RoomController room;

  @override
  State<_RoomSwitch> createState() => _RoomSwitchState();
}

class _RoomSwitchState extends State<_RoomSwitch> {
  late bool _inRoom = widget.room.inRoom;

  @override
  void initState() {
    super.initState();
    widget.room.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.room.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (widget.room.inRoom != _inRoom) {
      setState(() => _inRoom = widget.room.inRoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: _inRoom
          ? const RoomScreen(key: ValueKey('room'))
          : const HomeScreen(key: ValueKey('home')),
    );
  }
}
