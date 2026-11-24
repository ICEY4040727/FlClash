import 'dart:math' as math;

import 'package:fl_clash/features/ruleset_insight/rule_set_analyzer.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

void showRuleSourceSheet(
  BuildContext context,
  RuleSetReport report,
  RuleSection section,
) {
  showNestedSheet<void>(
    context,
    builder: (_) => RuleSourceSheet(
      lines: report.sourceLines,
      start: section.startLine,
      end: section.endLine,
      title: section.title,
    ),
  );
}

class RuleSourceSheet extends StatelessWidget {
  const RuleSourceSheet({
    super.key,
    required this.lines,
    required this.start,
    required this.end,
    required this.title,
  });

  final List<String> lines;
  final int start;
  final int end;
  final String title;

  @override
  Widget build(BuildContext context) {
    final first = math.max(1, math.min(start, lines.length));
    final last = math.max(first, math.min(end, lines.length));
    final count = last - first + 1;
    return Scaffold(
      title: title,
      body: ListView.builder(
        padding: EdgeInsets.only(
          top: context.contentTopPadding,
          bottom: 20 + context.bottomInset,
        ),
        itemCount: count,
        itemBuilder: (context, offset) {
          final number = first + offset;
          final text = lines[number - 1];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 46,
                  child: Text(
                    '$number',
                    textAlign: TextAlign.right,
                    style: _monoStyle(context).copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SelectableText(
                    text.isEmpty ? ' ' : text,
                    style: _monoStyle(context),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  TextStyle _monoStyle(BuildContext context) =>
      AppTextStyle.caption1.of(context).copyWith(
        fontFamily: 'JetBrainsMono',
        fontSize: 12.5,
        height: 1.45,
      );
}
