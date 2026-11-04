import 'dart:typed_data';

import '../../utils/time_format.dart';
import '../../utils/xlsx.dart';
import '../models/appearance.dart';
import '../models/intake_record.dart';
import 'intake_repository.dart';
import 'medication_repository.dart';

/// 가져오기 결과. 이미 있던 약·기록은 세지 않는다.
typedef ImportSummary = ({int medications, int records, int skippedRows});

/// 약, 복용 기록, 색·모양을 엑셀(.xlsx)로 내보내고 가져온다. 웹은 기록이 브라우저에만 있어 백업에 쓴다.
///
/// 사진은 넣지 않는다. 가져오기는 지금 데이터에 합친다: 약은 약 번호나 이름이 같으면 같은 약으로 보고
/// 그대로 두며, 기록은 같은 약·시각·개수면 건너뛴다.
class BackupRepository {
  BackupRepository(this._medications, this._intakes);

  final MedicationRepository _medications;
  final IntakeRepository _intakes;

  static const medicationSheet = '약';
  static const recordSheet = '기록';
  static const appearanceSheet = '색·모양';
  static const _medicationHeader = ['이름', '약 번호', '1회 개수', '복용 시간'];
  static const _recordHeader = ['시각', '약', '개수', '방법'];
  static const _appearanceHeader = ['약', 'L', 'a', 'b', '길쭉함'];
  static const _sources = {
    IntakeSource.camera: '사진',
    IntakeSource.manual: '직접',
  };

  Future<Uint8List> exportExcel() async {
    final medications = await _medications.getAll();
    final names = {for (final m in medications) m.id: m.name};
    return encodeXlsx({
      medicationSheet: [
        _medicationHeader,
        for (final m in medications)
          [
            m.name,
            m.categoryId,
            m.dosePerTake,
            m.times.map(formatMinuteOfDay).join(', '),
          ],
      ],
      recordSheet: [
        _recordHeader,
        for (final r in await _intakes.allRecords())
          [
            _formatDateTime(r.takenAt),
            names[r.medicationId],
            r.count,
            _sources[r.source],
          ],
      ],
      appearanceSheet: [
        _appearanceHeader,
        for (final (id, a) in await _medications.appearances())
          [names[id], a.l, a.a, a.b, a.elongation],
      ],
    });
  }

  /// [bytes]의 약·기록·색·모양을 지금 데이터에 합친다. 읽을 수 없는 행은 건너뛰고 [ImportSummary.skippedRows]에 센다.
  ///
  /// 이 앱이 내보낸 형식이 아니면 [FormatException].
  Future<ImportSummary> importExcel(Uint8List bytes) async {
    final sheets = decodeXlsx(bytes);
    final medicationRows = _rows(sheets, medicationSheet, _medicationHeader);
    final recordRows = _rows(sheets, recordSheet, _recordHeader);
    final appearanceRows = sheets.containsKey(appearanceSheet)
        ? _rows(sheets, appearanceSheet, _appearanceHeader)
        : const <List<Object?>>[];
    var skipped = 0;

    final existing = await _medications.getAll();
    final byName = {for (final m in existing) m.name: m.id};
    final byCategory = {
      for (final m in existing)
        if (m.categoryId != null) m.categoryId!: m.id,
    };
    var addedMedications = 0;
    for (final row in medicationRows) {
      final name = _string(row, 0);
      final categoryId = _int(row, 1);
      final dose = _int(row, 2) ?? 1;
      final times = _times(_cell(row, 3));
      if (name == null || dose <= 0 || times == null) {
        skipped++;
        continue;
      }
      final id = byCategory[categoryId] ?? byName[name];
      if (id != null) {
        byName[name] = id;
        continue;
      }
      final newId = await _medications.save(
        categoryId: categoryId,
        name: name,
        dosePerTake: dose,
        times: times,
      );
      byName[name] = newId;
      if (categoryId != null) byCategory[categoryId] = newId;
      addedMedications++;
    }

    final records =
        <
          ({int medicationId, DateTime takenAt, int count, IntakeSource source})
        >[];
    for (final row in recordRows) {
      final takenAt = _dateTime(_cell(row, 0));
      final id = byName[_string(row, 1)];
      final count = _int(row, 2);
      if (takenAt == null || id == null || count == null || count <= 0) {
        skipped++;
        continue;
      }
      final source = _string(row, 3) == _sources[IntakeSource.manual]
          ? IntakeSource.manual
          : IntakeSource.camera;
      records.add((
        medicationId: id,
        takenAt: takenAt,
        count: count,
        source: source,
      ));
    }
    final addedRecords = await _intakes.importRecords(records);

    final known = {
      for (final (id, a) in await _medications.appearances())
        (id, a.l, a.a, a.b, a.elongation),
    };
    for (final row in appearanceRows) {
      final id = byName[_string(row, 0)];
      final values = [for (var c = 1; c <= 4; c++) _double(row, c)];
      if (id == null || values.contains(null) || values[3]! <= 0) {
        skipped++;
        continue;
      }
      final [l, a, b, elongation] = values.cast<double>();
      if (!known.add((id, l, a, b, elongation))) continue;
      await _medications.addAppearance(
        id,
        Appearance(l: l, a: a, b: b, elongation: elongation),
      );
    }

    return (
      medications: addedMedications,
      records: addedRecords,
      skippedRows: skipped,
    );
  }

  /// [name] 시트의 머리글 아래 행들. 비어 있는 행은 뺀다.
  static List<List<Object?>> _rows(
    Map<String, Sheet> sheets,
    String name,
    List<String> header,
  ) {
    final rows = sheets[name];
    if (rows == null ||
        rows.isEmpty ||
        [
              for (var c = 0; c < header.length; c++) _string(rows.first, c),
            ].join('|') !=
            header.join('|')) {
      throw FormatException("'$name' 시트가 없거나 머리글이 다릅니다. 이 앱에서 내보낸 파일을 써 주세요.");
    }
    return [
      for (final row in rows.skip(1))
        if (row.any((v) => v != null && '$v'.trim().isNotEmpty)) row,
    ];
  }

  static Object? _cell(List<Object?> row, int column) =>
      column < row.length ? row[column] : null;

  static String? _string(List<Object?> row, int column) {
    final value = _cell(row, column);
    final text = value is num && value == value.roundToDouble()
        ? '${value.toInt()}'
        : value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static int? _int(List<Object?> row, int column) =>
      switch (_cell(row, column)) {
        final num n when n == n.roundToDouble() => n.toInt(),
        final String s => int.tryParse(s.trim()),
        _ => null,
      };

  static double? _double(List<Object?> row, int column) =>
      switch (_cell(row, column)) {
        final num n => n.toDouble(),
        final String s => double.tryParse(s.trim()),
        _ => null,
      };

  /// "08:00, 20:00"을 분으로. 엑셀이 시각 하나를 시각 서식(하루의 비율)으로 바꿨으면 그것도 읽는다.
  /// 빈칸은 복용 시간 없음, 읽을 수 없으면 null.
  static List<int>? _times(Object? value) {
    if (value == null) return const [];
    if (value is num) {
      final minute = (value * 24 * 60).round();
      return minute >= 0 && minute < 24 * 60 ? [minute] : null;
    }
    final parts = '$value'
        .split(RegExp('[,;/\\s]+'))
        .where((p) => p.isNotEmpty);
    final times = <int>[];
    for (final part in parts) {
      final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(part);
      if (match == null) return null;
      final hour = int.parse(match[1]!), minute = int.parse(match[2]!);
      if (hour > 23 || minute > 59) return null;
      times.add(hour * 60 + minute);
    }
    return times..sort();
  }

  /// "2026-10-30 08:10:23" 또는 엑셀 날짜 일련번호(1899-12-30부터 센 날, 소수는 하루의 비율).
  static DateTime? _dateTime(Object? value) => switch (value) {
    final num serial when serial > 0 => DateTime(
      1899,
      12,
      30 + serial.floor(),
      0,
      0,
      0,
      ((serial - serial.floor()) * Duration.millisecondsPerDay).round(),
    ),
    final String s => DateTime.tryParse(s.trim()),
    _ => null,
  };

  static String _formatDateTime(DateTime t) =>
      '${dateKey(t)} ${formatTime(t)}:${t.second.toString().padLeft(2, '0')}';
}
