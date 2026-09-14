import 'package:flutter_riverpod/flutter_riverpod.dart';

final navigationTabProvider =
    NotifierProvider<NavigationTabNotifier, int>(NavigationTabNotifier.new);

class NavigationTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setTab(int index) {
    if (index >= 0 && index <= 3) {
      state = index;
    }
  }

  void switchToHome() => setTab(0);
  void switchToDownloads() => setTab(1);
  void switchToMusic() => setTab(2);
  void switchToVideo() => setTab(3);
}
