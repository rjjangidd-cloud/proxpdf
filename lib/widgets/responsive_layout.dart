import 'package:flutter/material.dart';
import 'package:proxpdf/utils/responsive_utils.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget tablet;
  final Widget desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    required this.tablet,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (ResponsiveUtils.isDesktop(context)) {
          return desktop;
        } else if (ResponsiveUtils.isTablet(context)) {
          return tablet;
        } else {
          return mobile;
        }
      },
    );
  }
}     