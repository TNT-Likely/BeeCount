import 'dart:io';
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:yaml/yaml.dart';

import '../data/db.dart';
import '../data/repositories/base_repository.dart';
import 'system/logger_service.dart';

/// 分类包服务
/// 负责分类配置和自定义图标的打包导入导出
class CategoryPackageService {
  static const String _tag = 'CategoryPackage';
  static const int _version = 1;

  /// 导出分类包
  /// 返回 zip 文件路径
  static Future<String> exportPackage({
    required BaseRepository repository,
    required String outputPath,
    String? filterKind, // 可选：只导出指定类型 'expense' 或 'income'
  }) async {
    logger.info(_tag, '开始导出分类包, filterKind=$filterKind');

    final archive = Archive();

    // 1. 获取所有分类
    final allCategories = await repository.getAllCategories();
    List<Category> categories = allCategories;

    // 按类型过滤
    if (filterKind != null) {
      categories = allCategories.where((c) => c.kind == filterKind).toList();
    }

    // 2. 构建分类配置
    final categoryItems = <Map<String, dynamic>>[];
    final customIconFiles = <String>[]; // 需要打包的自定义图标文件名

    // 构建分类 ID 到名称的映射（用于获取父分类名称）
    final categoryMap = {for (var c in allCategories) c.id: c};

    for (final category in categories) {
      String? parentName;
      if (category.parentId != null && categoryMap.containsKey(category.parentId)) {
        parentName = categoryMap[category.parentId]!.name;
      }

      final item = <String, dynamic>{
        'name': category.name,
        'kind': category.kind,
        'icon': category.icon,
        'sort_order': category.sortOrder,
        'level': category.level,
        'icon_type': category.iconType,
      };

      if (parentName != null) {
        item['parent_name'] = parentName;
      }

      if (category.customIconPath != null && category.customIconPath!.isNotEmpty) {
        item['custom_icon_path'] = category.customIconPath;
        // 提取文件名
        final fileName = path.basename(category.customIconPath!);
        if (!customIconFiles.contains(fileName)) {
          customIconFiles.add(fileName);
        }
      }

      if (category.communityIconId != null && category.communityIconId!.isNotEmpty) {
        item['community_icon_id'] = category.communityIconId;
      }

      categoryItems.add(item);
    }

    // 3. 生成 YAML 配置
    final config = {
      'version': _version,
      'exported_at': DateTime.now().toIso8601String(),
      'categories': categoryItems,
    };

    final yamlContent = _toYaml(config);
    final yamlBytes = utf8.encode(yamlContent);
    archive.addFile(ArchiveFile('categories.yaml', yamlBytes.length, yamlBytes));

    logger.info(_tag, '已添加配置文件: ${categories.length} 个分类');

    // 4. 添加自定义图标文件
    if (customIconFiles.isNotEmpty) {
      final appDir = await getApplicationDocumentsDirectory();
      final iconDir = Directory('${appDir.path}/custom_icons');

      for (final fileName in customIconFiles) {
        final file = File('${iconDir.path}/$fileName');
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          archive.addFile(ArchiveFile('custom_icons/$fileName', bytes.length, bytes));
          logger.debug(_tag, '已添加图标: $fileName');
        } else {
          logger.warning(_tag, '图标文件不存在: $fileName');
        }
      }

      logger.info(_tag, '已添加 ${customIconFiles.length} 个自定义图标');
    }

    // 5. 压缩并保存
    final zipData = ZipEncoder().encode(archive);
    if (zipData == null) {
      throw Exception('压缩失败');
    }

    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(zipData);

    logger.info(_tag, '分类包已导出: $outputPath');
    return outputPath;
  }

  /// 导入分类包
  /// [mode]: 'merge' 合并（保留现有）, 'replace' 替换（清除未使用的）
  static Future<CategoryImportResult> importPackage({
    required String filePath,
    required BaseRepository repository,
    required String mode,
  }) async {
    logger.info(_tag, '开始导入分类包: $filePath, mode=$mode');

    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('文件不存在');
    }

    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    // 1. 读取配置文件
    final configFile = archive.findFile('categories.yaml');
    if (configFile == null) {
      throw Exception('无效的分类包：缺少 categories.yaml');
    }

    final yamlContent = utf8.decode(configFile.content as List<int>);
    final config = loadYaml(yamlContent);

    if (config is! Map) {
      throw Exception('无效的配置文件格式');
    }

    final version = config['version'] as int? ?? 1;
    logger.debug(_tag, '配置版本: $version');

    final categoriesData = config['categories'] as List?;
    if (categoriesData == null || categoriesData.isEmpty) {
      return CategoryImportResult(imported: 0, skipped: 0, iconsImported: 0);
    }

    // 2. 解压自定义图标到临时目录
    final tempDir = await getTemporaryDirectory();
    final extractDir = Directory('${tempDir.path}/category_import_${DateTime.now().millisecondsSinceEpoch}');
    await extractDir.create(recursive: true);

    final iconMapping = <String, String>{}; // 旧路径 -> 新路径

    for (final entry in archive) {
      if (entry.name.startsWith('custom_icons/') && !entry.isFile) continue;
      if (entry.name.startsWith('custom_icons/') && entry.isFile) {
        final fileName = path.basename(entry.name);
        final extractPath = '${extractDir.path}/$fileName';
        final extractFile = File(extractPath);
        await extractFile.writeAsBytes(entry.content as List<int>);
        iconMapping[entry.name] = extractPath;
      }
    }

    logger.info(_tag, '已解压 ${iconMapping.length} 个图标到临时目录');

    // 3. 获取现有分类
    final existingCategories = await repository.getAllCategories();
    // 按 (name, kind) 判重,允许跨 kind 同名(收入「红包」+ 支出「红包」)
    final existingKeys = existingCategories
        .map((c) => '${c.name.toLowerCase()}|${c.kind}')
        .toSet();

    // 4. 处理图标文件：复制到正式目录
    final appDir = await getApplicationDocumentsDirectory();
    final iconDir = Directory('${appDir.path}/custom_icons');
    if (!await iconDir.exists()) {
      await iconDir.create(recursive: true);
    }

    final newIconMapping = <String, String>{}; // 原路径 -> 新路径
    int iconsImported = 0;

    for (final entry in iconMapping.entries) {
      final oldPath = entry.key; // custom_icons/xxx.png
      final tempPath = entry.value;
      final oldFileName = path.basename(oldPath);

      // 生成新文件名（避免冲突）
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ext = path.extension(oldFileName);
      final newFileName = 'imported_${timestamp}_$iconsImported$ext';
      final newPath = '${iconDir.path}/$newFileName';

      await File(tempPath).copy(newPath);
      newIconMapping[oldPath] = 'custom_icons/$newFileName';
      iconsImported++;
    }

    logger.info(_tag, '已导入 $iconsImported 个图标');

    // 5. 导入分类
    int imported = 0;
    int skipped = 0;

    // 分离一级和二级分类
    final level1Items = <Map<String, dynamic>>[];
    final level2Items = <Map<String, dynamic>>[];

    for (final item in categoriesData) {
      final map = Map<String, dynamic>.from(item as Map);
      final level = map['level'] as int? ?? 1;
      if (level == 1 || map['parent_name'] == null) {
        level1Items.add(map);
      } else {
        level2Items.add(map);
      }
    }

    // 导入一级分类
    for (final item in level1Items) {
      final name = item['name'] as String;
      final kind = item['kind'] as String? ?? 'expense';
      if (existingKeys.contains('${name.toLowerCase()}|$kind')) {
        skipped++;
        continue;
      }

      String? customIconPath = item['custom_icon_path'] as String?;
      if (customIconPath != null && newIconMapping.containsKey(customIconPath)) {
        customIconPath = newIconMapping[customIconPath];
      }

      await repository.insertCategory(CategoriesCompanion.insert(
        name: name,
        kind: kind,
        icon: Value(item['icon'] as String?),
        sortOrder: Value(item['sort_order'] as int? ?? 0),
        parentId: const Value(null),
        level: const Value(1),
        iconType: Value(item['icon_type'] as String? ?? 'material'),
        customIconPath: Value(customIconPath),
        communityIconId: Value(item['community_icon_id'] as String?),
      ));
      imported++;
      existingKeys.add('${name.toLowerCase()}|$kind');
    }

    // 重新获取分类列表（包含刚导入的）
    final updatedCategories = await repository.getAllCategories();
    final keyToId = {
      for (var c in updatedCategories) '${c.name.toLowerCase()}|${c.kind}': c.id
    };

    // 导入二级分类
    for (final item in level2Items) {
      final name = item['name'] as String;
      final kind = item['kind'] as String? ?? 'expense';
      if (existingKeys.contains('${name.toLowerCase()}|$kind')) {
        skipped++;
        continue;
      }

      // 父分类与子分类同 kind,按 (parentName, kind) 查父 id
      final parentName = item['parent_name'] as String?;
      final parentId =
          parentName != null ? keyToId['${parentName.toLowerCase()}|$kind'] : null;

      if (parentId == null) {
        logger.warning(_tag, '找不到父分类: $parentName, 跳过 $name');
        skipped++;
        continue;
      }

      String? customIconPath = item['custom_icon_path'] as String?;
      if (customIconPath != null && newIconMapping.containsKey(customIconPath)) {
        customIconPath = newIconMapping[customIconPath];
      }

      await repository.insertCategory(CategoriesCompanion.insert(
        name: name,
        kind: kind,
        icon: Value(item['icon'] as String?),
        sortOrder: Value(item['sort_order'] as int? ?? 0),
        parentId: Value(parentId),
        level: const Value(2),
        iconType: Value(item['icon_type'] as String? ?? 'material'),
        customIconPath: Value(customIconPath),
        communityIconId: Value(item['community_icon_id'] as String?),
      ));
      imported++;
      existingKeys.add('${name.toLowerCase()}|$kind');
    }

    // 6. 清理临时目录
    try {
      await extractDir.delete(recursive: true);
    } catch (e) {
      logger.warning(_tag, '清理临时目录失败: $e');
    }

    logger.info(_tag, '导入完成: imported=$imported, skipped=$skipped, icons=$iconsImported');

    return CategoryImportResult(
      imported: imported,
      skipped: skipped,
      iconsImported: iconsImported,
    );
  }

  /// 将 Map 转换为 YAML 字符串
  static String _toYaml(Map<String, dynamic> data) {
    final buffer = StringBuffer();
    buffer.writeln('# BeeCount 分类包');
    buffer.writeln('# 导出时间: ${data['exported_at']}');
    buffer.writeln();
    buffer.writeln('version: ${data['version']}');
    buffer.writeln('exported_at: "${data['exported_at']}"');
    buffer.writeln();
    buffer.writeln('categories:');

    final categories = data['categories'] as List<Map<String, dynamic>>;
    for (final cat in categories) {
      buffer.writeln('  - name: "${cat['name']}"');
      buffer.writeln('    kind: "${cat['kind']}"');
      if (cat['icon'] != null) {
        buffer.writeln('    icon: "${cat['icon']}"');
      }
      buffer.writeln('    sort_order: ${cat['sort_order']}');
      buffer.writeln('    level: ${cat['level']}');
      buffer.writeln('    icon_type: "${cat['icon_type']}"');
      if (cat['parent_name'] != null) {
        buffer.writeln('    parent_name: "${cat['parent_name']}"');
      }
      if (cat['custom_icon_path'] != null) {
        buffer.writeln('    custom_icon_path: "${cat['custom_icon_path']}"');
      }
      if (cat['community_icon_id'] != null) {
        buffer.writeln('    community_icon_id: "${cat['community_icon_id']}"');
      }
    }

    return buffer.toString();
  }
}

/// 分类导入结果
class CategoryImportResult {
  final int imported;
  final int skipped;
  final int iconsImported;

  CategoryImportResult({
    required this.imported,
    required this.skipped,
    required this.iconsImported,
  });
}
