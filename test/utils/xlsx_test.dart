import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pillbbox/utils/xlsx.dart';

void main() {
  test('쓴 시트를 그대로 읽는다', () {
    final sheets = {
      '약': [
        ['이름', '번호'],
        ['A & <B>', 1900],
        ['빈칸 뒤', null, 0.25],
      ],
      '기록': [
        ['시각'],
      ],
    };

    final read = decodeXlsx(encodeXlsx(sheets));

    expect(read.keys, ['약', '기록']);
    expect(read['약'], [
      ['이름', '번호'],
      ['A & <B>', 1900],
      ['빈칸 뒤', null, 0.25],
    ]);
  });

  test('엑셀이 저장한 형식(공유 문자열, 서식 섞인 글자, 건너뛴 칸·행)도 읽는다', () {
    String xml(String body) => '<?xml version="1.0" encoding="UTF-8"?>$body';
    const main =
        'xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"';
    final archive = Archive()
      ..add(
        ArchiveFile.string(
          'xl/workbook.xml',
          xml(
            '<workbook $main xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
            '<sheets><sheet name="약" sheetId="1" r:id="rId3"/></sheets></workbook>',
          ),
        ),
      )
      ..add(
        ArchiveFile.string(
          'xl/_rels/workbook.xml.rels',
          xml(
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            '<Relationship Id="rId3" Target="/xl/worksheets/sheet1.xml" Type="x"/></Relationships>',
          ),
        ),
      )
      ..add(
        ArchiveFile.string(
          'xl/sharedStrings.xml',
          xml(
            '<sst $main><si><t>이름</t></si>'
            '<si><r><t>타이레놀</t></r><r><t>정</t></r><rPh><t>たい</t></rPh></si></sst>',
          ),
        ),
      )
      ..add(
        ArchiveFile.string(
          'xl/worksheets/sheet1.xml',
          xml(
            '<worksheet $main><sheetData>'
            '<row r="1"><c r="A1" t="s"><v>0</v></c></row>'
            '<row r="3"><c r="A3" t="s"><v>1</v></c><c r="C3"><v>2</v></c></row>'
            '</sheetData></worksheet>',
          ),
        ),
      );

    final read = decodeXlsx(ZipEncoder().encodeBytes(archive));

    expect(read['약'], [
      ['이름'],
      <Object?>[],
      ['타이레놀정', null, 2],
    ]);
  });

  test('xlsx가 아니면 FormatException', () {
    expect(
      () => decodeXlsx(Uint8List.fromList(utf8.encode('이름,번호'))),
      throwsFormatException,
    );
  });
}
