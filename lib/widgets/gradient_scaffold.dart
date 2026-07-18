import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// Scaffold on the app's "vivid pop" background gradient. The gradient is
/// painted behind a transparent Scaffold, and any [appBar] is made
/// transparent too so the gradient runs through it — all locally, leaving
/// the global appBarTheme (which the game screen relies on) untouched.
class GradientScaffold extends StatelessWidget {
  const GradientScaffold({super.key, this.appBar, required this.body});

  final PreferredSizeWidget? appBar;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.bgGradient(AppPalette.isDark(context));
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: appBar == null
            ? null
            : PreferredSize(
                preferredSize: appBar!.preferredSize,
                child: Theme(
                  data: Theme.of(context).copyWith(
                    appBarTheme: Theme.of(context)
                        .appBarTheme
                        .copyWith(backgroundColor: Colors.transparent),
                  ),
                  child: appBar!,
                ),
              ),
        body: body,
      ),
    );
  }
}
