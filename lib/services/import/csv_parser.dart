/// CSV 解析工具类
class CsvParser {
  /// 解析 CSV 文本为二维数组
  static List<List<String>> parse(String input) {
    // 规范化换行并移除 UTF-8 BOM
    var text = input.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    if (text.isNotEmpty && text.codeUnitAt(0) == 0xFEFF) {
      text = text.substring(1);
    }

    final lines = text
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList(growable: false);
    if (lines.isEmpty) return const [];

    // 1. 先尝试自动检测常规分隔符（逗号/制表符/分号/竖线）
    final delimiter = _detectDelimiter(lines);

    // 如果检测到的分隔符不是 Tab，则移除文本中的 Tab
    // （支付宝旧版CSV在字段中混入tab，会干扰解析）
    List<String> processedLines;
    if (delimiter != '\t') {
      processedLines = lines.map((l) => l.replaceAll('\t', '')).toList();
    } else {
      processedLines = lines;
    }

    List<List<String>> parsed;
    if (delimiter == 'space') {
      parsed = processedLines.map((l) => _splitSpaceSeparatedLine(l)).toList();
    } else {
      parsed =
          processedLines.map((l) => _splitDelimitedLine(l, delimiter)).toList();
    }

    // 2. 如果仍然全部只有 1 列（说明可能不是上述分隔符），且文本出现了连续双空格/制表符，再次尝试空白分隔
    final multiColumn = parsed.any((r) => r.length > 1);
    if (!multiColumn) {
      final hasMultiSpaces = RegExp(r' {2,}').hasMatch(text);
      final hasTab = text.contains('\t');
      if (hasTab) {
        final tabParsed =
            lines.map((l) => _splitDelimitedLine(l, '\t')).toList();
        if (tabParsed.any((r) => r.length > 1)) return tabParsed;
      }
      if (hasMultiSpaces) {
        final spaceParsed = lines.map(_splitSpaceSeparatedLine).toList();
        if (spaceParsed.any((r) => r.length > 1)) return spaceParsed;
      }
    }

    return parsed;
  }

  /// 自动检测分隔符（不进入引号内部）
  /// 优先级：逗号 > 制表符 > 分号 > 竖线；都没有再考虑空格
  static String _detectDelimiter(List<String> lines) {
    // 扩大到前50行，以覆盖支付宝CSV前面的描述行（表头在第25行左右）
    final maxLines = lines.length < 50 ? lines.length : 50;
    final counts = <String, int>{',': 0, '\t': 0, ';': 0, '|': 0};
    for (int i = 0; i < maxLines; i++) {
      final l = lines[i];
      bool inQuotes = false;
      for (int j = 0; j < l.length; j++) {
        final ch = l[j];
        if (ch == '"') {
          if (inQuotes && j + 1 < l.length && l[j + 1] == '"') {
            j++; // 跳过转义
            continue;
          }
          inQuotes = !inQuotes;
          continue;
        }
        if (!inQuotes) {
          if (counts.containsKey(ch)) counts[ch] = counts[ch]! + 1;
        }
      }
    }
    // 选择出现次数最多的分隔符（>0）
    String? best;
    int bestCount = 0;
    counts.forEach((k, v) {
      if (v > bestCount) {
        best = k;
        bestCount = v;
      }
    });
    if (best != null && bestCount > 0) return best!;
    // 检查是否存在连续多空格用于分隔
    final hasMultiSpaces =
        lines.take(maxLines).any((l) => RegExp(r' {2,}').hasMatch(l));
    if (hasMultiSpaces) return 'space';
    // 默认回退逗号（保持与以前行为兼容）
    return ',';
  }

  /// 拆分一行：适用于明确单字符分隔符（逗号/制表符/分号/竖线），支持双引号转义
  static List<String> _splitDelimitedLine(String line, String delimiter) {
    final out = <String>[];
    final buf = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
        continue;
      }
      if (!inQuotes && ch == delimiter) {
        out.add(_cleanCsvField(buf.toString()));
        buf.clear();
        continue;
      }
      buf.write(ch);
    }
    out.add(_cleanCsvField(buf.toString()));
    return out;
  }

  /// 空格（或多个空格）分隔的行拆分：忽略引号内空格；多个连续空格视为一个分隔
  static List<String> _splitSpaceSeparatedLine(String line) {
    final out = <String>[];
    final buf = StringBuffer();
    bool inQuotes = false;
    int spaceRun = 0;
    void pushBuf() {
      out.add(_cleanCsvField(buf.toString()));
      buf.clear();
    }

    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
        spaceRun = 0;
        continue;
      }
      if (!inQuotes && ch == ' ') {
        spaceRun++;
        if (spaceRun == 1) {
          // 先标记一次空格，等待看是否为分隔符（需要 >=1 且前面已有内容）
        }
        continue;
      }
      // 碰到非空格字符
      if (!inQuotes && spaceRun > 0) {
        // 之前累积的空格作为分隔符（忽略行首空格）
        if (buf.isNotEmpty) {
          pushBuf();
        }
        spaceRun = 0;
      }
      buf.write(ch);
    }
    // 行尾 push
    if (buf.isNotEmpty) {
      pushBuf();
    }
    return out;
  }

  /// 清理 CSV 字段：去除首尾空格和引号转义
  static String _cleanCsvField(String raw) {
    var s = raw.trim();
    if (s.length >= 2 && s.startsWith('"') && s.endsWith('"')) {
      s = s.substring(1, s.length - 1).replaceAll('""', '"').trim();
    }
    return s;
  }
}
