/// Route paths. Paths never contain journal content or entry ids; the entry
/// to show is passed as in-memory route data (`extra`).
abstract final class AppPaths {
  static const String journal = '/journal';
  static const String history = '/history';
  static const String trends = '/trends';
  static const String settings = '/settings';

  /// The entry page, full screen above the tabs, for viewing and changing
  /// one entry. `extra`: an `EntryRoute` (the entry id, and whether it was
  /// just added).
  static const String entry = '/entry';
}
