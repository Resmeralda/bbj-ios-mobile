import 'package:flutter/material.dart';

import '../models/training_session.dart' show formatDate;
import '../theme.dart';
import 'common.dart';

Future<void> showFormSheet(BuildContext context, Widget form) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(c).viewInsets.bottom,
        ),
        child: SingleChildScrollView(child: form),
      ),
    );

Future<bool> confirmDelete(BuildContext context, String what) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text('Delete $what?'),
      content: const Text('This cannot be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(c, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return ok ?? false;
}

String? requiredPositive(String? v) {
  final n = double.tryParse(v ?? '');
  return (n == null || n <= 0) ? 'Enter a number above 0' : null;
}

String? optionalNumber(String? v) {
  if (v == null || v.trim().isEmpty) return null;
  final n = double.tryParse(v);
  return (n == null || n < 0) ? 'Enter a valid number' : null;
}

String? requiredText(String? v, String message) =>
    (v == null || v.trim().isEmpty) ? message : null;

String oneDecimal(double v) => v.toStringAsFixed(1);

String hoursLabel(double h) {
  final total = (h * 60).round();
  return '${total ~/ 60} hr ${total % 60} min';
}

class SheetTitle extends StatelessWidget {
  final String text;
  const SheetTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: AppColors.ink,
      ),
    ),
  );
}

class DateField extends StatelessWidget {
  final DateTime date;
  final ValueChanged<DateTime> onChanged;
  const DateField({super.key, required this.date, required this.onChanged});

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: const Text('Date'),
    subtitle: Text(formatDate(date)),
    trailing: const Icon(Icons.calendar_month),
    onTap: () async {
      final d = await showDatePicker(
        context: context,
        initialDate: date,
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 1)),
      );
      if (d != null) onChanged(d);
    },
  );
}

/// 1-5 selector with a caption for each end.
class RatingPicker extends StatelessWidget {
  final String label, low, high;
  final int value;
  final ValueChanged<int> onChanged;
  const RatingPicker({
    super.key,
    required this.label,
    required this.low,
    required this.high,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        SegmentedButton<int>(
          showSelectedIcon: false,
          segments: [
            for (var i = 1; i <= 5; i++)
              ButtonSegment<int>(value: i, label: Text('$i')),
          ],
          selected: {value},
          onSelectionChanged: (s) => onChanged(s.first),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              low,
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
            Text(
              high,
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ),
      ],
    ),
  );
}

class AddButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  const AddButton({
    super.key,
    required this.label,
    required this.color,
    required this.onPressed,
    this.icon = Icons.add,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.all(16),
      ),
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    ),
  );
}

class EntryTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, subtitle;
  final String? extra;
  final VoidCallback onTap, onDelete;
  const EntryTile({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.onDelete,
    this.extra,
  });

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: onTap,
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              if (extra != null && extra!.isNotEmpty)
                Text(
                  extra!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, color: AppColors.muted),
          onPressed: onDelete,
        ),
      ],
    ),
  );
}

class StatCard extends StatelessWidget {
  final String label, value;
  final Color color;
  const StatCard(
    this.label,
    this.value, {
    super.key,
    this.color = AppColors.tint,
  });

  @override
  Widget build(BuildContext context) => AppCard(
    color: color,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );
}

class StatRow extends StatelessWidget {
  final List<StatCard> cards;
  const StatRow(this.cards, {super.key});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < cards.length; i++) ...[
        if (i > 0) const SizedBox(width: 8),
        Expanded(child: cards[i]),
      ],
    ],
  );
}

class EmptyState extends StatelessWidget {
  final String message;
  const EmptyState(this.message, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.muted),
      ),
    ),
  );
}
