import 'package:flutter/material.dart';

import '../widgets/gradient_scaffold.dart';
import '../widgets/pop_card.dart';

/// Scrollable viewer for a static legal document (privacy policy / terms of
/// service — see lib/content/policy_texts.dart). One screen serves both;
/// the body is picked by the app's current locale.
class PolicyScreen extends StatelessWidget {
  const PolicyScreen({
    super.key,
    required this.title,
    required this.bodyKo,
    required this.bodyEn,
  });

  final String title;
  final String bodyKo;
  final String bodyEn;

  @override
  Widget build(BuildContext context) {
    final isKorean = Localizations.localeOf(context).languageCode == 'ko';
    return GradientScaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          PopCard(
            padding: const EdgeInsets.all(20),
            child: SelectionArea(
              child: Text(
                isKorean ? bodyKo : bodyEn,
                style: const TextStyle(height: 1.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
