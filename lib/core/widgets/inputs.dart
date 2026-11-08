import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/dates.dart';
import '../theme/app_theme.dart';

/// Tappable field that opens a date picker. Works in calendar dates only.
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.firstDate,
    required this.lastDate,
    required this.onChanged,
    this.allowClear = true,
  });

  final String label;
  final DateTime? value;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime?> onChanged;
  final bool allowClear;

  Future<void> _pick(BuildContext context) async {
    final initial = value ?? lastDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(firstDate)
          ? firstDate
          : (initial.isAfter(lastDate) ? lastDate : initial),
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: label,
    );
    if (picked != null) onChanged(dateOnly(picked));
  }

  @override
  Widget build(BuildContext context) {
    final text = value == null
        ? 'Choose a date'
        : DateFormat('EEE, d MMM yyyy').format(value!);
    return Semantics(
      button: true,
      label: '$label: $text',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _pick(context),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.event_outlined),
            suffixIcon: (allowClear && value != null)
                ? IconButton(
                    tooltip: 'Clear',
                    icon: const Icon(Icons.close),
                    onPressed: () => onChanged(null),
                  )
                : null,
          ),
          child: Text(
            text,
            style: value == null
                ? TextStyle(color: context.cycle.muted)
                : null,
          ),
        ),
      ),
    );
  }
}

/// − value + control for small whole numbers.
class NumberStepper extends StatelessWidget {
  const NumberStepper({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.unit = '',
    this.enabled = true,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final String unit;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? context.cycle.heading : context.cycle.muted;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: context.text.titleSmall?.copyWith(color: color)),
          ),
          IconButton.filledTonal(
            tooltip: 'Decrease $label',
            onPressed:
                enabled && value > min ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove),
          ),
          SizedBox(
            width: 84,
            child: Text(
              '$value $unit'.trim(),
              textAlign: TextAlign.center,
              style: context.text.titleMedium?.copyWith(color: color),
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Increase $label',
            onPressed:
                enabled && value < max ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

/// Square selectable tile with an icon and label (symptoms, flow).
class ChoiceTile extends StatelessWidget {
  const ChoiceTile({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.color,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? context.colors.primary;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected
            ? accent.withValues(alpha: 0.14)
            : context.colors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: selected ? accent : context.cycle.cardBorder,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: accent, size: 26),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: context.cycle.heading,
                  ),
                ),
                if (selected)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(Icons.check_circle, size: 14, color: accent),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
