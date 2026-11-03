import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Quản lý phát âm thanh tập trung, đảm bảo chỉ có 1 track phát tại một thời điểm
/// và cung cấp trạng thái thực từ AudioPlayer stream.
class AppAudioController extends ChangeNotifier {
  static final AppAudioController instance = AppAudioController._internal();
  AppAudioController._internal() {
    _initPlayer();
  }

  late final AudioPlayer _player;

  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<void>? _completeSub;

  String? _currentAssetPath;
  String? _currentTrackId;
  PlayerState _playerState = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _playbackRate = 1.0;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  String? get currentAssetPath => _currentAssetPath;
  String? get currentTrackId => _currentTrackId;
  PlayerState get playerState => _playerState;
  bool get isPlaying => _playerState == PlayerState.playing;
  bool get isPaused => _playerState == PlayerState.paused;
  bool get isStopped => _playerState == PlayerState.stopped || _playerState == PlayerState.completed;
  Duration get position => _position;
  Duration get duration => _duration;
  double get playbackRate => _playbackRate;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void _initPlayer() {
    _player = AudioPlayer();
    _player.audioCache.prefix = '';

    _stateSub = _player.onPlayerStateChanged.listen((state) {
      _playerState = state;
      notifyListeners();
    });

    _positionSub = _player.onPositionChanged.listen((pos) {
      _position = pos;
      notifyListeners();
    });

    _durationSub = _player.onDurationChanged.listen((dur) {
      if (dur > Duration.zero) {
        _duration = dur;
        notifyListeners();
      }
    });

    _completeSub = _player.onPlayerComplete.listen((_) {
      _playerState = PlayerState.completed;
      _position = _duration;
      notifyListeners();
    });
  }

  /// Nạp và phát một file MP3 từ assets (ví dụ: assets/audio/global_success_12/listening/unit-01-listening-activity-2.mp3)
  Future<void> playAsset({
    required String assetPath,
    String? trackId,
    Duration? startAt,
    double? fallbackDurationSeconds,
  }) async {
    // Nếu đang phát chính track này và đang pause, bấm play tiếp
    if (_currentAssetPath == assetPath && _playerState == PlayerState.paused) {
      await resume();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    _currentAssetPath = assetPath;
    _currentTrackId = trackId;
    if (fallbackDurationSeconds != null && fallbackDurationSeconds > 0) {
      _duration = Duration(milliseconds: (fallbackDurationSeconds * 1000).round());
    } else {
      _duration = Duration.zero;
    }
    _position = startAt ?? Duration.zero;
    notifyListeners();

    try {
      // Dừng bài đang phát trước đó để tránh chồng tiếng
      await _player.stop();

      // Cấu hình source và phát
      final cleanPath = assetPath.startsWith('assets/') ? assetPath.substring(7) : assetPath;
      _player.audioCache.prefix = 'assets/';

      await _player.play(AssetSource(cleanPath));
      if (_playbackRate != 1.0) {
        await _player.setPlaybackRate(_playbackRate);
      }

      if (startAt != null && startAt > Duration.zero) {
        await _player.seek(startAt);
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      if (e.toString().contains('MissingPluginException')) {
        _errorMessage = 'Cần biên dịch Native Audio: Vui lòng dừng ứng dụng và chạy lại "flutter run" trên máy tính để thiết bị nạp plugin âm thanh.';
      } else {
        _errorMessage = 'Không thể phát âm thanh: $e';
      }
      _playerState = PlayerState.stopped;
      notifyListeners();
    }
  }

  /// Tạm dừng
  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (_) {}
  }

  /// Tiếp tục phát
  Future<void> resume() async {
    try {
      await _player.resume();
    } catch (_) {}
  }

  /// Tua đến vị trí cụ thể
  Future<void> seek(Duration target) async {
    try {
      await _player.seek(target);
      _position = target;
      notifyListeners();
    } catch (_) {}
  }

  /// Nghe lại từ đầu
  Future<void> replay() async {
    try {
      await _player.seek(Duration.zero);
      await _player.resume();
      _position = Duration.zero;
      notifyListeners();
    } catch (_) {}
  }

  /// Thay đổi tốc độ phát: 0.75x, 1.0x, 1.25x, 1.5x
  Future<void> setPlaybackRate(double rate) async {
    _playbackRate = rate;
    try {
      await _player.setPlaybackRate(rate);
    } catch (_) {}
    notifyListeners();
  }

  /// Dừng phát hoàn toàn
  Future<void> stop() async {
    try {
      await _player.stop();
      _playerState = PlayerState.stopped;
      _position = Duration.zero;
      notifyListeners();
    } catch (_) {}
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _completeSub?.cancel();
    _player.dispose();
    super.dispose();
  }
}

