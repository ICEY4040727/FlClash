import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/features/ruleset_insight/rule_set_analyzer.dart';
import 'package:fl_clash/features/ruleset_insight/rule_source_view.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/widgets.dart';

void showRuleListSheet(
  BuildContext context, {
  required RuleSetReport report,
  required List<RuleEntry> rules,
  required String title,
}) {
  showNestedSheet<void>(
    context,
    builder: (_) => RuleListSheet(report: report, rules: rules, title: title),
  );
}

class RuleListSheet extends StatefulWidget {
  const RuleListSheet({
    super.key,
    required this.report,
    required this.rules,
    required this.title,
  });

  final RuleSetReport report;
  final List<RuleEntry> rules;
  final String title;

  @override
  State<RuleListSheet> createState() => _RuleListSheetState();
}

class _RuleListSheetState extends State<RuleListSheet> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final matched = searchRules(widget.rules, _query);
    return Scaffold(
      title: widget.title,
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              context.contentTopPadding,
              16,
              8,
            ),
            child: SearchField(
              controller: _controller,
              hintText: appLocalizations.ruleSetInsightSearchHint,
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                '${matched.length} / ${widget.rules.length}',
                style: AppTextStyle.caption2
                    .of(context)
                    .copyWith(color: context.colorScheme.onSurfaceVariant),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.only(
                top: 6,
                bottom: 20 + context.bottomInset,
              ),
              itemCount: matched.length,
              itemBuilder: (context, index) {
                final rule = matched[index];
                return ListItem(
                  title: Text(
                    'L${rule.line} · ${rule.type},${rule.value}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text('→ ${rule.target}'),
                  onTap: () => showRuleSourceSheet(
                    context,
                    widget.report,
                    RuleSection(
                      title: rule.section,
                      rules: [rule],
                      startLine: rule.line,
                      endLine: rule.line,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
