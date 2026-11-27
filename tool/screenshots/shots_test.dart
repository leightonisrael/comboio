// ignore_for_file: invalid_use_of_visible_for_testing_member
// Gera as capturas de tela das lojas e os ícones do app a partir dos widgets
// reais, sem emulador. Não faz parte da suíte de testes.
//
//   flutter test tool/screenshots/shots_test.dart
//
// Saída: store/ (capturas e artes das lojas), ios/.../AppIcon.appiconset e
// android/.../mipmap-* (ícones).

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:comboio/app.dart';
import 'package:comboio/core/discovery.dart';
import 'package:comboio/core/feedback_service.dart';
import 'package:comboio/core/peer_link.dart';
import 'package:comboio/core/platform_bridge.dart';
import 'package:comboio/core/protocol.dart';
import 'package:comboio/core/room_controller.dart';
import 'package:comboio/core/settings_store.dart';
import 'package:comboio/design/theme.dart';
import 'package:comboio/design/tokens.dart';
import 'package:comboio/features/guide_screen.dart';
import 'package:comboio/features/home_screen.dart';
import 'package:comboio/features/room_screen.dart';
import 'package:comboio/features/settings_screen.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _boundary = GlobalKey();

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(
      Future.value(ByteData.view(File(f).readAsBytesSync().buffer)),
    );
  }
  await loader.load();
}

/// Renderiza [child] em [logical] × [dpr] e grava um PNG sem canal alfa
/// (a App Store recusa ícones com transparência).
Future<void> _capture(
  WidgetTester tester,
  String path,
  Widget child, {
  required Size logical,
  required double dpr,
  int frames = 24,
}) async {
  tester.view.physicalSize = logical * dpr;
  tester.view.devicePixelRatio = dpr;
  await tester.pumpWidget(RepaintBoundary(key: _boundary, child: child));
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  final ro = tester.renderObject<RenderRepaintBoundary>(find.byKey(_boundary));
  await tester.runAsync(() async {
    final image = await ro.toImage(pixelRatio: dpr);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final rgba = img.Image.fromBytes(
      width: image.width,
      height: image.height,
      bytes: data!.buffer,
      numChannels: 4,
    );
    final file = File(path)..createSync(recursive: true);
    file.writeAsBytesSync(img.encodePng(rgba.convert(numChannels: 3)));
  });
  // Desmonta para encerrar temporizadores e animações da tela.
  await tester.pumpWidget(const SizedBox());
}

/// Símbolo do app: ponto laranja, duas ondas, ponto verde.
class _IconArt extends StatelessWidget {
  const _IconArt({this.zoom = 1});

  final double zoom;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFF0A0B0D),
    child: CustomPaint(painter: _IconPainter(zoom), size: Size.infinite),
  );
}

class _IconPainter extends CustomPainter {
  _IconPainter(this.zoom);

  final double zoom;

  @override
  void paint(Canvas canvas, Size size) {
    // Mesmas coordenadas do vetor Android (viewport 108), recortando a área
    // visível central de 72 unidades.
    final s = size.shortestSide / 72 * zoom;
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(s);
    canvas.translate(-55, -54);
    const orange = Color(0xFFFF8A00);
    final stroke = Paint()
      ..color = orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(const Offset(35, 54), 6, Paint()..color = orange);
    for (final r in const [14.0, 26.0]) {
      canvas.drawArc(
        Rect.fromCircle(center: const Offset(35, 54), radius: r),
        -math.pi / 4,
        math.pi / 2,
        false,
        stroke,
      );
    }
    canvas.drawCircle(
      const Offset(75, 54),
      6,
      Paint()..color = const Color(0xFF2EE86B),
    );
  }

  @override
  bool shouldRepaint(_IconPainter old) => old.zoom != zoom;
}

class _FeatureGraphic extends StatelessWidget {
  const _FeatureGraphic();

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: ColoredBox(
      color: const Color(0xFF0A0B0D),
      child: Row(
        children: [
          const SizedBox(width: 420, height: 500, child: _IconArt(zoom: 0.9)),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'COMBOIO',
                  style: Ty.display.copyWith(
                    color: const Color(0xFFFF8A00),
                    fontSize: 132,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'INTERCOM DE MOTO\nSEM INTERNET',
                  style: Ty.title.copyWith(
                    color: Colors.white,
                    fontSize: 50,
                    height: 1.08,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

void main() {
  late Settings settings;
  late FeedbackService feedback;
  late PlatformBridge platform;

  setUpAll(() async {
    final sdk = Platform.environment['FLUTTER_ROOT']!;
    final fonts = '$sdk/bin/cache/artifacts/material_fonts';
    await _loadFont('SairaCondensed', [
      'assets/fonts/SairaCondensed-SemiBold.ttf',
      'assets/fonts/SairaCondensed-Bold.ttf',
    ]);
    await _loadFont('Roboto', [
      '$fonts/roboto-regular.ttf',
      '$fonts/roboto-medium.ttf',
      '$fonts/roboto-bold.ttf',
    ]);
    await _loadFont('MaterialIcons', ['$fonts/materialicons-regular.otf']);

    SharedPreferences.setMockInitialValues({
      'peerId': 'a1b2c3d4e5f60718',
      'pin': '482915',
      'name': 'Israel',
      'color': 0,
      'onboarded': true,
      'guideSeen': true,
      'known': '{"leo":"111222"}',
    });
    settings = Settings();
    await settings.load();
    feedback = FeedbackService()..voiceEnabled = false;
    platform = PlatformBridge();
  });

  RoomController room({
    List<(String, int, bool)> pilots = const [],
    bool host = true,
    bool transmitting = false,
    bool pttDown = false,
  }) {
    final r = RoomController(settings, feedback, platform)
      ..phase = RoomPhase.active
      ..isHost = host
      ..roomName = 'Sala de Israel'
      ..pin = '482915'
      ..localIps = const ['192.168.43.1']
      ..transmitting = transmitting
      ..pttDown = pttDown
      ..localLevel = transmitting ? 0.28 : 0;
    for (final (name, color, talking) in pilots) {
      r.pilots[name] = PilotView(PeerInfo(id: name, name: name, color: color))
        ..state = LinkState.connected
        ..everConnected = true
        ..quality = 4
        ..talking = talking
        ..level = talking ? 0.3 : 0;
    }
    return r;
  }

  Widget app(Widget home, RoomController r, {Brightness b = Brightness.dark}) =>
      Deps(
        settings: settings,
        room: r,
        feedback: feedback,
        platform: platform,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildTheme(b),
          home: home,
        ),
      );

  final rooms = [
    RoomAd(
      ip: '192.168.43.1',
      room: 'Sala de Léo',
      hostId: 'leo',
      hostName: 'Léo',
      color: 2,
      count: 1,
      max: 6,
    ),
    RoomAd(
      ip: '192.168.43.7',
      room: 'Sala de Marina',
      hostId: 'marina',
      hostName: 'Marina',
      color: 3,
      count: 2,
      max: 6,
    ),
  ];

  // (pasta, tamanho lógico, densidade) -> App Store 6,9" e Google Play (2:1).
  const targets = [
    ('store/ios', Size(440, 956), 3.0), // 1320 x 2868
    ('store/android', Size(432, 864), 2.5), // 1080 x 2160
  ];

  testWidgets('capturas de tela', (tester) async {
    for (final (dir, size, dpr) in targets) {
      Future<void> shot(String name, Widget w) =>
          _capture(tester, '$dir/$name.png', w, logical: size, dpr: dpr);

      settings.mode = TalkMode.open;
      await shot(
        '1-sala',
        app(const RoomScreen(), room(pilots: const [('Léo', 2, true)])),
      );
      await shot('2-home', app(HomeScreen(previewRooms: rooms), room()));
      await shot('3-como-conectar', app(const GuideScreen(), room()));
      await shot(
        '4-grupo',
        app(
          const RoomScreen(),
          room(
            pilots: const [
              ('Léo', 2, false),
              ('Marina', 3, true),
              ('Caio', 1, false),
              ('Bia', 5, false),
            ],
          ),
        ),
      );
      settings.mode = TalkMode.ptt;
      await shot(
        '5-ptt',
        app(
          const RoomScreen(),
          room(
            pilots: const [('Léo', 2, false)],
            transmitting: true,
            pttDown: true,
          ),
        ),
      );
      settings.mode = TalkMode.open;
      await shot('6-criar-sala', app(const RoomScreen(), room()));
      await shot('7-configuracoes', app(const SettingsScreen(), room()));
    }
  });

  testWidgets('icones e artes das lojas', (tester) async {
    Future<void> icon(String path, double px, {double zoom = 1}) => _capture(
      tester,
      path,
      _IconArt(zoom: zoom),
      logical: Size.square(px),
      dpr: 1,
      frames: 1,
    );

    const ios = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
    const iosSizes = {
      'Icon-App-1024x1024@1x': 1024.0,
      'Icon-App-20x20@1x': 20.0,
      'Icon-App-20x20@2x': 40.0,
      'Icon-App-20x20@3x': 60.0,
      'Icon-App-29x29@1x': 29.0,
      'Icon-App-29x29@2x': 58.0,
      'Icon-App-29x29@3x': 87.0,
      'Icon-App-40x40@1x': 40.0,
      'Icon-App-40x40@2x': 80.0,
      'Icon-App-40x40@3x': 120.0,
      'Icon-App-60x60@2x': 120.0,
      'Icon-App-60x60@3x': 180.0,
      'Icon-App-76x76@1x': 76.0,
      'Icon-App-76x76@2x': 152.0,
      'Icon-App-83.5x83.5@2x': 167.0,
    };
    for (final e in iosSizes.entries) {
      await icon('$ios/${e.key}.png', e.value, zoom: 0.92);
    }

    const android = 'android/app/src/main/res';
    const densities = {
      'mdpi': 48.0,
      'hdpi': 72.0,
      'xhdpi': 96.0,
      'xxhdpi': 144.0,
      'xxxhdpi': 192.0,
    };
    for (final e in densities.entries) {
      await icon('$android/mipmap-${e.key}/ic_launcher.png', e.value);
    }

    await icon('store/icone-512.png', 512, zoom: 0.92);
    await _capture(
      tester,
      'store/destaque-1024x500.png',
      const _FeatureGraphic(),
      logical: const Size(1024, 500),
      dpr: 1,
      frames: 1,
    );
  });
}
