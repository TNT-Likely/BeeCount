import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beecount/widgets/biz/app_empty.dart';

void main() {
  group('AppEmpty Widget Tests', () {
    testWidgets('should display default text when no parameters provided', (tester) async {
      // Arrange & Act
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppEmpty(),
          ),
        ),
      );

      // Assert
      expect(find.text('暂无数据'), findsOneWidget);
    });

    testWidgets('should display custom text when provided', (tester) async {
      // Arrange
      const customText = '没有找到任何记录';
      
      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppEmpty(text: customText),
          ),
        ),
      );

      // Assert
      expect(find.text(customText), findsOneWidget);
      expect(find.text('暂无数据'), findsNothing);
    });

    testWidgets('should display both text and subtext when both provided', (tester) async {
      // Arrange
      const mainText = '没有数据';
      const subText = '请先添加一些记录';
      
      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppEmpty(
              text: mainText,
              subtext: subText,
            ),
          ),
        ),
      );

      // Assert
      expect(find.text(mainText), findsOneWidget);
      expect(find.text(subText), findsOneWidget);
    });

    testWidgets('should not display subtext when only main text provided', (tester) async {
      // Arrange
      const mainText = '空的状态';
      
      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppEmpty(text: mainText),
          ),
        ),
      );

      // Assert
      expect(find.text(mainText), findsOneWidget);
      // Subtext should not be present in the widget tree when null
      expect(find.byType(Text), findsNWidgets(1)); // Only main text should be found
    });

    testWidgets('should have proper widget structure', (tester) async {
      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppEmpty(),
          ),
        ),
      );

      // Assert - verify the widget contains expected structure
      expect(find.byType(AppEmpty), findsOneWidget);
    });
  });
}