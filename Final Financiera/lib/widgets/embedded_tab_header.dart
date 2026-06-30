import 'package:flutter/material.dart';

import '../core/brand/brand_colors.dart';

class EmbeddedTabHeader extends StatelessWidget {
  const EmbeddedTabHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(gradient: BrandColors.headerGradient),
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
