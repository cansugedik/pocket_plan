/// Matches a selected calendar day; no selection includes all dates.
bool matchesTransactionDate(DateTime? date, DateTime? selectedDate) {
  if (selectedDate == null) return true;
  return date != null &&
      date.year == selectedDate.year &&
      date.month == selectedDate.month &&
      date.day == selectedDate.day;
}
