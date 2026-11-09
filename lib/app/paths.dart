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

  /// The welcome (1.1), full screen, shown once on a new journal.
  static const String welcome = '/welcome';

  /// The four tour pages (1.2–1.5). `extra`: a `TourMode`.
  static const String tour = '/tour';
}
