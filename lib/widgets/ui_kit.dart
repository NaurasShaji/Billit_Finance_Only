import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';

/// Session-only privacy switch: hides every money value in the app.
final ValueNotifier<bool> hideAmounts = ValueNotifier<bool>(false);

/// "Today", "Yesterday" or a readable date.
String dayLabel(DateTime d) {
  final now = DateTime.now();
  final today = DateTime.utc(now.year, now.month, now.day);
  final day = DateTime.utc(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return DateFormat('EEE, dd MMM yyyy').format(d);
}

class MaskedText extends StatelessWidget {
  const MaskedText(this.text, {super.key, this.style, this.textAlign});
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: hideAmounts,
    builder: (context, hidden, _) =>
        Text(hidden ? '₹ ••••' : text, style: style, textAlign: textAlign),
  );
}

class ResponsiveBody extends StatelessWidget {
  const ResponsiveBody({super.key, required this.child, this.maxWidth = 760});
  final Widget child;
  final double maxWidth;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

class PeriodSwitcher extends StatelessWidget {
  const PeriodSwitcher({
    super.key,
    required this.label,
    required this.onPrevious,
    required this.onNext,
  });
  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  @override
  Widget build(BuildContext context) => Card(
    child: Row(
      children: [
        IconButton(
          tooltip: 'Previous',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
        IconButton(
          tooltip: 'Next',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    ),
  );
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: context.ink,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    ),
  );
}

/// Date heading used when a list is grouped by day.
class DayHeader extends StatelessWidget {
  const DayHeader({super.key, required this.label, this.total});
  final String label;
  final double? total;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 14, 4, 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: context.muted,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ),
        if (total != null)
          MaskedText(
            _money(total!),
            style: TextStyle(
              color: context.muted,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
      ],
    ),
  );
  static String _money(double v) =>
      NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(v);
}

class DeltaChip extends StatelessWidget {
  const DeltaChip({super.key, required this.delta, this.lowerIsBetter = false});
  final double delta;
  final bool lowerIsBetter;
  @override
  Widget build(BuildContext context) {
    final flat = delta.abs() < 0.5;
    final up = delta > 0;
    final Color color;
    if (flat) {
      color = context.muted;
    } else {
      color = (up != lowerIsBetter) ? context.good : context.bad;
    }
    final text = flat
        ? '–'
        : '${up ? '▲' : '▼'} ${delta.abs().toStringAsFixed(0)}%';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.title,
    required this.value,
    this.icon,
    this.color,
    this.delta,
    this.lowerIsBetter = false,
    this.info,
    this.mask = true,
  });
  final String title;
  final String value;
  final IconData? icon;
  final Color? color;

  /// Percentage change versus the previous period.
  final double? delta;
  final bool lowerIsBetter;

  /// Shown on tap of an (i) icon instead of permanent helper text.
  final String? info;

  /// Set to false for values that are not money (e.g. a percentage).
  final bool mask;
  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.brand;
    final valueStyle = TextStyle(
      color: context.ink,
      fontSize: 21,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.3,
    );
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null)
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: tint.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 18, color: tint),
                  ),
                if (icon != null) const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.muted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (info != null)
                  Tooltip(
                    message: info!,
                    triggerMode: TooltipTriggerMode.tap,
                    showDuration: const Duration(seconds: 4),
                    child: Icon(
                      Icons.info_outline,
                      size: 16,
                      color: context.muted,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: mask
                  ? MaskedText(value, style: valueStyle)
                  : Text(value, style: valueStyle),
            ),
            if (delta != null) ...[
              const SizedBox(height: 6),
              DeltaChip(delta: delta!, lowerIsBetter: lowerIsBetter),
            ],
          ],
        ),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.label, this.color, {super.key});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
    ),
  );
}

class BarSegment {
  const BarSegment(this.label, this.value, this.color);
  final String label;
  final double value;
  final Color color;
}

/// Stacked proportional bar with a colour legend.
class BreakdownBar extends StatelessWidget {
  const BreakdownBar({super.key, required this.segments});
  final List<BarSegment> segments;
  @override
  Widget build(BuildContext context) {
    final active = segments.where((s) => s.value > 0).toList();
    final total = active.fold<double>(0, (sum, s) => sum + s.value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 10,
            child: total == 0
                ? ColoredBox(
                    color: context.hairline,
                    child: const SizedBox.expand(),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final s in active)
                        Expanded(
                          flex: (s.value / total * 1000)
                              .round()
                              .clamp(1, 1000)
                              .toInt(),
                          child: ColoredBox(color: s.color),
                        ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            for (final s in segments)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: s.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    s.label,
                    style: TextStyle(fontSize: 12, color: context.muted),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

/// Today / Yesterday / custom date selector — faster than a date picker alone.
class DateField extends StatelessWidget {
  const DateField({super.key, required this.value, required this.onChanged});
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  static bool _same(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    final custom = !_same(value, today) && !_same(value, yesterday);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: const Text('Today'),
          selected: _same(value, today),
          onSelected: (_) => onChanged(today),
        ),
        ChoiceChip(
          label: const Text('Yesterday'),
          selected: _same(value, yesterday),
          onSelected: (_) => onChanged(yesterday),
        ),
        ChoiceChip(
          avatar: const Icon(Icons.calendar_today_outlined, size: 16),
          label: Text(
            custom ? DateFormat('dd MMM yyyy').format(value) : 'Pick date',
          ),
          selected: custom,
          onSelected: (_) async {
            final picked = await Navigator.of(context).push<DateTime>(
              MaterialPageRoute(builder: (_) => _DateSelectionPage(initialDate: value)),
            );
            if (picked != null) onChanged(picked);
          },
        ),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.icon = Icons.inbox_outlined,
    this.action,
  });
  final String title;
  final IconData icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: context.muted),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(fontWeight: FontWeight.w700, color: context.muted),
          ),
          if (action != null) ...[const SizedBox(height: 14), action!],
        ],
      ),
    ),
  );
}

class _DateSelectionPage extends StatefulWidget {
  const _DateSelectionPage({required this.initialDate});
  final DateTime initialDate;
  @override
  State<_DateSelectionPage> createState() => _DateSelectionPageState();
}
class _DateSelectionPageState extends State<_DateSelectionPage> {
  late DateTime _selected = widget.initialDate;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Choose date'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, _selected), child: const Text('Done'))],
    ),
    body: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: CalendarDatePicker(
        initialDate: _selected,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        onDateChanged: (date) => setState(() => _selected = date),
      ),
    )),
  );
}
