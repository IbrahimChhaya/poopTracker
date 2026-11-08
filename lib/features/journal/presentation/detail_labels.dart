import '../domain/entry.dart';

/// Wording for the optional details. Used only in the entry flow and entry
/// screens, and only when the matching setting is on.

/// Bristol stool form types: short name and description (screen 3.2).
const Map<int, ({String name, String description})> stoolForms = {
  1: (name: 'Separate hard lumps', description: 'Hard to pass'),
  2: (name: 'Lumpy, sausage-shaped', description: 'Firm and joined together'),
  3: (name: 'Cracked surface', description: 'Sausage-shaped with cracks'),
  4: (name: 'Smooth and soft', description: 'Sausage- or snake-shaped'),
  5: (name: 'Soft blobs', description: 'Clear-cut edges'),
  6: (name: 'Fluffy, mushy pieces', description: 'Ragged edges'),
  7: (name: 'Entirely liquid', description: 'Watery, no solid pieces'),
};

/// "Type 4 · Smooth and soft".
String stoolFormLabel(int type) => 'Type $type · ${stoolForms[type]!.name}';

/// Chip label on the context step.
String easeChip(Ease e) => switch (e) {
  Ease.easy => 'Easy',
  Ease.someStraining => 'Some straining',
  Ease.difficult => 'Difficult',
};

/// Phrase used in summaries, for example "Easy to pass".
String easePhrase(Ease e) => switch (e) {
  Ease.easy => 'Easy to pass',
  Ease.someStraining => 'Some straining',
  Ease.difficult => 'Difficult to pass',
};

String symptomLabel(Symptom s) => switch (s) {
  Symptom.none => 'None',
  Symptom.bloating => 'Bloating',
  Symptom.cramping => 'Cramping',
  Symptom.urgency => 'Urgency',
  Symptom.mucus => 'Mucus',
  Symptom.blood => 'Blood',
};

String tagLabel(Tag t) => switch (t) {
  Tag.afterMeal => 'After a meal',
  Tag.coffee => 'Coffee',
  Tag.stress => 'Stress',
  Tag.lowFluids => 'Low fluids',
  Tag.medication => 'Medication',
  Tag.exercise => 'Exercise',
};

/// Symptoms in a stable order, for display.
List<Symptom> sortedSymptoms(Set<Symptom> s) =>
    Symptom.values.where(s.contains).toList();

List<Tag> sortedTags(Set<Tag> t) => Tag.values.where(t.contains).toList();

/// "Bloating, Cramping", "No symptoms" for an explicit None, or null when
/// symptoms were not answered.
String? symptomSummary(Set<Symptom> s) {
  if (s.isEmpty) return null;
  if (s.contains(Symptom.none)) return 'No symptoms';
  return sortedSymptoms(s).map(symptomLabel).join(', ');
}
