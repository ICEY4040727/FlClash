import 'package:fl_clash/features/ruleset_insight/rule_set_analyzer.dart';
import 'package:fl_clash/features/ruleset_insight/server_chain.dart';

class EgressChain {
  const EgressChain({
    required this.target,
    required this.count,
    required this.hops,
    this.note,
  });

  final String target;
  final int count;
  final List<String> hops;
  final String? note;
}

List<EgressChain> buildEgressChains({
  required RuleSetReport report,
  required Map<String, String> selected,
  ServerChain? serverChain,
}) {
  final proxies = {for (final item in report.proxyInfos) item.name: item};
  final groups = {for (final item in report.groupInfos) item.name: item};
  final entries = report.targetCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return [
    for (final entry in entries)
      _resolve(
        target: entry.key,
        count: entry.value,
        proxies: proxies,
        groups: groups,
        selected: selected,
        serverChain: serverChain,
      ),
  ];
}

EgressChain _resolve({
  required String target,
  required int count,
  required Map<String, ProxyInfo> proxies,
  required Map<String, GroupInfo> groups,
  required Map<String, String> selected,
  ServerChain? serverChain,
}) {
  final hops = <String>[];
  final visited = <String>{};
  String? note;
  var current = target;

  while (true) {
    if (!visited.add(current)) {
      note = '循环引用已截断';
      break;
    }
    if (builtinRuleTargets.contains(current.toUpperCase())) {
      hops.add(current.toUpperCase());
      break;
    }
    final group = groups[current];
    if (group != null) {
      hops.add('$current [${group.type}]');
      final next = selected[current] ?? group.members.firstOrNull;
      if (next == null) {
        note = '组内没有成员';
        break;
      }
      if (selected[current] == null) {
        note = '选中项未知，按成员首项';
      }
      current = next;
      continue;
    }
    final proxy = proxies[current];
    if (proxy != null) {
      hops.add('$current (${proxy.type} ${proxy.endpoint})');
      final dialer = proxy.dialerProxy;
      if (dialer == null || dialer.isEmpty) {
        if (serverChain?.host != null && serverChain!.host == proxy.server) {
          final endpoint = serverChain.endpoints.firstOrNull;
          hops.add(endpoint ?? '服务端出站');
        }
        break;
      }
      current = dialer;
      continue;
    }
    hops.add(current);
    note ??= '未知目标';
    break;
  }

  return EgressChain(
    target: target,
    count: count,
    hops: hops,
    note: note,
  );
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
