import 'dart:math' as math;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/features/ruleset_insight/rule_set_analyzer.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter/widgets.dart';

class RuleStructureDiagram extends StatelessWidget {
  const RuleStructureDiagram({super.key, required this.report});

  final RuleSetReport report;

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _Chip(
            label: appLocalizations.ruleSetInsightRules,
            value: '${report.ruleCount}',
          ),
          _Chip(
            label: appLocalizations.ruleSetInsightSections,
            value: '${report.sections.length}',
          ),
          _Chip(
            label: appLocalizations.ruleSetInsightGroups,
            value: '${report.groupCount}',
          ),
          _Chip(
            label: appLocalizations.ruleSetInsightNodes,
            value: '${report.proxyCount}',
          ),
          _Chip(
            label: appLocalizations.ruleSetInsightProviders,
            value: '${report.providerCount}',
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          Text(
            value,
            style: AppTextStyle.subheadline
                .of(context, emphasized: true)
                .copyWith(color: colorScheme.onSurface),
          ),
          Text(
            label,
            style: AppTextStyle.caption1
                .of(context)
                .copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class RuleFlowDiagram extends StatelessWidget {
  const RuleFlowDiagram({super.key, required this.report});

  final RuleSetReport report;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final sections = report.sections;
    final targets = report.targetCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (sections.isEmpty || targets.isEmpty) {
      return const SizedBox.shrink();
    }
    const rowHeight = 64.0;
    const targetHeight = 50.0;
    const outerPadding = 12.0;
    final height = math.max(
          sections.length * rowHeight,
          targets.length * targetHeight,
        ) +
        outerPadding * 2;
    final palette = _FlowPalette(
      surface: colorScheme.surfaceContainerHighest,
      border: colorScheme.outlineVariant,
      text: colorScheme.onSurface,
      subtext: colorScheme.onSurfaceVariant,
      accent: colorScheme.primary,
      error: colorScheme.error,
      edge: colorScheme.outline,
      titleStyle: AppTextStyle.footnote.of(context, emphasized: true),
      bodyStyle: AppTextStyle.caption1.of(context),
      countStyle: AppTextStyle.caption2.of(context),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, constraints) => CustomPaint(
            size: Size(constraints.maxWidth, height),
            painter: _FlowPainter(
              report: report,
              targets: targets,
              palette: palette,
            ),
          ),
        ),
      ),
    );
  }
}

class _FlowPalette {
  const _FlowPalette({
    required this.surface,
    required this.border,
    required this.text,
    required this.subtext,
    required this.accent,
    required this.error,
    required this.edge,
    required this.titleStyle,
    required this.bodyStyle,
    required this.countStyle,
  });

  final Color surface;
  final Color border;
  final Color text;
  final Color subtext;
  final Color accent;
  final Color error;
  final Color edge;
  final TextStyle titleStyle;
  final TextStyle bodyStyle;
  final TextStyle countStyle;
}

class _FlowPainter extends CustomPainter {
  _FlowPainter({
    required this.report,
    required this.targets,
    required this.palette,
  });

  final RuleSetReport report;
  final List<MapEntry<String, int>> targets;
  final _FlowPalette palette;

  static const double _outer = 12;
  static const double _gap = 10;

  @override
  void paint(Canvas canvas, Size size) {
    final sections = report.sections;
    final sectionWidth = math.max(120.0, size.width * 0.42);
    final targetWidth = math.max(96.0, size.width * 0.3);
    final sectionHeight = math.min(
      46.0,
      (size.height - _outer * 2 - _gap * (sections.length - 1)) /
          sections.length,
    );
    final targetHeight = math.min(
      34.0,
      (size.height - _outer * 2 - _gap * (targets.length - 1)) / targets.length,
    );

    final sectionRects = <int, Rect>{};
    for (var i = 0; i < sections.length; i++) {
      final top = _outer + i * (sectionHeight + _gap);
      sectionRects[i] = Rect.fromLTWH(_outer, top, sectionWidth, sectionHeight);
    }

    final targetRects = <String, Rect>{};
    for (var i = 0; i < targets.length; i++) {
      final top = _outer + i * (targetHeight + _gap);
      targetRects[targets[i].key] = Rect.fromLTWH(
        size.width - _outer - targetWidth,
        top,
        targetWidth,
        targetHeight,
      );
    }

    final edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < sections.length; i++) {
      final section = sections[i];
      final counts = section.targetCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      for (final entry in counts) {
        final from = sectionRects[i]!.centerRight.translate(0, 0);
        final to = targetRects[entry.key]!.centerLeft;
        final strength = (entry.value / math.max(1, section.rules.length))
            .clamp(0.25, 1.0);
        edgePaint
          ..color = _targetColor(entry.key).withValues(alpha: 0.25 + 0.45 * strength)
          ..strokeWidth = 1 + 2.2 * strength;
        final path = Path()
          ..moveTo(from.dx, from.dy)
          ..cubicTo(
            from.dx + (to.dx - from.dx) * 0.45,
            from.dy,
            to.dx - (to.dx - from.dx) * 0.45,
            to.dy,
            to.dx,
            to.dy,
          );
        canvas.drawPath(path, edgePaint);
        _paintCount(canvas, path, entry.value);
      }
    }

    for (var i = 0; i < sections.length; i++) {
      final rect = sectionRects[i]!;
      final section = sections[i];
      _roundBox(canvas, rect, palette.surface, palette.border);
      _text(
        canvas,
        section.title,
        Rect.fromLTWH(rect.left + 8, rect.top + 4, rect.width - 46, rect.height - 8),
        palette.titleStyle.copyWith(color: palette.text),
        maxLines: 2,
      );
      _text(
        canvas,
        '${section.rules.length}',
        Rect.fromLTWH(rect.right - 34, rect.top + 6, 26, 18),
        palette.countStyle.copyWith(color: palette.subtext),
        align: TextAlign.right,
      );
    }

    for (final entry in targets) {
      final rect = targetRects[entry.key]!;
      final color = _targetColor(entry.key);
      _roundBox(canvas, rect, color.withValues(alpha: 0.22), color.withValues(alpha: 0.62));
      _text(
        canvas,
        entry.key,
        Rect.fromLTWH(rect.left + 10, rect.top, rect.width - 46, rect.height),
        palette.bodyStyle.copyWith(
          color: palette.text,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        center: true,
      );
      _text(
        canvas,
        '${entry.value}',
        Rect.fromLTWH(rect.right - 38, rect.top, 30, rect.height),
        palette.countStyle.copyWith(color: palette.subtext),
        align: TextAlign.right,
        center: true,
      );
    }
  }

  Color _targetColor(String target) {
    if (target.startsWith('REJECT')) return palette.error;
    if (target.toUpperCase() == 'DIRECT') return palette.edge;
    return palette.accent;
  }

  void _roundBox(Canvas canvas, Rect rect, Color fill, Color border) {
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(10));
    canvas.drawRRect(rrect, Paint()..color = fill);
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = border,
    );
  }

  void _paintCount(Canvas canvas, Path path, int count) {
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = metrics.first;
    final position = metric.getTangentForOffset(metric.length * 0.5);
    if (position == null) return;
    final painter = TextPainter(
      text: TextSpan(
        text: '$count',
        style: palette.countStyle.copyWith(color: palette.subtext),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final rect = Rect.fromCenter(
      center: position.position.translate(0, -8),
      width: painter.width + 8,
      height: painter.height + 2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()..color = palette.surface.withValues(alpha: 0.9),
    );
    painter.paint(
      canvas,
      Offset(rect.center.dx - painter.width / 2, rect.center.dy - painter.height / 2),
    );
  }

  void _text(
    Canvas canvas,
    String value,
    Rect rect,
    TextStyle style, {
    int maxLines = 1,
    TextAlign align = TextAlign.left,
    bool center = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: value, style: style),
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      ellipsis: '…',
      textAlign: align,
    )..layout(maxWidth: rect.width);
    final dy = center
        ? rect.top + (rect.height - painter.height) / 2
        : rect.top + 2;
    painter.paint(canvas, Offset(rect.left, dy));
  }

  @override
  bool shouldRepaint(covariant _FlowPainter oldDelegate) =>
      oldDelegate.report != report || oldDelegate.palette != palette;
}
