import 'dart:async';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/features/ruleset_insight/rule_set_analyzer.dart';
import 'package:fl_clash/features/ruleset_insight/rule_set_diagram.dart';
import 'package:fl_clash/features/ruleset_insight/server_chain.dart';
import 'package:fl_clash/features/ruleset_insight/server_chain_fetcher.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/views/dashboard/style.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'card.dart';

RuleSetReport? analyzeRuleSetFile(String path) {
  final file = File(path);
  if (!file.existsSync()) return null;
  if (file.lengthSync() > RuleSetAnalyzer.maxBytes) return null;
  return RuleSetAnalyzer.analyze(file.readAsStringSync());
}

void showRuleSetInsightSheet(
  BuildContext context,
  RuleSetReport report,
  ServerChain? chain,
) {
  showNestedSheet<void>(
    context,
    builder: (_) => RuleSetInsightSheet(report: report, chain: chain),
  );
}

class RuleSetInsightCard extends ConsumerStatefulWidget {
  const RuleSetInsightCard({super.key});

  @override
  ConsumerState<RuleSetInsightCard> createState() =>
      _RuleSetInsightCardState();
}

class _RuleSetInsightCardState extends ConsumerState<RuleSetInsightCard> {
  RuleSetReport? _report;
  ServerChain? _chain;
  bool _loading = true;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<RuleSetReport?> _load() async {
    final generation = ++_generation;
    try {
      final path = await appPath.configFilePath;
      final report = await compute(analyzeRuleSetFile, path);
      final chain = await ServerChain.load();
      if (!mounted || generation != _generation) return null;
      setState(() {
        _report = report;
        _chain = chain;
        _loading = false;
      });
      return report;
    } catch (_) {
      if (!mounted || generation != _generation) return null;
      setState(() {
        _loading = false;
      });
      return null;
    }
  }

  Future<void> _openSheet() async {
    final fresh = await _load();
    if (!mounted) return;
    final report = fresh ?? _report;
    if (report == null) return;
    showRuleSetInsightSheet(context, report, _chain);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(groupsProvider, (_, _) {
      unawaited(_load());
    });
    final appLocalizations = context.appLocalizations;
    final report = _report;
    return DashboardCard(
      semanticLabel: appLocalizations.ruleSetInsight,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: _openSheet,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  appLocalizations.ruleSetInsight,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DashboardText.label(context),
                ),
              ),
              if (report != null)
                Text(
                  report.issueCount == 0
                      ? appLocalizations.ruleSetInsightNoIssues
                      : '${report.issueCount} ${appLocalizations.ruleSetInsightIssues}',
                  maxLines: 1,
                  style: DashboardText.label(context),
                ),
              const SizedBox(width: 4),
              Text('›', style: DashboardText.label(context)),
            ],
          ),
          if (report == null)
            Text(
              _loading
                  ? appLocalizations.ruleSetInsightLoading
                  : appLocalizations.ruleSetInsightUnavailable,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: DashboardText.label(context),
            )
          else ...[
            Row(
              spacing: 16,
              children: [
                _Figure(
                  value: '${report.ruleCount}',
                  label: appLocalizations.ruleSetInsightRules,
                ),
                _Figure(
                  value: '${report.sections.length}',
                  label: appLocalizations.ruleSetInsightSections,
                ),
                _Figure(
                  value: '${report.targetCounts.length}',
                  label: appLocalizations.ruleSetInsightTargets,
                ),
              ],
            ),
            Text(
              _topTargets(report),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DashboardText.label(context),
            ),
          ],
        ],
      ),
    );
  }

  String _topTargets(RuleSetReport report) {
    final entries = report.targetCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(3).map((e) => '${e.key} ×${e.value}').join('  ·  ');
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 1,
      children: [
        Text(value, style: DashboardText.figure(context, AppTextStyle.title2)),
        Text(label, style: DashboardText.label(context)),
      ],
    );
  }
}

class RuleSetInsightSheet extends StatefulWidget {
  const RuleSetInsightSheet({
    super.key,
    required this.report,
    this.chain,
  });

  final RuleSetReport report;
  final ServerChain? chain;

  @override
  State<RuleSetInsightSheet> createState() => _RuleSetInsightSheetState();
}

class _RuleSetInsightSheetState extends State<RuleSetInsightSheet> {
  ServerChain? _chain;
  bool _refreshing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _chain = widget.chain;
  }

  Future<void> _refreshServerChain() async {
    if (_refreshing) return;
    setState(() {
      _refreshing = true;
      _error = null;
    });
    final result = await ServerChainFetcher.refresh(
      widget.report.proxyServers,
    );
    if (!mounted) return;
    setState(() {
      _refreshing = false;
      if (result.ok) {
        _chain = result.chain;
      } else {
        _error = result.error;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final chain = _chain;
    final appLocalizations = context.appLocalizations;
    return Scaffold(
      title: appLocalizations.ruleSetInsight,
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(
              top: context.contentTopPadding,
              bottom: 20 + context.bottomInset,
            ),
            sliver: SliverList.list(
              children: [
                _SummaryRows(report: report),
                const SizedBox(height: 12),
                _SheetHeader(title: appLocalizations.ruleSetInsightServerChain),
                if (chain != null) ...[
                  if (!chain.matchesServers(report.proxyServers))
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                      child: Text(
                        appLocalizations.ruleSetInsightServerChainStale,
                        style: AppTextStyle.caption1
                            .of(context)
                            .copyWith(color: context.colorScheme.error),
                      ),
                    ),
                  ServerChainDiagram(chain: chain),
                  if (chain.snapshotLabel != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
                      child: Text(
                        chain.snapshotLabel!,
                        style: AppTextStyle.caption2
                            .of(context)
                            .copyWith(
                              color: context.colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                ] else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      appLocalizations.ruleSetInsightServerChainMissing,
                      style: AppTextStyle.caption1
                          .of(context)
                          .copyWith(color: context.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ListItem(
                  title: Text(
                    _refreshing
                        ? appLocalizations.ruleSetInsightServerChainRefreshing
                        : appLocalizations.ruleSetInsightServerChainRefresh,
                  ),
                  subtitle: _error == null ? null : Text(_error!),
                  onTap: _refreshing ? null : _refreshServerChain,
                ),
                const SizedBox(height: 8),
                _SheetHeader(title: appLocalizations.ruleSetInsightStructure),
                RuleStructureDiagram(report: report),
                const SizedBox(height: 8),
                _SheetHeader(title: appLocalizations.ruleSetInsightFlow),
                RuleFlowDiagram(report: report),
                const SizedBox(height: 12),
                _SheetHeader(title: appLocalizations.ruleSetInsightSections),
                for (final section in report.sections)
                  ListItem(
                    title: Text(section.title, maxLines: 2),
                    subtitle: Text(section.topTargets),
                    trailing: Text('${section.rules.length}'),
                  ),
                const SizedBox(height: 12),
                _SheetHeader(title: appLocalizations.ruleSetInsightChecks),
                if (report.errors.isEmpty && report.warnings.isEmpty)
                  ListItem(title: Text(appLocalizations.ruleSetInsightNoIssues))
                else ...[
                  for (final error in report.errors)
                    ListItem(title: Text('❌ $error')),
                  for (final warning in report.warnings)
                    ListItem(title: Text('⚠️ $warning')),
                ],
                if (report.parseError != null)
                  ListItem(title: Text(report.parseError!)),
                const SizedBox(height: 12),
                ListItem(
                  title: Text(appLocalizations.ruleSetInsightCopy),
                  subtitle: Text(appLocalizations.ruleSetInsightCopyHint),
                  onTap: () {
                    Clipboard.setData(
                      ClipboardData(text: RuleSetDiagrams.markdown(report)),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRows extends StatelessWidget {
  const _SummaryRows({required this.report});

  final RuleSetReport report;

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return ListItem(
      title: Text(
        '${appLocalizations.ruleSetInsightRules}: ${report.ruleCount}  '
        '${appLocalizations.ruleSetInsightSections}: ${report.sections.length}  '
        '${appLocalizations.ruleSetInsightIssues}: ${report.issueCount}',
      ),
      subtitle: Text(
        '${appLocalizations.ruleSetInsightNodes}: ${report.proxyCount}  '
        '${appLocalizations.ruleSetInsightGroups}: ${report.groupCount}  '
        '${appLocalizations.ruleSetInsightProviders}: ${report.providerCount}',
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Text(title, style: DashboardText.cardTitle(context)),
    );
  }
}
