import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ResponsiveBody extends StatelessWidget {
  const ResponsiveBody({super.key, required this.child, this.maxWidth = 760});
  final Widget child;
  final double maxWidth;
  @override
  Widget build(BuildContext context) => Align(alignment: Alignment.topCenter, child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child));
}

class PeriodSwitcher extends StatelessWidget {
  const PeriodSwitcher({super.key, required this.label, required this.onPrevious, required this.onNext});
  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  @override
  Widget build(BuildContext context) => Card(child: Row(children: [
    IconButton(tooltip: 'Previous', onPressed: onPrevious, icon: const Icon(Icons.chevron_left)),
    Expanded(child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
    IconButton(tooltip: 'Next', onPressed: onNext, icon: const Icon(Icons.chevron_right)),
  ]));
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(4, 14, 4, 4), child: Row(children: [
    Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.ink))),
    if (trailing != null) trailing!,
  ]));
}

class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.title, required this.value, this.subtitle, this.icon, this.color});
  final String title;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.brand;
    return Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
      if (icon != null) CircleAvatar(backgroundColor: tint.withValues(alpha: .12), child: Icon(icon, color: tint)),
      if (icon != null) const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 5),
        Text(value, style: const TextStyle(color: AppColors.ink, fontSize: 20, fontWeight: FontWeight.w800)),
        if (subtitle != null) Text(subtitle!, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
      ])),
    ])));
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, this.message, this.icon = Icons.inbox_outlined});
  final String title;
  final String? message;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 40, color: AppColors.muted), const SizedBox(height: 10),
    Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    if (message != null) ...[const SizedBox(height: 4), Text(message!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted))],
  ]));
}
