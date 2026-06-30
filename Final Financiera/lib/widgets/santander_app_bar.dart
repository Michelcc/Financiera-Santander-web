import 'package:flutter/material.dart';

import '../core/brand/brand_colors.dart';
import 'santander_icon.dart';

class SantanderAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SantanderAppBar({
    super.key,
    this.title,
    this.actions,
    this.leading,
  });

  final String? title;
  final List<Widget>? actions;
  final Widget? leading;

  @override
  Size get preferredSize => Size.fromHeight(title == null ? 64 : 76);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: BrandColors.red,
      foregroundColor: Colors.white,
      elevation: 0,
      leading: leading,
      flexibleSpace: Container(
        decoration: const BoxDecoration(gradient: BrandColors.headerGradient),
      ),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SantanderIcon(size: 32),
          if (title != null) ...[
            const SizedBox(height: 4),
            Text(
              title!,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ],
      ),
      centerTitle: true,
      actions: actions,
    );
  }
}
