import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// 엑셀(.xlsx) 시트. 행마다 칸 값: 글자(String), 숫자(num), 빈칸(null).
typedef Sheet = List<List<Object?>>;

/// 시트들을 .xlsx로 만든다. 시트 이름 순서대로 탭이 생긴다.
///
/// `excel` 패키지는 `image`와 `archive` 버전이 맞지 않아, xlsx(XML 파일을 묶은 zip)를 직접 쓴다.
/// 글자는 칸 안에 넣고(inlineStr), 서식은 넣지 않는다.
Uint8List encodeXlsx(Map<String, Sheet> sheets) {
  final names = sheets.keys.toList();
  final archive = Archive()
    ..add(
      ArchiveFile.string('[Content_Types].xml', '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
${[for (var i = 1; i <= names.length; i++) '<Override PartName="/xl/worksheets/sheet$i.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'].join('\n')}
</Types>'''),
    )
    ..add(
      ArchiveFile.string('_rels/.rels', '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>'''),
    )
    ..add(
      ArchiveFile.string('xl/workbook.xml', '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
<sheets>
${[for (var i = 1; i <= names.length; i++) '<sheet name="${_escape(names[i - 1])}" sheetId="$i" r:id="rId$i"/>'].join('\n')}
</sheets>
</workbook>'''),
    )
    ..add(
      ArchiveFile.string('xl/_rels/workbook.xml.rels', '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
${[for (var i = 1; i <= names.length; i++) '<Relationship Id="rId$i" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet$i.xml"/>'].join('\n')}
</Relationships>'''),
    );
  for (var i = 1; i <= names.length; i++) {
    archive.add(
      ArchiveFile.string(
        'xl/worksheets/sheet$i.xml',
        _sheetXml(sheets[names[i - 1]]!),
      ),
    );
  }
  return ZipEncoder().encodeBytes(archive);
}

String _sheetXml(Sheet rows) {
  final out = StringBuffer(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
    '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>',
  );
  for (var r = 0; r < rows.length; r++) {
    out.write('<row r="${r + 1}">');
    for (var c = 0; c < rows[r].length; c++) {
      final ref = '${_column(c)}${r + 1}';
      switch (rows[r][c]) {
        case null:
          break;
        case final num n:
          out.write('<c r="$ref"><v>$n</v></c>');
        case final value:
          out.write(
            '<c r="$ref" t="inlineStr"><is><t xml:space="preserve">'
            '${_escape('$value')}</t></is></c>',
          );
      }
    }
    out.write('</row>');
  }
  out.write('</sheetData></worksheet>');
  return out.toString();
}

/// .xlsx의 시트들을 읽는다. 엑셀에서 고쳐 저장한 파일(공유 문자열, 빈칸 건너뛰기)도 읽는다.
/// 칸 값은 글자(String), 숫자(num), 빈칸(null)이고, 날짜·시각 서식 칸은 엑셀 일련번호(숫자)로 나온다.
///
/// xlsx가 아니면 [FormatException].
Map<String, Sheet> decodeXlsx(Uint8List bytes) {
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    throw const FormatException('엑셀(.xlsx) 파일이 아닙니다');
  }
  XmlDocument? read(String path) {
    final file = archive.findFile(path);
    return file == null
        ? null
        : XmlDocument.parse(utf8.decode(file.content, allowMalformed: true));
  }

  final workbook = read('xl/workbook.xml');
  final rels = read('xl/_rels/workbook.xml.rels');
  if (workbook == null || rels == null) {
    throw const FormatException('엑셀(.xlsx) 파일이 아닙니다');
  }
  final targets = {
    for (final r in rels.findAllElements('Relationship'))
      r.getAttribute('Id'): r.getAttribute('Target'),
  };
  final shared = [
    for (final si
        in read('xl/sharedStrings.xml')?.findAllElements('si') ??
            const <XmlElement>[])
      _text(si),
  ];

  final sheets = <String, Sheet>{};
  for (final sheet in workbook.findAllElements('sheet')) {
    final target = targets[sheet.getAttribute('r:id')];
    if (target == null) continue;
    // 대상은 xl/ 기준 상대 경로이거나 /xl/... 절대 경로다.
    final path = target.startsWith('/') ? target.substring(1) : 'xl/$target';
    final xml = read(path);
    if (xml == null) continue;
    final rows = <List<Object?>>[];
    for (final row in xml.findAllElements('row')) {
      final index =
          (int.tryParse(row.getAttribute('r') ?? '') ?? rows.length + 1) - 1;
      while (rows.length <= index) {
        rows.add([]);
      }
      final cells = rows[index];
      for (final c in row.findElements('c')) {
        final column = _columnIndex(c.getAttribute('r')) ?? cells.length;
        while (cells.length <= column) {
          cells.add(null);
        }
        cells[column] = _value(c, shared);
      }
    }
    sheets[sheet.getAttribute('name') ?? ''] = rows;
  }
  return sheets;
}

Object? _value(XmlElement c, List<String> shared) {
  final v = c.getElement('v')?.innerText;
  return switch (c.getAttribute('t')) {
    'inlineStr' => _text(c.getElement('is')!),
    's' => shared[int.parse(v!)],
    'str' || 'e' => v,
    'b' => v == '1' ? 'TRUE' : 'FALSE',
    _ => v == null || v.isEmpty ? null : num.tryParse(v) ?? v,
  };
}

/// 서식이 섞인 글자(`<r><t>…</t></r>`)도 이어 붙인다. 발음 표기(`<rPh>`)는 뺀다.
String _text(XmlElement e) => [
  for (final t in e.findAllElements('t'))
    if (t.parentElement?.name.local != 'rPh') t.innerText,
].join();

String _column(int index) {
  var n = index + 1;
  final letters = StringBuffer();
  while (n > 0) {
    final r = (n - 1) % 26;
    letters.write(String.fromCharCode(65 + r));
    n = (n - 1) ~/ 26;
  }
  return letters.toString().split('').reversed.join();
}

int? _columnIndex(String? ref) {
  if (ref == null) return null;
  var n = 0;
  for (final unit in ref.codeUnits) {
    if (unit < 65 || unit > 90) break;
    n = n * 26 + unit - 64;
  }
  return n == 0 ? null : n - 1;
}

String _escape(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
