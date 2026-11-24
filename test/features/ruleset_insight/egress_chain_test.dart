import 'package:fl_clash/features/ruleset_insight/egress_chain.dart';
import 'package:fl_clash/features/ruleset_insight/rule_set_analyzer.dart';
import 'package:fl_clash/features/ruleset_insight/server_chain.dart';
import 'package:flutter_test/flutter_test.dart';

const _config = '''
proxies:
  - name: "Azure"
    type: anytls
    server: 4.216.184.217
    port: 443
    password: "x"
  - name: "JP"
    type: socks5
    server: 133.169.3.191
    port: 6810
    dialer-proxy: "Azure"
proxy-groups:
  - name: "Google-JP"
    type: select
    proxies: ["JP", "Azure"]
  - name: "Auto"
    type: url-test
    proxies: ["Azure"]
rules:
  - DOMAIN-SUFFIX,google.com,Google-JP
  - DOMAIN-SUFFIX,ads.example.com,REJECT
  - DOMAIN-SUFFIX,lan.example.com,DIRECT
  - MATCH,Auto
''';

ServerChain _serverChain() => ServerChain.fromJson({
  'host': '4.216.184.217',
  'endpoints': [
    {'type': 'wireguard', 'tag': 'warp', 'mtu': 1280},
  ],
  'outbounds': [
    {'type': 'direct', 'tag': 'direct'},
  ],
  'final': 'warp',
  'rules': [],
});

void main() {
  test('expands a group into selected node, dialer and server endpoint', () {
    final report = RuleSetAnalyzer.analyze(_config);
    final chains = buildEgressChains(
      report: report,
      selected: {'Google-JP': 'JP', 'Auto': 'Azure'},
      serverChain: _serverChain(),
    );
    final google = chains.firstWhere((item) => item.target == 'Google-JP');

    expect(google.hops[0], 'Google-JP [select]');
    expect(google.hops[1], contains('JP (socks5 133.169.3.191:6810)'));
    expect(google.hops[2], contains('Azure (anytls 4.216.184.217:443)'));
    expect(google.hops.last, contains('warp'));
    expect(google.note, isNull);
  });

  test('stops at builtins', () {
    final report = RuleSetAnalyzer.analyze(_config);
    final chains = buildEgressChains(
      report: report,
      selected: const {},
      serverChain: null,
    );
    final reject = chains.firstWhere((item) => item.target == 'REJECT');
    final direct = chains.firstWhere((item) => item.target == 'DIRECT');
    expect(reject.hops, ['REJECT']);
    expect(direct.hops, ['DIRECT']);
  });

  test('falls back to the first member when the selection is unknown', () {
    final report = RuleSetAnalyzer.analyze(_config);
    final chains = buildEgressChains(
      report: report,
      selected: const {},
      serverChain: null,
    );
    final google = chains.firstWhere((item) => item.target == 'Google-JP');
    expect(google.note, contains('按成员首项'));
    expect(google.hops[1], contains('JP (socks5'));
  });
}
