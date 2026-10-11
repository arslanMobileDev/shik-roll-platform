import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Russian month names in the nominative case. `intl`'s `DateFormat.MMMM('ru')`
/// returns the lowercase genitive ("октября"), which reads wrong on a grid of
/// month buttons and would need manual capitalisation anyway.
const List<String> _months = [
  'Январь',
  'Февраль',
  'Март',
  'Апрель',
  'Май',
  'Июнь',
  'Июль',
  'Август',
  'Сентябрь',
  'Октябрь',
  'Ноябрь',
  'Декабрь',
];

/// Weeks start on Monday — `DateTime.weekday` is 1 (Mon) .. 7 (Sun).
const List<String> _weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

/// Single-day picker. Opens on the **month grid** of [initialDate], so jumping
/// a year back costs two taps instead of scrolling a year list.
Future<DateTime?> showShikDatePicker(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String title = 'Выберите дату',
}) => showDialog<DateTime>(
  context: context,
  builder: (_) => _ShikCalendarDialog(
    title: title,
    initialCursor: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
  ),
);

/// Range picker: one dialog, three phases — start → end → confirm.
/// Keeps the calendar open between phases so the range stays visible, instead
/// of the two independent full-screen pickers it replaces.
Future<DateTimeRange?> showShikDateRangePicker(
  BuildContext context, {
  required DateTime firstDate,
  required DateTime lastDate,
  DateTime? initialFrom,
  DateTime? initialTo,
}) => showDialog<DateTimeRange>(
  context: context,
  builder: (_) => _ShikCalendarDialog(
    initialCursor: initialFrom ?? initialTo ?? DateTime.now(),
    firstDate: firstDate,
    lastDate: lastDate,
    range: true,
    initialFrom: initialFrom,
    initialTo: initialTo,
  ),
);

enum _Phase { start, end, ready }

class _ShikCalendarDialog extends StatefulWidget {
  const _ShikCalendarDialog({
    required this.initialCursor,
    required this.firstDate,
    required this.lastDate,
    this.title = 'Выберите дату',
    this.range = false,
    this.initialFrom,
    this.initialTo,
  });

  final DateTime initialCursor;
  final DateTime firstDate;
  final DateTime lastDate;
  final String title;
  final bool range;
  final DateTime? initialFrom;
  final DateTime? initialTo;

  @override
  State<_ShikCalendarDialog> createState() => _ShikCalendarDialogState();
}

class _ShikCalendarDialogState extends State<_ShikCalendarDialog> {
  late final DateTime _min = _dateOnly(widget.firstDate);
  late final DateTime _max = _dateOnly(widget.lastDate);

  /// First day of the month currently on screen.
  late DateTime _cursor = _clampMonth(_dateOnly(widget.initialCursor));

  /// Month grid (12 months of [_cursor.year]) vs day grid of [_cursor.month].
  bool _monthGrid = true;

  _Phase _phase = _Phase.start;
  DateTime? _from;
  DateTime? _to;

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static bool _sameDay(DateTime? a, DateTime? b) =>
      a != null && b != null && a.year == b.year && a.month == b.month && a.day == b.day;

  static String _fmt(DateTime d) => '${d.day.toString().padLeft(2, '0')}.'
      '${d.month.toString().padLeft(2, '0')}.${d.year}';

  DateTime _clampMonth(DateTime value) {
    final floor = DateTime(_min.year, _min.month);
    final ceil = DateTime(_max.year, _max.month);
    if (value.isBefore(floor)) return floor;
    if (value.isAfter(ceil)) return ceil;
    return value;
  }

  DateTime? _clampDay(DateTime? value) {
    if (value == null) return null;
    final d = _dateOnly(value);
    if (d.isBefore(_min)) return _min;
    if (d.isAfter(_max)) return _max;
    return d;
  }

  @override
  void initState() {
    super.initState();
    _cursor = _clampMonth(_dateOnly(widget.initialCursor));
    if (widget.range) {
      _from = _clampDay(widget.initialFrom);
      _to = _clampDay(widget.initialTo);
      _phase = _from == null ? _Phase.start : _Phase.end;
    }
  }

  bool get _canPrevMonth =>
      _cursor.isAfter(DateTime(_min.year, _min.month));

  bool get _canNextMonth => _cursor.isBefore(DateTime(_max.year, _max.month));

  String get _title => switch (_phase) {
    _Phase.start => 'Начало периода',
    _Phase.end => 'Конец периода',
    _Phase.ready => 'Период',
  };

  void _shiftMonth(int delta) {
    final next = DateTime(_cursor.year, _cursor.month + delta);
    if (next.isBefore(DateTime(_min.year, _min.month)) ||
        next.isAfter(DateTime(_max.year, _max.month))) {
      return;
    }
    setState(() => _cursor = next);
  }

  void _shiftYear(int delta) {
    setState(() {
      _cursor = _clampMonth(
        DateTime(_cursor.year + delta, _cursor.month),
      );
    });
  }

  void _pick(DateTime date) {
    if (!widget.range) {
      Navigator.of(context).pop(date);
      return;
    }
    setState(() {
      switch (_phase) {
        case _Phase.start:
        case _Phase.ready:
          _from = date;
          _to = null;
          _phase = _Phase.end;
        case _Phase.end:
          _to = date;
          _phase = _Phase.ready;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 340,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.range ? _title : widget.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              SizedBox(
                height: 18,
                child: Text(
                  widget.range && _from != null
                      ? 'начало: ${_fmt(_from!)}'
                      : '',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.inkMuted,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 300,
                child: _monthGrid ? _buildMonths() : _buildDays(),
              ),
              const SizedBox(height: 4),
              SizedBox(height: 44, child: _buildFooter()),
            ],
          ),
        ),
      ),
    );
  }

  // ── Month grid ───────────────────────────────────────────────────────────

  Widget _buildMonths() {
    return Column(
      children: [
        _arrowHeader(
          center: Text(
            '${_cursor.year}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          onPrev: _canPrevMonth ? () => _shiftYear(-1) : null,
          onNext: _canNextMonth ? () => _shiftYear(1) : null,
          prevKey: const ValueKey('shik.datePicker.prevYear'),
          nextKey: const ValueKey('shik.datePicker.nextYear'),
        ),
        const SizedBox(height: 4),
        for (var row = 0; row < 4; row++)
          Expanded(
            child: Row(
              children: [
                for (var col = 0; col < 3; col++)
                  Expanded(child: _monthCell(row * 3 + col + 1)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _monthCell(int month) {
    final value = DateTime(_cursor.year, month);
    final disabled =
        value.isBefore(DateTime(_min.year, _min.month)) ||
        value.isAfter(DateTime(_max.year, _max.month));
    final active = month == _cursor.month;

    return Padding(
      padding: const EdgeInsets.all(4),
      child: Material(
        color: active
            ? AppColors.terracotta.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          key: ValueKey('shik.datePicker.month.$month'),
          borderRadius: BorderRadius.circular(10),
          onTap: disabled
              ? null
              : () => setState(() {
                  _cursor = value;
                  _monthGrid = false;
                }),
          child: Center(
            child: Text(
              _months[month - 1],
              style: TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: disabled
                    ? AppColors.inkMuted.withValues(alpha: 0.35)
                    : AppColors.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Day grid ─────────────────────────────────────────────────────────────

  Widget _buildDays() {
    final today = _dateOnly(DateTime.now());
    return Column(
      children: [
        _arrowHeader(
          center: InkWell(
            key: const ValueKey('shik.datePicker.monthTitle'),
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _monthGrid = true),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '${_months[_cursor.month - 1]} ${_cursor.year}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ),
          ),
          onPrev: _canPrevMonth ? () => _shiftMonth(-1) : null,
          onNext: _canNextMonth ? () => _shiftMonth(1) : null,
          prevKey: const ValueKey('shik.datePicker.prevMonth'),
          nextKey: const ValueKey('shik.datePicker.nextMonth'),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final label in _weekdays)
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        // Always six rows so the cell size does not jump between months.
        for (final week in _weeks())
          Expanded(
            child: Row(
              children: [
                for (final date in week)
                  Expanded(child: _dayCell(date, today)),
              ],
            ),
          ),
      ],
    );
  }

  List<List<DateTime?>> _weeks() {
    final daysInMonth = DateTime(_cursor.year, _cursor.month + 1, 0).day;
    final lead = DateTime(_cursor.year, _cursor.month, 1).weekday - 1;
    return [
      for (var week = 0; week < 6; week++)
        [
          for (var slot = 0; slot < 7; slot++)
            _dayAt(week * 7 + slot - lead + 1, daysInMonth),
        ],
    ];
  }

  DateTime? _dayAt(int dayNumber, int daysInMonth) =>
      (dayNumber < 1 || dayNumber > daysInMonth)
      ? null
      : DateTime(_cursor.year, _cursor.month, dayNumber);

  Widget _dayCell(DateTime? date, DateTime today) {
    if (date == null) return const SizedBox.shrink();

    final selected = _sameDay(date, _from) || _sameDay(date, _to);
    final inRange =
        _from != null && _to != null && date.isAfter(_from!) && date.isBefore(_to!);
    // Days before the chosen start are locked in the end phase — matching the
    // old `firstDate: start`. Correcting a wrong start means cancelling.
    final disabled =
        date.isBefore(_min) ||
        date.isAfter(_max) ||
        (_phase == _Phase.end && _from != null && date.isBefore(_from!));
    final isToday = _sameDay(date, today);

    final Color textColor;
    if (selected) {
      textColor = Colors.white;
    } else if (disabled) {
      textColor = AppColors.inkMuted.withValues(alpha: 0.35);
    } else {
      textColor = AppColors.ink;
    }

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: selected
            ? AppColors.terracotta
            : inRange
            ? AppColors.terracotta.withValues(alpha: 0.12)
            : Colors.transparent,
        shape: CircleBorder(
          side: !selected && isToday
              ? const BorderSide(color: AppColors.terracotta, width: 1.5)
              : BorderSide.none,
        ),
        child: InkWell(
          key: ValueKey(
            'shik.datePicker.day.'
            '${date.year}-${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}',
          ),
          customBorder: const CircleBorder(),
          onTap: disabled ? null : () => _pick(date),
          child: Center(
            child: Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Chrome ───────────────────────────────────────────────────────────────

  Widget _arrowHeader({
    required Widget center,
    required VoidCallback? onPrev,
    required VoidCallback? onNext,
    required Key prevKey,
    required Key nextKey,
  }) {
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          _arrow(Icons.chevron_left_rounded, onPrev, prevKey),
          Expanded(child: center),
          _arrow(Icons.chevron_right_rounded, onNext, nextKey),
        ],
      ),
    );
  }

  Widget _arrow(IconData icon, VoidCallback? onTap, Key key) => IconButton(
    key: key,
    onPressed: onTap,
    icon: Icon(icon, size: 20),
    color: AppColors.ink,
    disabledColor: AppColors.inkMuted.withValues(alpha: 0.35),
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints.tightFor(width: 36, height: 36),
  );

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          key: const ValueKey('shik.datePicker.cancel'),
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: AppColors.inkMuted),
          child: const Text('Отмена'),
        ),
        if (widget.range && _phase == _Phase.ready) ...[
          const SizedBox(width: 8),
          FilledButton(
            key: const ValueKey('shik.datePicker.apply'),
            onPressed: () => Navigator.of(
              context,
            ).pop(DateTimeRange(start: _from!, end: _to!)),
            child: const Text('Применить'),
          ),
        ],
      ],
    );
  }
}
