// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vocabulary_word.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class VocabularyWordAdapter extends TypeAdapter<VocabularyWord> {
  @override
  final int typeId = 1;

  @override
  VocabularyWord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return VocabularyWord(
      id: fields[0] as String,
      english: fields[1] as String,
      khmer: fields[2] as String,
      sourceLang: fields[3] as String,
      learned: fields[4] as bool,
      createdAt: fields[5] as DateTime,
      learnedAt: fields[6] as DateTime?,
      explanationKm: fields[7] as String?,
      exampleEn: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, VocabularyWord obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.english)
      ..writeByte(2)
      ..write(obj.khmer)
      ..writeByte(3)
      ..write(obj.sourceLang)
      ..writeByte(4)
      ..write(obj.learned)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.learnedAt)
      ..writeByte(7)
      ..write(obj.explanationKm)
      ..writeByte(8)
      ..write(obj.exampleEn);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VocabularyWordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
