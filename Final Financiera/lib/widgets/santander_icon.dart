import 'package:flutter/material.dart';

import '../core/brand/brand_colors.dart';

/// Ícono PE (llama blanca sobre rojo) — launcher y splash.
class SantanderIcon extends StatefulWidget {
  const SantanderIcon({
    super.key,
    this.size = 72,
    this.pulse = false,
  });

  final double size;
  final bool pulse;

  @override
  State<SantanderIcon> createState() => _SantanderIconState();
}

class _SantanderIconState extends State<SantanderIcon>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.pulse) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200),
      )..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(widget.size * 0.18),
      child: Image.asset(
        'assets/branding/santander_icon.png',
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: widget.size,
          height: widget.size,
          color: BrandColors.red,
          child: Icon(
            Icons.local_fire_department,
            color: Colors.white,
            size: widget.size * 0.55,
          ),
        ),
      ),
    );

    if (_controller == null) return image;

    return ScaleTransition(
      scale: Tween<double>(begin: 0.92, end: 1.0).animate(
        CurvedAnimation(parent: _controller!, curve: Curves.easeInOut),
      ),
      child: image,
    );
  }
}
