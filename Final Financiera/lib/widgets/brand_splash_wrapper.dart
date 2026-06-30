import 'package:flutter/material.dart';

import '../core/brand/brand_colors.dart';
import 'santander_icon.dart';

class BrandSplashWrapper extends StatefulWidget {
  const BrandSplashWrapper({super.key, required this.child});

  final Widget child;

  @override
  State<BrandSplashWrapper> createState() => _BrandSplashWrapperState();
}

class _BrandSplashWrapperState extends State<BrandSplashWrapper>
    with TickerProviderStateMixin {
  late final AnimationController _logoController;
  late final AnimationController _exitController;
  late final Animation<double> _scale;
  late final Animation<double> _logoFade;
  late final Animation<double> _splashFade;

  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _scale = Tween<double>(begin: 0.45, end: 1).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _logoFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0, 0.55, curve: Curves.easeOut),
      ),
    );
    _splashFade = Tween<double>(begin: 1, end: 0).animate(_exitController);
    _run();
  }

  Future<void> _run() async {
    await _logoController.forward();
    await Future.delayed(const Duration(milliseconds: 500));
    await _exitController.forward();
    if (mounted) setState(() => _visible = false);
  }

  @override
  void dispose() {
    _logoController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_visible)
          FadeTransition(
            opacity: _splashFade,
            child: Material(
              color: BrandColors.red,
              child: Center(
                child: FadeTransition(
                  opacity: _logoFade,
                  child: ScaleTransition(
                    scale: _scale,
                    child: const SantanderIcon(size: 128),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
