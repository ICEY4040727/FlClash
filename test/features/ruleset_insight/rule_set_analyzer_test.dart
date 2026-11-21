import 'package:fl_clash/features/ruleset_insight/rule_set_analyzer.dart';
import 'package:flutter_test/flutter_test.dart';

const _basic = '''
mode: rule
proxies:
  - name: "JP"
    type: socks5
    server: 1.2.3.4
    port: 1080
  - name: "HK"
    type: http
    server: 5.6.7.8
    port: 8080
proxy-groups:
  - name: "Proxy"
    type: select
    proxies: ["JP", "HK", "DIRECT"]
  - name: "AI"
    type: select
    proxies: ["Proxy", "JP"]
rule-providers:
  used:
    type: http
    behavior: classical
  unused:
    type: http
    behavior: domain
rules:
  # 1) 广告拦截
  - DOMAIN-SUFFIX,ads.example.com,REJECT
  # 2) 代理
  - DOMAIN-SUFFIX,google.com,AI
  - DOMAIN-SUFFIX,google.com,AI
  - DOMAIN,www.google.com,Proxy
  - IP-CIDR,10.0.0.0/8,DIRECT,no-resolve
  - IP-CIDR,9.9.9.0/24,Proxy
  - DOMAIN-SUFFIX,late.example.com,DIRECT
  - MATCH,Proxy
''';

const _broken = '''
proxies:
  - name: "JP"
    type: socks5
    server: 1.2.3.4
    port: 1080
proxy-groups:
  - name: "A"
    type: select
    proxies: ["B"]
  - name: "B"
    type: select
    proxies: ["A"]
  - name: "Lonely"
    type: select
    proxies: ["JP"]
rules:
  - DOMAIN-SUFFIX,x.com,A
  - DOMAIN-SUFFIX,y.com,Missing
  - MATCH,Lonely
''';

void main() {
  group('RuleSetAnalyzer', () {
    test('parses sections, counts and targets', () {
      final report = RuleSetAnalyzer.analyze(_basic);
      expect(report.parsed, isTrue);
      expect(report.ruleCount, 8);
      expect(report.sections.length, 2);
      expect(report.sections.first.title, '1) 广告拦截');
      expect(report.sections.last.title, '2) 代理');
      expect(report.proxyCount, 2);
      expect(report.groupCount, 2);
      expect(report.providerCount, 2);
      expect(report.targetCounts['Proxy'], 3);
      expect(report.targetCounts['AI'], 2);
    });

    test('flags duplicates, shadowed domain rules and source order', () {
      final report = RuleSetAnalyzer.analyze(_basic);
      expect(report.warnings.any((w) => w.contains('重复')), isTrue);
      expect(
        report.warnings.any((w) => w.contains('DOMAIN,www.google.com')),
        isTrue,
      );
      expect(report.warnings.any((w) => w.contains('域名规则排在')), isTrue);
      expect(report.warnings.any((w) => w.contains('10.0.0.0/8')), isFalse);
    });

    test('reports missing targets and group cycles', () {
      final report = RuleSetAnalyzer.analyze(_broken);
      expect(report.errors.any((e) => e.contains('Missing')), isTrue);
      expect(report.errors.any((e) => e.contains('循环')), isTrue);
    });

    test('emits mermaid diagrams', () {
      final report = RuleSetAnalyzer.analyze(_basic);
      expect(RuleSetDiagrams.structure(report), startsWith('classDiagram'));
      expect(RuleSetDiagrams.sectionFlow(report), startsWith('flowchart LR'));
      expect(RuleSetDiagrams.detailFlows(report), isNotEmpty);
      expect(
        RuleSetDiagrams.detailFlows(
          report,
        ).every((diagram) => diagram.startsWith('flowchart TD')),
        isTrue,
      );
      expect(RuleSetDiagrams.markdown(report), contains('```mermaid'));
    });

    test('sanitises labels and ids', () {
      expect(mermaidId('Google-JP'), 'Google_JP');
      expect(mermaidId('2 clean'), 'n_2_clean');
      expect(mermaidLabel('a "b" |c|'), "a 'b' /c/");
    });
  });
}
