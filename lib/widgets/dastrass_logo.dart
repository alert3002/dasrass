import 'package:flutter/material.dart';

/// Логотип dastrass — мисли `frontend/public/logo1.jpg` (`.header-logo-img`).
class DastrassLogo extends StatelessWidget {
  const DastrassLogo({
    super.key,
    this.onTap,
    this.height = 42,
    this.maxWidth = 180,
    this.semanticLabel = 'dastrass',
  });

  final VoidCallback? onTap;
  final double height;
  final double maxWidth;
  final String semanticLabel;

  static const String assetPath = 'assets/images/logo1.jpg';

  @override
  Widget build(BuildContext context) {
    final img = Image.asset(
      assetPath,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => _WordmarkFallback(height: height),
    );

    Widget child = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: height),
      child: img,
    );

    if (onTap != null) {
      child = Semantics(
        label: semanticLabel,
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: child,
        ),
      );
    }

    return child;
  }
}

class _WordmarkFallback extends StatelessWidget {
  const _WordmarkFallback({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: const Center(
        child: Text(
          'DASRASS',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 11,
            letterSpacing: 1.2,
            color: Color(0xFF005BFE),
          ),
        ),
      ),
    );
  }
}
