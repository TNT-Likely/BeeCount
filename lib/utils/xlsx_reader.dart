import 'dart:typed_data';
import 'package:excel/excel.dart';

/// XLSX 文件读取工具
///
/// 将 Excel 文件转换为 CSV 格式字符串，便于后续使用现有的 CSV 解析逻辑
class XlsxReader {
  /// 读取 XLSX 文件字节并转换为 CSV 格式字符串
  ///
  /// 参数:
  /// - [bytes]: XLSX 文件的字节数据
  ///
  /// 返回:
  /// - CSV 格式的字符串，每行用 \n 分隔，字段用逗号分隔
  static String convertXlsxToCSV(Uint8List bytes) {
    try {
      // 解码 Excel 文件
      final excel = Excel.decodeBytes(bytes);

      // 获取第一个工作表（通常账单数据在第一个表）
      if (excel.tables.isEmpty) {
        throw Exception('Excel 文件为空或无法读取');
      }

      final sheetName = excel.tables.keys.first;
      final sheet = excel.tables[sheetName];

      if (sheet == null || sheet.rows.isEmpty) {
        throw Exception('工作表为空');
      }

      // 转换为 CSV 格式
      final csvLines = <String>[];

      for (final row in sheet.rows) {
        final fields = row.map((cell) {
          // 获取单元格值
          final value = cell?.value;

          if (value == null) {
            return '';
          }

          // 转换为字符串
          String text;
          if (value is SharedString) {
            text = value.toString();
          } else if (value is TextCellValue) {
            text = value.value.toString();
          } else if (value is IntCellValue) {
            text = value.value.toString();
          } else if (value is DoubleCellValue) {
            text = value.value.toString();
          } else if (value is BoolCellValue) {
            text = value.value.toString();
          } else if (value is DateCellValue) {
            // 日期格式化为 YYYY-MM-DD
            final date = value.asDateTimeLocal();
            text =
                '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          } else if (value is TimeCellValue) {
            // TimeCellValue 直接转字符串
            text = value.toString();
          } else if (value is DateTimeCellValue) {
            final dt = value.asDateTimeLocal();
            text =
                '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
          } else {
            text = value.toString();
          }

          // CSV 转义：如果包含逗号、双引号、换行符，需要用双引号包裹
          if (text.contains(',') ||
              text.contains('"') ||
              text.contains('\n') ||
              text.contains('\r')) {
            // 双引号需要转义为两个双引号
            text = text.replaceAll('"', '""');
            return '"$text"';
          }

          return text;
        }).toList();

        csvLines.add(fields.join(','));
      }

      return csvLines.join('\n');
    } catch (e) {
      throw Exception('解析 Excel 文件失败: $e');
    }
  }
}
