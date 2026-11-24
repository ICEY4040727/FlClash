import 'package:fl_clash/features/ruleset_insight/server_chain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads a server summary without secrets', () {
    final chain = ServerChain.fromJson({
      'generatedAt': '2026-11-24T09:58:28Z',
      'host': '4.216.184.217',
      'inbounds': [
        {'type': 'anytls', 'listen': '::', 'port': 8443, 'tls': true},
        {'type': 'anytls', 'listen': '::', 'port': 443, 'tls': true},
      ],
      'endpoints': [
        {
          'type': 'wireguard',
          'tag': 'warp',
          'addresses': ['172.16.0.2/32'],
          'mtu': 1280,
        },
      ],
      'outbounds': [
        {'type': 'direct', 'tag': 'direct'},
      ],
      'final': 'warp',
      'rules': [
        {'action': 'sniff'},
        {'protocol': 'dns', 'action': 'hijack-dns'},
      ],
    });

    expect(chain.host, '4.216.184.217');
    expect(chain.inboundLabel, 'anytls 8443 / anytls 443');
    expect(chain.egressLabel, 'warp · wireguard · mtu 1280');
    expect(chain.finalTag, 'warp');
    expect(chain.ruleCount, 2);
    expect(chain.summary, contains('wireguard'));
  });

  test('detects a summary from another host', () {
    final chain = ServerChain.fromJson({
      'host': '203.0.113.10',
      'inbounds': [],
      'endpoints': [],
      'outbounds': [],
      'rules': [],
    });
    expect(chain.matchesServers(['4.216.184.217']), isFalse);
    expect(chain.matchesServers(['203.0.113.10']), isTrue);
    expect(chain.matchesServers(['203.0.113.10', '1.1.1.1']), isTrue);
  });

  test('falls back to the plain outbound when no endpoint matches', () {
    final chain = ServerChain.fromJson({
      'inbounds': [
        {'type': 'mixed', 'port': 7890},
      ],
      'outbounds': [
        {'type': 'direct', 'tag': 'direct'},
      ],
      'final': 'direct',
      'rules': [],
    });

    expect(chain.inboundLabel, 'mixed 7890');
    expect(chain.egressLabel, 'direct · direct');
    expect(chain.ruleCount, 0);
  });
}
