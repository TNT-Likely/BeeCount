import '../../../data/db.dart';
import '../../../data/repositories/base_repository.dart';

class DuplicateTagName implements Exception {}

/// Keep writes and original name uniqueness rules out of the UI packages.
Future<Tag> saveTagDraft(BaseRepository repository,
    {required String name, required String color, Tag? existing}) async {
  final trimmed = name.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError.value(name, 'name');
  }
  if (await repository.isTagNameDuplicate(
      name: trimmed, excludeId: existing?.id)) {
    throw DuplicateTagName();
  }
  final int id;
  if (existing == null) {
    id = await repository.createTag(name: trimmed, color: color);
  } else {
    id = existing.id;
    await repository.updateTag(id, name: trimmed, color: color);
  }
  final saved = await repository.getTagById(id);
  if (saved == null) throw StateError('Saved tag is unavailable');
  return saved;
}
