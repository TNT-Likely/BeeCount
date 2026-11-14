import 'dart:convert';
import 'dart:typed_data';
import 'package:beecount/services/import/csv_parser.dart';
import 'package:beecount/services/import/file_reader.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gbk_codec/gbk_codec.dart';

void main() {
  const text = '日期,类型,金额\n2026-10-20,支出,12.5';
  test('真实文件读取服务支持UTF8与BOM', () {
    expect(FileReaderService.decodeBytes(utf8.encode(text)), text);
    expect(
        FileReaderService.decodeBytes([0xef, 0xbb, 0xbf, ...utf8.encode(text)]),
        text);
  });
  test('真实文件读取服务支持UTF16LE和BE的BOM', () {
    final le = <int>[0xff, 0xfe], be = <int>[0xfe, 0xff];
    for (final unit in text.codeUnits) {
      le.addAll([unit & 255, unit >> 8]);
      be.addAll([unit >> 8, unit & 255]);
    }
    expect(FileReaderService.decodeBytes(le), text);
    expect(FileReaderService.decodeBytes(be), text);
  });
  test('真实文件读取服务保留支付宝GBK编码', () {
    expect(FileReaderService.decodeBytes(gbk.encode(text)), text);
  });
  test('无路径内存字节读取与空文件返回沿用原服务', () async {
    final bytes = Uint8List.fromList(utf8.encode(text));
    expect(
        await FileReaderService.readFile(
            PlatformFile(name: 'qa.csv', size: bytes.length, bytes: bytes)),
        text);
    expect(
        await FileReaderService.readFile(
            PlatformFile(name: 'empty.csv', size: 0, bytes: Uint8List(0))),
        '');
  });
  test('XLSX字节逐字传入原转换回调', () async {
    final bytes = Uint8List.fromList([0x50, 0x4b, 3, 4]);
    List<int>? received;
    final result = await FileReaderService.readFile(
        PlatformFile(name: 'qa.XLSX', size: bytes.length, bytes: bytes),
        xlsxConverter: (input) {
      received = input;
      return text;
    });
    expect(received, orderedEquals(bytes));
    expect(result, text);
  });
  test('XLSX缺转换器仍抛原错误', () async {
    expect(
        () => FileReaderService.readFile(PlatformFile(
            name: 'qa.xlsx', size: 1, bytes: Uint8List.fromList([1]))),
        throwsArgumentError);
  });
  test('原CSV解析器保留标签附件逗号与双引号转义', () {
    final rows = CsvParser.parse(
        '日期,备注,标签,附件\n2026-10-20,"午餐,""咖啡""","工作,日常","a.jpg,b.png"');
    expect(rows.length, 2);
    expect(rows[1], ['2026-10-20', '午餐,"咖啡"', '工作,日常', 'a.jpg,b.png']);
  });
  test('原解析器识别TSV并保留空字段', () {
    final rows = CsvParser.parse('日期\t类型\t金额\t备注\n2026-10-20\t支出\t12.5\t');
    expect(rows[1], ['2026-10-20', '支出', '12.5', '']);
  });
}
