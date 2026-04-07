import 'package:flutter/material.dart';

/// AppBackground: paints a subtle company logo watermark behind any content.
///
/// Rules honored:
/// - Centered on the main content canvas, no parallax.
/// - 4–6% opacity (slightly lower in dark mode), scales with viewport.
/// - Never exceeds 45% of content width; auto-hides on narrow (<640px) screens.
/// - Fixed behind scroll; does not interfere with text or gestures.
class AppBackground extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  /// When false, the background watermark is not painted.
  final bool watermarkEnabled;
  const AppBackground({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.watermarkEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final opacity = isDark ? 0.04 : 0.06;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Use MediaQuery for deterministic width in tests and runtime
        final size = MediaQuery.of(context).size;
        final w = size.width;
        final h = size.height;
        // Hide on very small screens
        final hide = w < 640;
        final maxContentSide = w.isFinite
            ? w
            : (h.isFinite ? h : MediaQuery.of(context).size.shortestSide);
        // Watermark size capped to 45% of content width
        final markSize = maxContentSide * 0.45;
        final showMark = watermarkEnabled && !hide;
        return Stack(
          fit: StackFit.expand,
          children: [
            // Background layer with logo centered and faint
            IgnorePointer(
              child: Container(
                color: theme.colorScheme.surface, // base surface color
                child: showMark
                    ? Center(
                        child: Opacity(
                          key: const Key('app_watermark'),
                          opacity: opacity,
                          child: _LogoMark(size: markSize),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
            // Foreground content
            Padding(padding: padding, child: child),
          ],
        );
      },
    );
  }
}

class _LogoMark extends StatelessWidget {
  final double size;
  const _LogoMark({required this.size});

  @override
  Widget build(BuildContext context) {
    // Try to load an asset logo. If not found, show a ship icon placeholder.
    return Image.asset(
      'assets/logo/logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stack) {
        // Fallback to alternate filename if needed.
        return Image.asset(
          'assets/logo/truckercorelogo.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (context, error2, stack2) {
            // Final graceful fallback to an icon.
            return Icon(
              Icons.local_shipping,
              size: size,
              color: Colors.blueGrey.shade200,
            );
          },
        );
      },
    );
  }
}
