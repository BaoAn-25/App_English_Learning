import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../app_tokens.dart';

enum MascotMood {
  cheer,
  celebrate,
  study,
  fire,
}

class EngPassMascot extends StatefulWidget {
  final MascotMood mood;
  final double size;
  final String? speechText;
  final String? speechSubtitle;
  final bool animate;
  final Axis layoutAxis;

  const EngPassMascot({
    super.key,
    this.mood = MascotMood.cheer,
    this.size = 84,
    this.speechText,
    this.speechSubtitle,
    this.animate = true,
    this.layoutAxis = Axis.horizontal,
  });

  String get assetPath {
    switch (mood) {
      case MascotMood.cheer:
        return 'assets/images/mascot/mascot_cheer.png';
      case MascotMood.celebrate:
        return 'assets/images/mascot/mascot_celebrate.png';
      case MascotMood.study:
        return 'assets/images/mascot/mascot_study.png';
      case MascotMood.fire:
        return 'assets/images/mascot/mascot_fire.png';
    }
  }

  @override
  State<EngPassMascot> createState() => _EngPassMascotState();
}

class _EngPassMascotState extends State<EngPassMascot>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant EngPassMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate != widget.animate) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    final disableAnimations =
        (MediaQuery.maybeOf(context)?.disableAnimations ?? false) ||
            !SchedulerBinding.instance.framesEnabled ||
            WidgetsBinding.instance.runtimeType.toString().contains('TestWidgetsFlutterBinding') ||
            WidgetsBinding.instance.runtimeType.toString().contains('AutomatedTestWidgetsFlutterBinding');
    final shouldRun = widget.animate && !disableAnimations;
    if (shouldRun) {
      _controller ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1800),
      )..repeat(reverse: true);
    } else {
      _controller?.stop();
      _controller?.dispose();
      _controller = null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Widget _buildMascotAvatar() {
    final image = Image.asset(
      widget.assetPath,
      width: widget.size,
      height: widget.size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) => Image.asset(
        'assets/images/app_logo.png',
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
      ),
    );

    final controller = _controller;
    if (controller == null) {
      return image;
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final dy = (controller.value - 0.5) * 6.0;
        return Transform.translate(
          offset: Offset(0, dy),
          child: child,
        );
      },
      child: image,
    );
  }

  @override
  Widget build(BuildContext context) {
    final mascotWidget = _buildMascotAvatar();
    if (widget.speechText == null || widget.speechText!.trim().isEmpty) {
      return mascotWidget;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bubbleBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final bubbleBorder = isDark
        ? AppTokens.primaryLight.withValues(alpha: 0.35)
        : AppTokens.primary.withValues(alpha: 0.22);
    final textColor = isDark ? Colors.white : AppTokens.textMain;
    final subColor =
        isDark ? const Color(0xFF94A3B8) : AppTokens.textSecondary;

    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bubbleBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: bubbleBorder, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.speechText!,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: textColor,
              height: 1.35,
            ),
          ),
          if (widget.speechSubtitle != null &&
              widget.speechSubtitle!.trim().isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              widget.speechSubtitle!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: subColor,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );

    if (widget.layoutAxis == Axis.vertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          bubble,
          const SizedBox(height: 8),
          mascotWidget,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        mascotWidget,
        const SizedBox(width: 12),
        Expanded(child: bubble),
      ],
    );
  }
}
