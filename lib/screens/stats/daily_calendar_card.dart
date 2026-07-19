import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../models/daily.dart';
import '../../services/daily_puzzle_service.dart';
import '../../state/auth_controller.dart';
import '../../theme/app_palette.dart';
import '../../widgets/pop_card.dart';

/// A month-grid calendar of the player's daily-sudoku completions, shown at
/// the top of the stats screen. Self-contained grid (no calendar package) so
/// it matches the app's PopCard/AppPalette look. Requires sign-in; degrades
/// to a message if signed out or if the history RPC isn't available yet
/// (migration 0011 unapplied).
class DailyCalendarCard extends StatefulWidget {
  const DailyCalendarCard({super.key, required this.auth, this.service});

  final AuthController auth;

  /// Test seam. In production this is null and a real [DailyPuzzleService]
  /// is created lazily — only when signed in, so a signed-out render never
  /// touches [Supabase.instance] (which would throw if uninitialized).
  final DailyPuzzleService? service;

  @override
  State<DailyCalendarCard> createState() => _DailyCalendarCardState();
}

class _DailyCalendarCardState extends State<DailyCalendarCard> {
  DailyPuzzleService? _serviceOrNull;
  DailyPuzzleService get _service =>
      _serviceOrNull ??= widget.service ?? DailyPuzzleService();

  /// First day of the currently-shown month.
  late DateTime _month;

  /// Completions keyed by 'yyyy-MM', so revisiting a month doesn't refetch.
  final _cache = <String, Map<int, DailyHistoryEntry>>{};
  bool _loading = false;
  bool _errored = false;
  DailyHistoryEntry? _selected;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    if (widget.auth.isSignedIn) _loadMonth();
  }

  String _key(DateTime month) =>
      '${month.year}-${month.month.toString().padLeft(2, '0')}';

  Future<void> _loadMonth() async {
    if (_cache.containsKey(_key(_month))) return;
    setState(() {
      _loading = true;
      _errored = false;
    });
    try {
      final from = _month;
      final to = DateTime(_month.year, _month.month + 1, 0); // last day
      final entries = await _service.fetchMyHistory(from: from, to: to);
      _cache[_key(_month)] = {
        for (final e in entries) e.date.day: e,
      };
    } catch (_) {
      _errored = true;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changeMonth(int delta) {
    final next = DateTime(_month.year, _month.month + delta);
    final thisMonth = DateTime(DateTime.now().year, DateTime.now().month);
    // No navigating into the future.
    if (next.isAfter(thisMonth)) return;
    setState(() {
      _month = next;
      _selected = null;
    });
    _loadMonth();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (!widget.auth.isSignedIn) {
      return PopCard(
        padding: const EdgeInsets.all(20),
        child: Text(l10n.dailyCalendarSignInHint,
            textAlign: TextAlign.center),
      );
    }

    final isDark = AppPalette.isDark(context);
    const teal = AppPalette.dailyTeal;
    final localeCode = Localizations.localeOf(context).languageCode;
    final monthLabel =
        DateFormat.yMMMM(localeCode).format(_month);
    final thisMonth = DateTime(DateTime.now().year, DateTime.now().month);
    final canGoNext = _month.isBefore(thisMonth);
    final days = _cache[_key(_month)] ?? const {};

    return PopCard(
      tint: teal,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _changeMonth(-1),
              ),
              Text(monthLabel,
                  style: const TextStyle(fontFamily: 'Jua', fontSize: 18)),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: canGoNext ? () => _changeMonth(1) : null,
              ),
            ],
          ),
          if (_errored)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(l10n.dailyCalendarLoadError,
                  style: Theme.of(context).textTheme.bodySmall),
            )
          else ...[
            _WeekdayHeader(localeCode: localeCode),
            const SizedBox(height: 4),
            _MonthGrid(
              month: _month,
              days: days,
              teal: teal,
              isDark: isDark,
              selectedDay: _selected?.date.day,
              onTapDay: (entry) => setState(() => _selected = entry),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: SizedBox(
                    height: 2, child: LinearProgressIndicator(minHeight: 2)),
              ),
            if (_selected != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  l10n.dailyCalendarDayDetail(
                    _selected!.date.month,
                    _selected!.date.day,
                    _formatTime(_selected!.elapsedSeconds),
                    _selected!.mistakes,
                  ),
                  style: const TextStyle(fontFamily: 'Jua', color: teal),
                ),
              ),
          ],
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader({required this.localeCode});

  final String localeCode;

  @override
  Widget build(BuildContext context) {
    // DateFormat.E gives the short weekday name; anchor on a known Sunday.
    final fmt = DateFormat.E(localeCode);
    final sunday = DateTime(2024, 1, 7); // a Sunday
    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Center(
              child: Text(
                fmt.format(sunday.add(Duration(days: i))),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.days,
    required this.teal,
    required this.isDark,
    required this.selectedDay,
    required this.onTapDay,
  });

  final DateTime month;
  final Map<int, DailyHistoryEntry> days;
  final Color teal;
  final bool isDark;
  final int? selectedDay;
  final void Function(DailyHistoryEntry) onTapDay;

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // weekday: Mon=1..Sun=7; grid starts on Sunday, so Sun→0 offset.
    final firstWeekday = DateTime(month.year, month.month, 1).weekday % 7;
    final today = DateTime.now();
    final isThisMonth = today.year == month.year && today.month == month.month;

    final cells = <Widget>[];
    for (var i = 0; i < firstWeekday; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var day = 1; day <= daysInMonth; day++) {
      final entry = days[day];
      final isToday = isThisMonth && today.day == day;
      final isSelected = selectedDay == day;
      cells.add(_DayCell(
        day: day,
        completed: entry != null,
        isToday: isToday,
        isSelected: isSelected,
        teal: teal,
        onTap: entry == null ? null : () => onTapDay(entry),
      ));
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: cells,
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.completed,
    required this.isToday,
    required this.isSelected,
    required this.teal,
    required this.onTap,
  });

  final int day;
  final bool completed;
  final bool isToday;
  final bool isSelected;
  final Color teal;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: completed ? teal : Colors.transparent,
            border: isToday || isSelected
                ? Border.all(
                    color: teal, width: isSelected ? 2.5 : 1.5)
                : null,
          ),
          child: Text(
            '$day',
            style: TextStyle(
              color: completed
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurface,
              fontWeight: completed ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
