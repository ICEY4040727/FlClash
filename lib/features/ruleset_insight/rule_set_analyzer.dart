import 'package:yaml/yaml.dart';

const Set<String> builtinRuleTargets = {
  'DIRECT',
  'REJECT',
  'REJECT-DROP',
  'PASS',
  'COMPATIBLE',
  'REJECT-TINYGIF',
};

const Set<String> _domainRuleTypes = {
  'DOMAIN',
  'DOMAIN-SUFFIX',
  'DOMAIN-KEYWORD',
  'DOMAIN-REGEX',
  'GEOSITE',
};

const Set<String> _ipRuleTypes = {
  'IP-CIDR',
  'IP-CIDR6',
  'IP-SUFFIX',
  'IP-ASN',
  'GEOIP',
  'SRC-IP-CIDR',
  'SRC-IP-SUFFIX',
};

class RuleEntry {
  const RuleEntry({
    required this.index,
    required this.type,
    required this.value,
    required this.target,
    required this.params,
    required this.section,
    required this.line,
    required this.raw,
  });

  final int index;
  final String type;
  final String value;
  final String target;
  final List<String> params;
  final String section;
  final int line;
  final String raw;

  bool get isMatch => type == 'MATCH';

  String get label => isMatch ? 'MATCH -> $target' : '$type,$value -> $target';
}

class RuleSection {
  const RuleSection({
    required this.title,
    required this.rules,
    required this.startLine,
    required this.endLine,
  });

  final String title;
  final List<RuleEntry> rules;
  final int startLine;
  final int endLine;

  String get lineRange => 'L$startLine–L$endLine';

  Map<String, int> get targetCounts {
    final counts = <String, int>{};
    for (final rule in rules) {
      counts[rule.target] = (counts[rule.target] ?? 0) + 1;
    }
    return counts;
  }

  String get topTargets {
    final entries = targetCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(3).map((e) => '${e.key} ×${e.value}').join('、');
  }
}

class ProxyInfo {
  const ProxyInfo({
    required this.name,
    required this.type,
    required this.server,
    required this.port,
    this.dialerProxy,
  });

  final String name;
  final String type;
  final String server;
  final int? port;
  final String? dialerProxy;

  String get endpoint => server.isEmpty ? type : '$server${port == null ? '' : ':$port'}';
}

class GroupInfo {
  const GroupInfo({required this.name, required this.type, required this.members});

  final String name;
  final String type;
  final List<String> members;
}

class RuleSetReport {
  const RuleSetReport({
    required this.rules,
    required this.sections,
    required this.proxyCount,
    required this.groupCount,
    required this.providerCount,
    required this.proxyProviderCount,
    required this.nodeTypes,
    required this.proxyServers,
    required this.sourceLines,
    required this.proxyInfos,
    required this.groupInfos,
    required this.typeCounts,
    required this.targetCounts,
    required this.errors,
    required this.warnings,
    required this.parsed,
    this.parseError,
  });

  final List<RuleEntry> rules;
  final List<RuleSection> sections;
  final int proxyCount;
  final int groupCount;
  final int providerCount;
  final int proxyProviderCount;
  final Map<String, int> nodeTypes;
  final List<String> proxyServers;
  final List<String> sourceLines;
  final List<ProxyInfo> proxyInfos;
  final List<GroupInfo> groupInfos;
  final Map<String, int> typeCounts;
  final Map<String, int> targetCounts;
  final List<String> errors;
  final List<String> warnings;
  final bool parsed;
  final String? parseError;

  int get ruleCount => rules.length;
  int get issueCount => errors.length + warnings.length;

  String get summary =>
      '规则 $ruleCount 条 · 段落 ${sections.length} 个 · 出口 ${targetCounts.length} 个';
}

class RuleSetAnalyzer {
  static const int maxBytes = 8 << 20;

  static RuleSetReport analyze(String text) {
    var proxyCount = 0;
    var groupCount = 0;
    var providerCount = 0;
    var proxyProviderCount = 0;
    final nodeTypes = <String, int>{};
    final proxyServers = <String>[];
    final proxyInfos = <ProxyInfo>[];
    final groupInfos = <GroupInfo>[];
    String? parseError;
    var parsed = false;
    final groupNames = <String>{};
    final proxyNames = <String>{};
    final groupMembers = <String, List<String>>{};
    final providerNames = <String>{};

    try {
      final document = loadYaml(text);
      if (document is YamlMap) {
        parsed = true;
        final proxies = _asList(document['proxies']);
        final groups = _asList(document['proxy-groups']);
        final providers = document['rule-providers'];
        proxyCount = proxies.length;
        groupCount = groups.length;
        providerCount = providers is Map ? providers.length : 0;
      final proxyProviders = document['proxy-providers'];
      proxyProviderCount = proxyProviders is Map ? proxyProviders.length : 0;
        for (final proxy in proxies) {
          if (proxy is Map && proxy['name'] != null) {
            proxyNames.add(proxy['name'].toString());
            final type = (proxy['type'] ?? 'unknown').toString();
            nodeTypes[type] = (nodeTypes[type] ?? 0) + 1;
            final server = proxy['server']?.toString();
            if (server != null && server.isNotEmpty) proxyServers.add(server);
            proxyInfos.add(
              ProxyInfo(
                name: proxy['name'].toString(),
                type: type,
                server: server ?? '',
                port: int.tryParse('${proxy['port'] ?? ''}'),
                dialerProxy: proxy['dialer-proxy']?.toString(),
              ),
            );
          }
        }
        for (final group in groups) {
          if (group is! Map || group['name'] == null) continue;
          final name = group['name'].toString();
          groupNames.add(name);
          final members = <String>[];
          for (final member in _asList(group['proxies'])) {
            members.add(member.toString());
          }
          for (final used in _asList(group['use'])) {
            members.add('provider:$used');
          }
          groupMembers[name] = members;
          groupInfos.add(
            GroupInfo(
              name: name,
              type: (group['type'] ?? 'select').toString(),
              members: members,
            ),
          );
        }
        if (providers is Map) {
          for (final key in providers.keys) {
            providerNames.add(key.toString());
          }
        }
      }
    } catch (error) {
      parseError = error.toString();
    }

    final sections = _parseSections(text);
    final rules = <RuleEntry>[for (final section in sections) ...section.rules];

    final typeCounts = <String, int>{};
    final targetCounts = <String, int>{};
    for (final rule in rules) {
      typeCounts[rule.type] = (typeCounts[rule.type] ?? 0) + 1;
      if (rule.target.isNotEmpty) {
        targetCounts[rule.target] = (targetCounts[rule.target] ?? 0) + 1;
      }
    }

    final errors = <String>[];
    final warnings = <String>[];
    _checkGroups(groupNames, proxyNames, groupMembers, errors);
    _checkTargets(rules, proxyNames, groupNames, errors);
    _checkDuplicates(rules, warnings);
    _checkMatch(rules, warnings);
    _checkOrdering(rules, warnings);
    _checkReferenced(
      proxyNames,
      groupNames,
      providerNames,
      groupMembers,
      rules,
      warnings,
    );

    return RuleSetReport(
      rules: rules,
      sections: sections,
      proxyCount: proxyCount,
      groupCount: groupCount,
      providerCount: providerCount,
      proxyProviderCount: proxyProviderCount,
      nodeTypes: nodeTypes,
      proxyServers: proxyServers,
      proxyInfos: proxyInfos,
      groupInfos: groupInfos,
      sourceLines: text.split('\n'),
      typeCounts: typeCounts,
      targetCounts: targetCounts,
      errors: errors,
      warnings: warnings,
      parsed: parsed,
      parseError: parseError,
    );
  }

  static List<RuleSection> _parseSections(String text) {
    final lines = text.split('\n');
    var start = -1;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trimRight() == 'rules:' || line == 'rules:') {
        start = i + 1;
        break;
      }
    }
    if (start == -1) return const [];

    final sections = <RuleSection>[];
    var title = '未分组';
    var current = <RuleEntry>[];
    var block = <String>[];
    var index = 0;

    void flush() {
      if (current.isEmpty) return;
      sections.add(
        RuleSection(
          title: title,
          rules: current,
          startLine: current.first.line,
          endLine: current.last.line,
        ),
      );
      current = <RuleEntry>[];
    }

    for (var i = start; i < lines.length; i++) {
      final raw = lines[i];
      if (raw.trim().isEmpty) continue;
      if (!raw.startsWith(' ') && !raw.startsWith('\t')) {
        final head = raw.trimLeft();
        if (!head.startsWith('#') && !head.startsWith('- ')) break;
      }
      final trimmed = raw.trim();
      if (trimmed.startsWith('#')) {
        final comment = trimmed.replaceFirst(RegExp(r'^#+'), '').trim();
        if (comment.isNotEmpty && !RegExp(r'^[-=*#\s]+$').hasMatch(comment)) {
          block.add(comment);
        }
        continue;
      }
      final match = RegExp(r'^-\s*(.+)$').firstMatch(trimmed);
      if (match == null) continue;
      if (block.isNotEmpty) {
        final numbered = block
            .where((item) => RegExp(r'^\d+(\.\d+)?\)').hasMatch(item))
            .toList();
        final next = numbered.isNotEmpty ? numbered.first : block.first;
        block = <String>[];
        if (current.isNotEmpty) flush();
        title = next;
      }
      final body = _stripInlineComment(match.group(1)!);
      final rule = _parseRule(body, ++index, title, i + 1);
      if (rule != null) {
        current.add(rule);
      } else {
        index--;
      }
    }
    flush();
    return sections;
  }

  static RuleEntry? _parseRule(String body, int index, String section, int line) {
    final fields = _splitFields(body);
    if (fields.isEmpty) return null;
    final type = fields.first.toUpperCase();
    if (type == 'MATCH' || type == 'FINAL') {
      return RuleEntry(
        index: index,
        type: 'MATCH',
        value: '',
        target: fields.length > 1 ? fields[1] : '',
        params: const [],
        section: section,
        line: line,
        raw: body,
      );
    }
    if (fields.length > 2) {
      return RuleEntry(
        index: index,
        type: type,
        value: fields[1],
        target: fields[2],
        params: fields.sublist(3),
        section: section,
        line: line,
        raw: body,
      );
    }
    return RuleEntry(
      index: index,
      type: type,
      value: fields.length > 1 ? fields[1] : '',
      target: fields.length > 1 ? fields[1] : '',
      params: const [],
      section: section,
      line: line,
      raw: body,
    );
  }

  static List<String> _splitFields(String body) {
    final fields = <String>[];
    final buffer = StringBuffer();
    var depth = 0;
    String? quote;
    for (final rune in body.runes) {
      final char = String.fromCharCode(rune);
      if (quote != null) {
        buffer.write(char);
        if (char == quote) quote = null;
        continue;
      }
      if (char == '"' || char == "'") {
        quote = char;
        buffer.write(char);
      } else if (char == '(') {
        depth++;
        buffer.write(char);
      } else if (char == ')') {
        if (depth > 0) depth--;
        buffer.write(char);
      } else if (char == ',' && depth == 0) {
        fields.add(buffer.toString().trim());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    fields.add(buffer.toString().trim());
    return fields.where((field) => field.isNotEmpty).toList();
  }

  static String _stripInlineComment(String value) {
    final index = value.indexOf(' #');
    return index > 0 ? value.substring(0, index).trim() : value.trim();
  }

  static void _checkGroups(
    Set<String> groupNames,
    Set<String> proxyNames,
    Map<String, List<String>> members,
    List<String> errors,
  ) {
    members.forEach((group, list) {
      for (final member in list) {
        if (member.startsWith('provider:')) continue;
        if (!proxyNames.contains(member) &&
            !groupNames.contains(member) &&
            !builtinRuleTargets.contains(member.toUpperCase())) {
          errors.add('策略组 `$group` 引用了不存在的成员 `$member`');
        }
      }
    });

    final visiting = <String>{};
    final done = <String>{};

    void visit(String node, List<String> stack) {
      if (done.contains(node)) return;
      if (!visiting.add(node)) {
        errors.add('策略组存在循环引用: ${[...stack, node].join(' -> ')}');
        return;
      }
      for (final next in members[node] ?? const <String>[]) {
        if (members.containsKey(next)) visit(next, [...stack, next]);
      }
      visiting.remove(node);
      done.add(node);
    }

    for (final group in members.keys) {
      visit(group, [group]);
    }
  }

  static void _checkTargets(
    List<RuleEntry> rules,
    Set<String> proxyNames,
    Set<String> groupNames,
    List<String> errors,
  ) {
    final known = {...proxyNames, ...groupNames, ...builtinRuleTargets};
    for (final rule in rules) {
      if (rule.target.isEmpty || rule.target == rule.value) continue;
      if (!known.contains(rule.target) &&
          !known.contains(rule.target.toUpperCase())) {
        errors.add(
          '第 ${rule.index} 条目标 `${rule.target}` 未定义（${rule.type},${rule.value}）',
        );
      }
    }
  }

  static void _checkDuplicates(List<RuleEntry> rules, List<String> warnings) {
    final seen = <String, int>{};
    for (final rule in rules) {
      if (rule.isMatch) continue;
      final key = '${rule.type}|${rule.value}';
      if (seen.containsKey(key)) {
        warnings.add(
          '第 ${rule.index} 条与第 ${seen[key]} 条重复（${rule.type},${rule.value}），后一条永不生效',
        );
      } else {
        seen[key] = rule.index;
      }
    }
  }

  static void _checkMatch(List<RuleEntry> rules, List<String> warnings) {
    if (rules.isEmpty) return;
    if (!rules.last.isMatch) {
      warnings.add('最后一条不是 MATCH，未命中的流量行为由内核默认决定');
    }
    for (final rule in rules) {
      if (rule.isMatch && rule.index != rules.length) {
        warnings.add('第 ${rule.index} 条是 MATCH 但后面还有规则，其后的规则永不生效');
      }
    }
  }

  static void _checkOrdering(List<RuleEntry> rules, List<String> warnings) {
    final publicIp = rules.where(
      (rule) => _ipRuleTypes.contains(rule.type) && !_isLocalIpRule(rule),
    );
    if (publicIp.isNotEmpty) {
      final firstIp = publicIp
          .map((rule) => rule.index)
          .reduce((a, b) => a < b ? a : b);
      final late = rules.where(
        (rule) => _domainRuleTypes.contains(rule.type) && rule.index > firstIp,
      );
      if (late.isNotEmpty) {
        warnings.add(
          '共有 ${late.length} 条域名规则排在第 $firstIp 条公网 IP 规则之后，fake-ip 下可能先被 IP 规则截取',
        );
      }
    }

    final suffixIndex = <String, int>{};
    final keywordIndex = <String, int>{};
    for (final rule in rules) {
      if (rule.type == 'DOMAIN-SUFFIX') {
        suffixIndex.putIfAbsent(rule.value.toLowerCase(), () => rule.index);
      } else if (rule.type == 'DOMAIN-KEYWORD') {
        keywordIndex.putIfAbsent(rule.value.toLowerCase(), () => rule.index);
      }
    }
    if (suffixIndex.isEmpty && keywordIndex.isEmpty) return;

    for (final rule in rules) {
      if (rule.type != 'DOMAIN') continue;
      final value = rule.value.toLowerCase();
      final parts = value.split('.');
      for (var i = 1; i < parts.length; i++) {
        final hit = suffixIndex[parts.sublist(i).join('.')];
        if (hit != null && hit < rule.index) {
          warnings.add(
            '第 ${rule.index} 条 DOMAIN,${rule.value} 被第 $hit 条 DOMAIN-SUFFIX 覆盖，永不生效',
          );
          break;
        }
      }
      for (final entry in keywordIndex.entries) {
        if (entry.value < rule.index && value.contains(entry.key)) {
          warnings.add(
            '第 ${rule.index} 条 DOMAIN,${rule.value} 被第 ${entry.value} 条 DOMAIN-KEYWORD 覆盖，永不生效',
          );
          break;
        }
      }
    }
  }

  static void _checkReferenced(
    Set<String> proxyNames,
    Set<String> groupNames,
    Set<String> providerNames,
    Map<String, List<String>> members,
    List<RuleEntry> rules,
    List<String> warnings,
  ) {
    final referenced = <String>{...rules.map((rule) => rule.target)};
    for (final list in members.values) {
      referenced.addAll(list);
    }
    for (final proxy in proxyNames) {
      if (!referenced.contains(proxy)) {
        warnings.add('节点 `$proxy` 没有被任何策略组或规则引用');
      }
    }
    for (final group in groupNames) {
      if (!referenced.contains(group)) {
        warnings.add('策略组 `$group` 没有被任何规则引用');
      }
    }
    final usedProviders = rules
        .where((rule) => rule.type == 'RULE-SET')
        .map((rule) => rule.value)
        .toSet();
    for (final provider in providerNames) {
      final used =
          usedProviders.contains(provider) ||
          members.values.any((list) => list.contains('provider:$provider'));
      if (!used) {
        warnings.add('规则集 `$provider` 已定义但未被任何 RULE-SET 引用');
      }
    }
  }

  static bool _isLocalIpRule(RuleEntry rule) {
    if (rule.type.startsWith('SRC-') || rule.type == 'GEOIP') return true;
    final value = rule.value.split('/').first;
    final parts = value.split('.');
    if (parts.length != 4) {
      return value.contains(':') && rule.type == 'IP-CIDR6';
    }
    final numbers = parts.map(int.tryParse).toList();
    if (numbers.contains(null)) return false;
    final first = numbers[0]!;
    final second = numbers[1]!;
    if (first == 0 || first == 10 || first == 127) return true;
    if (first == 100 && second >= 64 && second <= 127) return true;
    if (first == 169 && second == 254) return true;
    if (first == 172 && second >= 16 && second <= 31) return true;
    if (first == 192 && second == 168) return true;
    if (first == 198 && (second == 18 || second == 19)) return true;
    if (first >= 224) return true;
    return false;
  }

  static List<dynamic> _asList(Object? value) {
    if (value is YamlList) return value.toList();
    if (value is List) return value;
    return const [];
  }
}

String mermaidId(String value) {
  final cleaned = value.replaceAll(RegExp(r'[^0-9A-Za-z_]'), '_');
  if (cleaned.isEmpty) return 'n_empty';
  return RegExp(r'^\d').hasMatch(cleaned) ? 'n_$cleaned' : cleaned;
}

String mermaidLabel(String value) {
  var cleaned = value
      .replaceAll('"', "'")
      .replaceAll('|', '/')
      .replaceAll('`', "'")
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (cleaned.length > 46) {
    cleaned = '${cleaned.substring(0, 44)}…';
  }
  return cleaned;
}

class RuleSetDiagrams {
  static String structure(RuleSetReport report) {
    final buffer = StringBuffer()
      ..writeln('classDiagram')
      ..writeln('  direction LR')
      ..writeln('  class Config["Clash 配置"]');
    if (report.proxyCount > 0) {
      buffer
        ..writeln('  class Proxies["代理节点 ${report.proxyCount} 个"]')
        ..writeln('  Config *-- Proxies');
    }
    if (report.groupCount > 0) {
      buffer
        ..writeln('  class Groups["策略组 ${report.groupCount} 个"]')
        ..writeln('  Config *-- Groups');
    }
    if (report.providerCount > 0) {
      buffer
        ..writeln('  class Providers["规则集 ${report.providerCount} 个"]')
        ..writeln('  Config *-- Providers');
    }
    if (report.proxyProviderCount > 0) {
      buffer
        ..writeln(
          '  class ProxyProviders["代理提供者 ${report.proxyProviderCount} 个"]',
        )
        ..writeln('  Config *-- ProxyProviders');
    }
    if (report.nodeTypes.isNotEmpty) {
      final entries = report.nodeTypes.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final entry in entries) {
        buffer.writeln(
          '  class T_${mermaidId(entry.key)}["${mermaidLabel(entry.key)} ${entry.value} 个"]',
        );
        buffer.writeln('  Proxies *-- T_${mermaidId(entry.key)}');
      }
    }
    buffer
      ..writeln('  class Rules["规则 ${report.ruleCount} 条 · 首条命中即止"]')
      ..writeln('  Config *-- Rules');
    return buffer.toString();
  }

  static String sectionFlow(RuleSetReport report) {
    final buffer = StringBuffer()..writeln('flowchart LR');
    final targets = <String>{};
    for (var i = 0; i < report.sections.length; i++) {
      final section = report.sections[i];
      buffer.writeln(
        '  S$i["${mermaidLabel(section.title)}<br/>${section.rules.length} 条"]',
      );
    }
    for (var i = 0; i < report.sections.length; i++) {
      final counts = report.sections[i].targetCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final entry in counts) {
        final id = mermaidId('T_${entry.key}');
        if (targets.add(entry.key)) {
          buffer.writeln('  $id(["${mermaidLabel(entry.key)}"])');
        }
        buffer.writeln('  S$i -->|${entry.value}| $id');
      }
    }
    return buffer.toString();
  }

  static List<String> detailFlows(
    RuleSetReport report, {
    int chunk = 22,
    int maxDiagrams = 12,
  }) {
    final diagrams = <String>[];
    for (final section in report.sections) {
      for (var start = 0; start < section.rules.length; start += chunk) {
        if (diagrams.length >= maxDiagrams) return diagrams;
        final slice = section.rules.skip(start).take(chunk).toList();
        final buffer = StringBuffer()..writeln('flowchart TD');
        String? previous;
        for (final rule in slice) {
          final id = 'r${rule.index}';
          if (rule.isMatch) {
            buffer.writeln('  $id{{"END · MATCH"}}');
          } else {
            final label = mermaidLabel(rule.value.isEmpty ? '-' : rule.value);
            buffer.writeln('  $id{"${rule.index}. ${rule.type}<br/>$label"}');
          }
          if (previous != null) {
            buffer.writeln('  $previous -->|未命中| $id');
          }
          previous = id;
          if (!rule.isMatch) {
            buffer.writeln(
              '  $id --> t${mermaidId(rule.target)}(["${mermaidLabel(rule.target)}"])',
            );
          }
        }
        diagrams.add(buffer.toString());
      }
    }
    return diagrams;
  }

  static String markdown(RuleSetReport report) {
    final buffer = StringBuffer()
      ..writeln('# 规则集说明')
      ..writeln()
      ..writeln('- ${report.summary}')
      ..writeln('- 错误 ${report.errors.length} 项，警告 ${report.warnings.length} 项')
      ..writeln()
      ..writeln('## 1. 结构')
      ..writeln('```mermaid')
      ..writeln(structure(report))
      ..writeln('```')
      ..writeln()
      ..writeln('## 2. 分段流转')
      ..writeln('```mermaid')
      ..writeln(sectionFlow(report))
      ..writeln('```');
    for (final diagram in detailFlows(report)) {
      buffer
        ..writeln()
        ..writeln('## 明细')
        ..writeln('```mermaid')
        ..writeln(diagram)
        ..writeln('```');
    }
    if (report.errors.isNotEmpty || report.warnings.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('## 检查结果');
      for (final error in report.errors) {
        buffer.writeln('- ❌ $error');
      }
      for (final warning in report.warnings) {
        buffer.writeln('- ⚠️ $warning');
      }
    }
    return buffer.toString();
  }
}
