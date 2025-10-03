// lib/services/notification_audio_service.dart

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class NotificationAudioService {
  static final NotificationAudioService _instance =
      NotificationAudioService._internal();
  factory NotificationAudioService() => _instance;
  NotificationAudioService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isLooping = false;

  /// Play notification sound for new orders (looping until stopped)
  Future<void> playNewOrderSound() async {
    try {
      _isLooping = true;
      await _audioPlayer.setReleaseMode(ReleaseMode.loop); // Set to loop mode
      await _audioPlayer.play(AssetSource('sounds/order-success.mp3'));
      if (kDebugMode) {
        print('🔊 Playing new order notification sound (looping)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('🔇 Failed to play new order sound: $e');
      }
    }
  }

  /// Play notification sound for cancelled orders (looping until stopped)
  Future<void> playCancelOrderSound() async {
    try {
      _isLooping = true;
      await _audioPlayer.setReleaseMode(ReleaseMode.loop); // Set to loop mode
      await _audioPlayer.play(AssetSource('sounds/order-success.mp3'));
      if (kDebugMode) {
        print('🔊 Playing cancel order notification sound (looping)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('🔇 Failed to play cancel order sound: $e');
      }
    }
  }

  /// Stop any currently playing notification sound
  Future<void> stopSound() async {
    try {
      _isLooping = false;
      await _audioPlayer.stop();
      await _audioPlayer.setReleaseMode(
        ReleaseMode.release,
      ); // Reset to normal mode
      if (kDebugMode) {
        print('🔇 Stopped notification sound');
      }
    } catch (e) {
      if (kDebugMode) {
        print('🔇 Failed to stop notification sound: $e');
      }
    }
  }

  /// Check if sound is currently looping
  bool get isLooping => _isLooping;

  /// Dispose of the audio player resources
  void dispose() {
    _audioPlayer.dispose();
  }
}
