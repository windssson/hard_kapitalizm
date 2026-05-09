class AppDateTime {
  static DateTime toTurkeyTime(DateTime dateTime) {
    return dateTime.toLocal();
  }

  static String formatTurkeyDateTime(DateTime dateTime) {
    final local = toTurkeyTime(dateTime);
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    final hours = local.hour.toString().padLeft(2, '0');
    final minutes = local.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hours:$minutes';
  }
}
