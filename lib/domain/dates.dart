/// Calendar-date helpers.
///
/// Cycle events are calendar dates, not moments in time. They are held as
/// UTC-midnight [DateTime]s so that day arithmetic never crosses a
/// daylight-saving change.
library;

DateTime dateOnly(DateTime d) => DateTime.utc(d.year, d.month, d.day);

/// Today's date on this device's own calendar.
DateTime todayDate() => dateOnly(DateTime.now());

DateTime addDays(DateTime d, int days) =>
    DateTime.utc(d.year, d.month, d.day + days);

/// Whole calendar days from [from] to [to] (negative if [to] is earlier).
int daysBetween(DateTime from, DateTime to) =>
    dateOnly(to).difference(dateOnly(from)).inDays;

bool sameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// 'YYYY-MM-DD' as used by the database `date` type.
String toDbDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

DateTime parseDbDate(String s) {
  final parts = s.split('-');
  if (parts.length != 3) {
    throw FormatException('Not a YYYY-MM-DD date', s);
  }
  return DateTime.utc(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2].substring(0, 2)),
  );
}

/// Monday of the week containing [d].
DateTime startOfWeek(DateTime d) => addDays(dateOnly(d), -(d.weekday - 1));

DateTime firstOfMonth(DateTime d) => DateTime.utc(d.year, d.month, 1);

int daysInMonth(int year, int month) => DateTime.utc(year, month + 1, 0).day;
