import 'dart:async';

import 'package:boat/boat_media.dart';
import 'package:fairy/fairy.dart';

/// Holds the single [BoatMediaPlayer] instance for the app lifetime.
///
/// Registered as a [FairyLocator] singleton so the media bus is created once
/// and disposed with the app.
class MediaService with Disposable {
  final player = BoatMediaPlayer();

  @override
  void dispose() {
    unawaited(player.dispose().catchError((_) {}));
    super.dispose();
  }
}
