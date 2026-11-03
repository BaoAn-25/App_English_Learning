import 'package:flutter/material.dart';
import '../../data/audio_repository.dart';
import '../theme/app_tokens.dart';
import 'app_audio_controller.dart';

/// Widget thanh phát âm thanh chuẩn hóa của ứng dụng EngPass THPT
class AppAudioPlayerWidget extends StatefulWidget {
  final AudioTrack track;
  final String? title;
  final String? subtitle;
  final VoidCallback? onCompleted;
  final bool compact;

  const AppAudioPlayerWidget({
    super.key,
    required this.track,
    this.title,
    this.subtitle,
    this.onCompleted,
    this.compact = false,
  });

  @override
  State<AppAudioPlayerWidget> createState() => _AppAudioPlayerWidgetState();
}

class _AppAudioPlayerWidgetState extends State<AppAudioPlayerWidget> {
  final AppAudioController _controller = AppAudioController.instance;
  bool _isDragging = false;
  double _dragValue = 0.0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onAudioUpdate);
  }

  @override
  void dispose() {
    _controller.removeListener(_onAudioUpdate);
    super.dispose();
  }

  void _onAudioUpdate() {
    if (mounted) {
      if (_controller.playerState.name == 'completed') {
        widget.onCompleted?.call();
      }
      setState(() {});
    }
  }

  String _formatDuration(Duration d) {
    final mins = d.inMinutes;
    final secs = d.inSeconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  bool get _isCurrentTrack =>
      _controller.currentAssetPath == widget.track.assetPath;

  @override
  Widget build(BuildContext context) {
    final isCurrent = _isCurrentTrack;
    final isPlaying = isCurrent && _controller.isPlaying;
    final isLoading = isCurrent && _controller.isLoading;
    final position = isCurrent ? _controller.position : Duration.zero;
    final duration = (isCurrent && _controller.duration > Duration.zero)
        ? _controller.duration
        : Duration(milliseconds: (widget.track.durationSeconds * 1000).round());

    final maxMs = duration.inMilliseconds.toDouble();
    final currentMs = _isDragging
        ? _dragValue
        : position.inMilliseconds.toDouble().clamp(0.0, maxMs > 0 ? maxMs : 1.0);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: widget.compact ? 12 : 16,
        vertical: widget.compact ? 10 : 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Tiêu đề + Huy hiệu ngoại tuyến
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: isPlaying ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.headphones_rounded,
                  size: 18,
                  color: isPlaying ? const Color(0xFFD97706) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title ?? 'Audio SGK Tiếng Anh 12',
                      style: const TextStyle(
                        fontFamily: 'BeVietnamPro',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle!,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // Huy hiệu Có sẵn ngoại tuyến
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.offline_pin_outlined, size: 12, color: AppTokens.primary),
                    SizedBox(width: 4),
                    Text(
                      'Ngoại tuyến',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppTokens.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Thanh tiến trình (Slider)
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              activeTrackColor: AppTokens.primary,
              inactiveTrackColor: const Color(0xFFE2E8F0),
              thumbColor: AppTokens.primary,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              min: 0.0,
              max: maxMs > 0 ? maxMs : 1.0,
              value: currentMs.clamp(0.0, maxMs > 0 ? maxMs : 1.0),
              onChangeStart: (_) {
                setState(() {
                  _isDragging = true;
                });
              },
              onChanged: (val) {
                setState(() {
                  _dragValue = val;
                });
              },
              onChangeEnd: (val) async {
                _isDragging = false;
                await _controller.seek(Duration(milliseconds: val.round()));
              },
            ),
          ),

          // Hiển thị thời gian và các nút điều khiển
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Thời gian hiện tại / Tổng thời gian
              Text(
                '${_formatDuration(position)} / ${_formatDuration(duration)}',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),

              // Bộ nút điều khiển
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Nút chọn tốc độ phát
                  _buildSpeedSelector(),

                  const SizedBox(width: 6),

                  // Nút Replay (Nghe lại từ đầu)
                  IconButton(
                    icon: const Icon(Icons.replay_rounded, size: 20, color: Color(0xFF475569)),
                    tooltip: 'Nghe lại từ đầu',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: isCurrent ? () => _controller.replay() : null,
                  ),

                  const SizedBox(width: 10),

                  // Nút Play/Pause chính
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () async {
                        if (isLoading) return;
                        if (isPlaying) {
                          await _controller.pause();
                        } else if (isCurrent) {
                          await _controller.resume();
                        } else {
                          await _controller.playAsset(
                            assetPath: widget.track.assetPath,
                            trackId: widget.track.id,
                            fallbackDurationSeconds: widget.track.durationSeconds,
                          );
                        }
                      },
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTokens.primary,
                        ),
                        child: Center(
                          child: isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(
                                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Hiển thị thông báo lỗi nếu có
          if (isCurrent && _controller.errorMessage != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.error_outline_rounded, size: 14, color: AppTokens.errorRed),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _controller.errorMessage!,
                    style: const TextStyle(fontSize: 11, color: AppTokens.errorRed),
                  ),
                ),
                TextButton(
                  onPressed: () => _controller.playAsset(
                    assetPath: widget.track.assetPath,
                    trackId: widget.track.id,
                  ),
                  child: const Text('Thử lại', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSpeedSelector() {
    final speeds = [0.75, 1.0, 1.25, 1.5];
    final currentSpeed = _controller.playbackRate;

    return PopupMenuButton<double>(
      initialValue: currentSpeed,
      tooltip: 'Tốc độ phát',
      padding: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${currentSpeed}x',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
            const Icon(Icons.arrow_drop_down_rounded, size: 16, color: Color(0xFF64748B)),
          ],
        ),
      ),
      onSelected: (speed) => _controller.setPlaybackRate(speed),
      itemBuilder: (ctx) => speeds
          .map(
            (s) => PopupMenuItem<double>(
              value: s,
              height: 34,
              child: Row(
                children: [
                  Text(
                    '${s}x',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: s == currentSpeed ? FontWeight.w700 : FontWeight.w500,
                      color: s == currentSpeed ? AppTokens.primary : const Color(0xFF0F172A),
                    ),
                  ),
                  if (s == currentSpeed) ...[
                    const Spacer(),
                    const Icon(Icons.check_rounded, size: 16, color: AppTokens.primary),
                  ],
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

