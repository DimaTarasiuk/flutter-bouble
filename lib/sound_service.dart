import 'package:audioplayers/audioplayers.dart';

/// Звук нового повідомлення. Сам файл `assets/sounds/bulk-10.mp3`
/// треба скопіювати з `front/src/static/bulk-10.mp3` React-проєкту —
/// я не маю до нього доступу. Без файлу просто не буде звуку (без крашу).
class SoundService {
  static final AudioPlayer _player = AudioPlayer();

  static Future<void> playNewMessage() async {
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/bulk-10.mp3'));
    } catch (_) {
      // немає файлу або звук вимкнено системою — тихо ігноруємо
    }
  }
}
