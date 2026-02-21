class EcuadorTime {
  static const Duration _ecuadorOffset = Duration(hours: -5);

  // Parses server timestamp (ideally UTC) and normalizes it for Ecuador UI.
  static DateTime parseServerToEcuador(String raw) {
    final parsed = DateTime.parse(raw);
    final utc = parsed.isUtc ? parsed : parsed.toUtc();
    return utc.add(_ecuadorOffset);
  }

  // Converts a local Ecuador wall-clock datetime to UTC ISO string for backend.
  static String ecuadorLocalToUtcIso(DateTime ecuadorLocal) {
    final utc = DateTime.utc(
      ecuadorLocal.year,
      ecuadorLocal.month,
      ecuadorLocal.day,
      ecuadorLocal.hour + 5,
      ecuadorLocal.minute,
      ecuadorLocal.second,
      ecuadorLocal.millisecond,
      ecuadorLocal.microsecond,
    );
    return utc.toIso8601String();
  }

  // Date-only fields should be sent without time/timezone shifts.
  static String dateOnlyIso(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
