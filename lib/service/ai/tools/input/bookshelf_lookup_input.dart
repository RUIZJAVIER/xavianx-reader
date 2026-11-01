import 'package:freezed_annotation/freezed_annotation.dart';

part 'bookshelf_lookup_input.freezed.dart';
part 'bookshelf_lookup_input.g.dart';

@freezed
abstract class BookshelfLookupInput with _$BookshelfLookupInput {
  const factory BookshelfLookupInput({
    String? query,
    int? groupId,
    @Default(false) bool includeDeleted,
    int? limit,
    @Default(0) int offset,
  }) = _BookshelfLookupInput;
  const BookshelfLookupInput._();

  factory BookshelfLookupInput.fromJson(Map<String, dynamic> json) =>
      _$BookshelfLookupInputFromJson(json);

  int resolvedLimit([int fallback = 100]) {
    final value = limit ?? fallback;
    return value.clamp(1, 100);
  }

  int resolvedOffset() => offset < 0 ? 0 : offset;
}
