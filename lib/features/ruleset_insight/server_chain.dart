import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter/widgets.dart';

const String serverChainFileName = 'server-chain.json';

class ServerChain {
  const ServerChain({
    required this.host,
    required this.generatedAt,
    required this.inbounds,
    required this.endpoints,
    required this.outbounds,
    required this.finalTag,
    required this.ruleCount,
  });

  final String? host;
  final DateTime? generatedAt;
  final List<String> inbounds;
  final List<String> endpoints;
  final List<String> outbounds;
  final String? finalTag;
  final int ruleCount;

  String get inboundLabel =>
      inbounds.isEmpty ? '-' : inbounds.take(2).join(' / ');

  String get egressLabel {
    final target = finalTag;
    if (target == null) return '-';
    final endpoint = endpoints.firstWhere(
      (item) => item.startsWith(target),
      orElse: () => '',
    );
    if (endpoint.isNotEmpty) return endpoint;
    final outbound = outbounds.firstWhere(
      (item) => item.startsWith(target),
      orElse: () => target,
    );
    return outbound;
  }

  String get summary => '$inboundLabel → $egressLabel';

  static Future<ServerChain?> load() async {
    try {
      final home = await appPath.homeDirPath;
      final file = File('$home${Platform.pathSeparator}$serverChainFileName');
      if (!file.existsSync()) return null;
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map) return null;
      return ServerChain.fromJson(decoded.cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  static ServerChain fromJson(Map<String, dynamic> json) {
    final inbounds = <String>[];
    for (final item in _asList(json['inbounds'])) {
      if (item is! Map) continue;
      final type = item['type']?.toString() ?? 'inbound';
      final port = item['port']?.toString();
      inbounds.add(port == null ? type : '$type $port');
    }
    final endpoints = <String>[];
    for (final item in _asList(json['endpoints'])) {
      if (item is! Map) continue;
      final tag = item['tag']?.toString() ?? 'endpoint';
      final type = item['type']?.toString() ?? '';
      final mtu = item['mtu']?.toString();
      final parts = [tag, if (type.isNotEmpty) type, if (mtu != null) 'mtu $mtu'];
      endpoints.add(parts.join(' · '));
    }
    final outbounds = <String>[];
    for (final item in _asList(json['outbounds'])) {
      if (item is! Map) continue;
      final tag = item['tag']?.toString();
      final type = item['type']?.toString();
      if (tag != null || type != null) {
        outbounds.add([tag ?? type!, if (type != null && tag != null) type].join(' · '));
      }
    }
    return ServerChain(
      host: json['host']?.toString(),
      generatedAt: DateTime.tryParse(json['generatedAt']?.toString() ?? ''),
      inbounds: inbounds,
      endpoints: endpoints,
      outbounds: outbounds,
      finalTag: json['final']?.toString(),
      ruleCount: _asList(json['rules']).length,
    );
  }

  static List<dynamic> _asList(Object? value) =>
      value is List ? value : const [];
}

class ServerChainDiagram extends StatelessWidget {
  const ServerChainDiagram({super.key, required this.chain});

  final ServerChain chain;

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final nodes = <String>[
      chain.inboundLabel,
      '${appLocalizations.ruleSetInsightRouteRules}: ${chain.ruleCount}',
      chain.egressLabel,
      appLocalizations.ruleSetInsightInternet,
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (var i = 0; i < nodes.length; i++) ...[
            _Node(label: nodes[i], highlighted: i == nodes.length - 2),
            if (i != nodes.length - 1)
              Text(
                '→',
                style: AppTextStyle.caption1
                    .of(context)
                    .copyWith(color: context.colorScheme.onSurfaceVariant),
              ),
          ],
        ],
      ),
    );
  }
}

class _Node extends StatelessWidget {
  const _Node({required this.label, this.highlighted = false});

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final accent = colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlighted
            ? accent.withValues(alpha: 0.18)
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlighted
              ? accent.withValues(alpha: 0.55)
              : colorScheme.outlineVariant,
        ),
      ),
      child: Text(
        label,
        style: AppTextStyle.caption1
            .of(context)
            .copyWith(color: highlighted ? accent : colorScheme.onSurface),
      ),
    );
  }
}
