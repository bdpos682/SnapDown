import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'core/database/database_service.dart';
import 'core/storage/storage_manager.dart';
import 'features/player/service/snap_audio_handler.dart';

late final SnapAudioHandler globalAudioHandler;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize storage sandboxes & database
  await StorageManager().init();
  await DatabaseService().database;

  // Initialize AudioService for background / lockscreen playback
  globalAudioHandler = await AudioService.init(
    builder: () => SnapAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.snapvideo.snapdown.audio',
      androidNotificationChannelName: 'SnapDown Trình phát',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidShowNotificationBadge: true,
    ),
  );

  runApp(
    const ProviderScope(
      child: SnapDownApp(),
    ),
  );
}
