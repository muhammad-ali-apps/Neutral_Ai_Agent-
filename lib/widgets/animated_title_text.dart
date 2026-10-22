import 'package:flutter/material.dart';

/// Sleek non-colorful animated title text with typewriter entrance
/// and continuous monochromatic luminous light shimmer.
class AnimatedTitleText extends StatefulWidget {
  final String text;
  final TextStyle? style;

  const AnimatedTitleText({
    super.key,
    required this.text,
    this.style,
  });

  @override
  State<AnimatedTitleText> createState() => _AnimatedTitleTextState();
}

class _AnimatedTitleTextState extends State<AnimatedTitleText>
    with TickerProviderStateMixin {
  late final AnimationController _typeController;
  late final AnimationController _shimmerController;
  late final Animation<int> _characterCount;

  @override
  void initState() {
    super.initState();
    _typeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _characterCount = StepTween(
      begin: 0,
      end: widget.text.length,
    ).animate(CurvedAnimation(
      parent: _typeController,
      curve: Curves.easeOutCubic,
    ));

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _typeController.forward().then((_) {
      if (mounted) {
        _shimmerController.repeat();
      }
    });
  }

  @override
  void dispose() {
    _typeController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Elegant monochromatic light sweep (Zero rainbow/colorful hues)
    final shimmerColors = isDark
        ? const [
            Color(0xFF888888), // Subtle muted white
            Color(0xFFD4D4D8), // Bright silver
            Colors.white,      // Pure luminous white highlight
            Color(0xFFD4D4D8), // Bright silver
            Color(0xFF888888), // Subtle muted white
          ]
        : const [
            Color(0xFF6B7280), // Slate grey
            Color(0xFF374151), // Dark grey
            Color(0xFF0F172A), // Deep black-slate highlight
            Color(0xFF374151), // Dark grey
            Color(0xFF6B7280), // Slate grey
          ];

    final baseStyle = TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      color: isDark ? Colors.white : const Color(0xFF1E1E1E),
    );

    final effectiveStyle = widget.style != null
        ? baseStyle.merge(widget.style)
        : baseStyle;

    return AnimatedBuilder(
      animation: Listenable.merge([_typeController, _shimmerController]),
      builder: (context, _) {
        final currentLength = _characterCount.value.clamp(0, widget.text.length);
        final displayedText = widget.text.substring(0, currentLength);
        final isTyping = !_typeController.isCompleted;

        Widget textWidget;
        if (isTyping) {
          textWidget = Text(
            displayedText,
            textAlign: TextAlign.center,
            style: effectiveStyle,
          );
        } else {
          textWidget = ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) {
              return LinearGradient(
                begin: const Alignment(-1.0, 0.0),
                end: const Alignment(1.0, 0.0),
                tileMode: TileMode.repeated,
                colors: shimmerColors,
                stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
                transform: _SlidingGradientTransform(
                  slidePercent: _shimmerController.value,
                ),
              ).createShader(bounds);
            },
            child: Text(
              widget.text,
              textAlign: TextAlign.center,
              style: effectiveStyle.copyWith(color: Colors.white),
            ),
          );
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            textWidget,
            if (isTyping)
              AnimatedOpacity(
                opacity: _typeController.value % 0.4 < 0.2 ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 100),
                child: Text(
                  '|',
                  style: effectiveStyle.copyWith(
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;
  const _SlidingGradientTransform({required this.slidePercent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0.0, 0.0);
  }
}
