import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/features/ruleset_insight/egress_chain.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter/widgets.dart';

class EgressChainList extends StatelessWidget {
  const EgressChainList({super.key, required this.chains, this.onSelect});

  final List<EgressChain> chains;
  final ValueChanged<EgressChain>? onSelect;

  @override
  Widget build(BuildContext context) {
    if (chains.isEmpty) return const SizedBox.shrink();
    final appLocalizations = context.appLocalizations;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          for (final chain in chains)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onSelect == null ? null : () => onSelect!(chain),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                Text(
                  '${chain.target} ×${chain.count}',
                  style: AppTextStyle.caption1
                      .of(context, emphasized: true)
                      .copyWith(color: context.colorScheme.onSurface),
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (var i = 0; i < chain.hops.length; i++) ...[
                      _Hop(
                        label: chain.hops[i],
                        terminal: i == chain.hops.length - 1,
                      ),
                      Text(
                        '→',
                        style: AppTextStyle.caption1
                            .of(context)
                            .copyWith(color: context.colorScheme.onSurfaceVariant),
                      ),
                    ],
                    _Hop(
                      label: appLocalizations.ruleSetInsightInternet,
                      terminal: false,
                    ),
                  ],
                ),
                if (chain.note != null)
                  Text(
                    chain.note!,
                    style: AppTextStyle.caption2
                        .of(context)
                        .copyWith(color: context.colorScheme.onSurfaceVariant),
                  ),
              ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Hop extends StatelessWidget {
  const _Hop({required this.label, required this.terminal});

  final String label;
  final bool terminal;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final accent = colorScheme.primary;
    final isReject = label.startsWith('REJECT');
    final color = isReject ? colorScheme.error : accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: terminal
            ? color.withValues(alpha: 0.18)
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: terminal
              ? color.withValues(alpha: 0.55)
              : colorScheme.outlineVariant,
        ),
      ),
      child: Text(
        label,
        style: AppTextStyle.caption2.of(context).copyWith(
          color: terminal ? color : colorScheme.onSurface,
        ),
      ),
    );
  }
}
