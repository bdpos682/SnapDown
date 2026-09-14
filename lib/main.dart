import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/database/database_service.dart';
import 'core/storage/storage_manager.dart';
import 'features/player/service/snap_audio_handler.dart';

late final SnapAudioHandler globalAudioHandler;

void main() async {
  // 1. Giữ Splash Screen ngay lập tức để không bị nháy màn hình trắng
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // 2. Cấu hình giao diện thanh trạng thái (Status Bar / Nav Bar)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // 3. Khởi tạo Storage và Database ngầm
  await StorageManager().init();
  await DatabaseService().database;

  // 4. Khởi tạo Audio Service đồng bộ tên thương hiệu BDSNAP
  globalAudioHandler = await AudioService.init(
    builder: () => SnapAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.bdsnap.audio',
      androidNotificationChannelName: 'BDSNAP Trình phát',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidShowNotificationBadge: true,
    ),
  );

  // 5. Tắt Splash Screen sau khi các dịch vụ đã nạp xong
  FlutterNativeSplash.remove();

  runApp(
    const ProviderScope(
      child: SnapDownApp(),
    ),
  );
}