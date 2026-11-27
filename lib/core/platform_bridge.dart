import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Estado do capacete Bluetooth. `known == false` quando a plataforma não informa.
class HelmetStatus {
  const HelmetStatus({
    required this.known,
    required this.connected,
    required this.name,
  });
  const HelmetStatus.unknown() : known = false, connected = false, name = '';

  final bool known;
  final bool connected;
  final String name;
}

/// Tudo o que depende do sistema operacional fica atrás desta classe.
class PlatformBridge {
  static const _channel = MethodChannel('comboio/audio');

  void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'comboio_conversa',
        channelName: 'Conversa ativa',
        channelDescription:
            'Mantém a conversa funcionando com a tela bloqueada.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  /// Pede as permissões. Só o microfone é obrigatório.
  Future<bool> ensurePermissions() async {
    // No iOS o pedido do microfone aparece sozinho ao abrir o áudio.
    if (!Platform.isAndroid) return true;
    final mic = await Permission.microphone.request();
    // Recusar estas não impede a conversa: sem Bluetooth o áudio sai pelo
    // celular, e sem notificação o serviço roda sem aviso visível.
    await Permission.bluetoothConnect.request();
    await Permission.notification.request();
    return mic.isGranted;
  }

  Future<void> startBackground(String title) async {
    if (!Platform.isAndroid) return;
    if (await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.startService(
      serviceId: 4780,
      serviceTypes: [ForegroundServiceTypes.microphone],
      notificationTitle: 'Comboio · $title',
      notificationText: 'Conversa ativa. Toque para voltar ao app.',
    );
  }

  Future<void> stopBackground() async {
    if (!Platform.isAndroid) return;
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (_) {}
  }

  /// Sessão de áudio de chamada: é o que abre o link de voz (HFP) do capacete.
  Future<void> configureAudio() async {
    try {
      if (Platform.isAndroid) {
        await Helper.setAndroidAudioConfiguration(
          AndroidAudioConfiguration.communication,
        );
      } else if (Platform.isIOS) {
        await Helper.setAppleAudioConfiguration(
          AppleAudioConfiguration(
            appleAudioCategory: AppleAudioCategory.playAndRecord,
            appleAudioCategoryOptions: {
              AppleAudioCategoryOption.allowBluetooth,
              AppleAudioCategoryOption.mixWithOthers,
            },
            appleAudioMode: AppleAudioMode.voiceChat,
          ),
        );
      }
    } catch (_) {}
  }

  /// Tira o áudio do alto-falante; com o capacete conectado, o sistema usa o Bluetooth.
  Future<void> routeToHelmet() async {
    try {
      await Helper.setSpeakerphoneOn(false);
    } catch (_) {}
  }

  /// Alto-falante do celular (viva-voz) no lugar do capacete ou do fone de
  /// ouvido da chamada.
  Future<void> setSpeaker(bool on) async {
    try {
      await Helper.setSpeakerphoneOn(on);
    } catch (_) {}
  }

  Future<HelmetStatus> helmet() async {
    try {
      final r = await _channel.invokeMapMethod<String, dynamic>('getRoute');
      if (r == null) return const HelmetStatus.unknown();
      return HelmetStatus(
        known: true,
        connected: r['bluetooth'] == true,
        name: '${r['name'] ?? ''}',
      );
    } catch (_) {
      return const HelmetStatus.unknown();
    }
  }

  /// `kind`: bluetooth, wifi, hotspot ou app.
  Future<void> openSettings(String kind) async {
    try {
      await _channel.invokeMethod<void>('openSettings', {'kind': kind});
    } catch (_) {
      await openAppSettings();
    }
  }

  Future<void> keepScreenOn(bool on) async {
    try {
      await WakelockPlus.toggle(enable: on);
    } catch (_) {}
  }

  Future<void> setTrackVolume(MediaStreamTrack track, double volume) async {
    try {
      await Helper.setVolume(volume, track);
    } catch (_) {}
  }
}
