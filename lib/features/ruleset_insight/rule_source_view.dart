import 'dart:math' as math;

import 'package:fl_clash/features/ruleset_insight/rule_set_analyzer.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

const double _lineHeight = 19;

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
      focusLine: section.rules.length == 1 ? section.rules.first.line : null,
    ),
  );
}

class RuleSourceSheet extends StatefulWidget {
  const RuleSourceSheet({
    super.key,
    required this.lines,
    required this.start,
    required this.end,
    required this.title,
    this.focusLine,
  });

  final List<String> lines;
  final int start;
  final int end;
  final String title;
  final int? focusLine;

  @override
  State<RuleSourceSheet> createState() => _RuleSourceSheetState();
}

class _RuleSourceSheetState extends State<RuleSourceSheet> {
  late final ScrollController _controller;
  late final int _first;
  late final int _last;

  @override
  void initState() {
    super.initState();
    _first = math.max(1, math.min(widget.start, widget.lines.length));
    _last = math.max(_first, math.min(widget.end, widget.lines.length));
    final focus = widget.focusLine;
    final offset = focus == null
        ? 0.0
        : math.max(0.0, (focus - _first - 3) * _lineHeight);
    _controller = ScrollController(initialScrollOffset: offset);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final count = _last - _first + 1;
    return Scaffold(
      title: widget.title,
      body: ListView.builder(
        controller: _controller,
        padding: EdgeInsets.only(
          top: context.contentTopPadding,
          bottom: 20 + context.bottomInset,
        ),
        itemExtent: _lineHeight,
        itemCount: count,
        itemBuilder: (context, offset) {
          final number = _first + offset;
          final text = widget.lines[number - 1];
          final focused = number == widget.focusLine;
          return Container(
            color: focused
                ? colorScheme.primary.withValues(alpha: 0.14)
                : null,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 46,
                  child: Text(
                    '$number',
                    textAlign: TextAlign.right,
                    style: _monoStyle(context).copyWith(
                      color: focused
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text.isEmpty ? ' ' : text,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
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
