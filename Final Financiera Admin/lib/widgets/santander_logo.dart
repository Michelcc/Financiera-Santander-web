import 'package:flutter/material.dart';

import '../core/brand/brand_colors.dart';

/// Logo horizontal Santander — uso dentro de la app (fondos claros).
class SantanderLogo extends StatefulWidget {
  const SantanderLogo({
    super.key,
    this.height = 40,
    this.animate = false,
  });

  final double height;
  final bool animate;

  @override
  State<SantanderLogo> createState() => _SantanderLogoState();
}

class _SantanderLogoState extends State<SantanderLogo>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _fade;
  Animation<Offset>? _slide;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 800),
      );
      _fade = CurvedAnimation(parent: _controller!, curve: Curves.easeOut);
      _slide = Tween<Offset>(
        begin: const Offset(0, 0.2),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: _controller!, curve: Curves.easeOutCubic));
      _controller!.forward();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logo = Image.asset(
      'assets/branding/santander_logo.png',
      height: widget.height,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Text(
        'Santander',
        style: TextStyle(
          color: BrandColors.red,
          fontSize: widget.height * 0.55,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    if (_controller == null) return logo;

    return FadeTransition(
      opacity: _fade!,
      child: SlideTransition(position: _slide!, child: logo),
    );
  }
}
