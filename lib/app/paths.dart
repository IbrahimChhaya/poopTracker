/// Route paths. Paths never contain journal content or entry ids; an entry
/// to show or edit is passed as in-memory route data (`extra`).
abstract final class AppPaths {
  static const String journal = '/journal';
  static const String history = '/history';
  static const String trends = '/trends';
  static const String settings = '/settings';

  /// Entry detail inside the Journal or History tab. `extra`: the entry id.
  static const String journalEntry = '/journal/entry';
  static const String historyEntry = '/history/entry';

  /// Full-screen editor. `extra`: for new, an optional default date
  /// (`LocalDate`); for edit, the entry id.
  static const String newEntry = '/entry/new';
  static const String editEntry = '/entry/edit';
}
