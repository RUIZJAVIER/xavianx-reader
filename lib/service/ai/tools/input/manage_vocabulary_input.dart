import 'package:freezed_annotation/freezed_annotation.dart';

part 'manage_vocabulary_input.freezed.dart';
part 'manage_vocabulary_input.g.dart';

@freezed
abstract class ManageVocabularyInput with _$ManageVocabularyInput {
  const factory ManageVocabularyInput({
    @Default('list') String action,
    int? id,
    String? island,
    @Default(20) int limit,
    String? associationMnemonic,
    String? languageIsland,
  }) = _ManageVocabularyInput;
  const ManageVocabularyInput._();

  factory ManageVocabularyInput.fromJson(Map<String, dynamic> json) =>
      _$ManageVocabularyInputFromJson(json);

  bool get isUpdate => action.toLowerCase() == 'update';

  int resolvedLimit() => limit.clamp(1, 100);
}
