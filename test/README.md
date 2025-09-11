# BeeCount Testing Framework

This directory contains the test suite for BeeCount, organized by test type.

## Test Structure

```
test/
├── unit/           # Unit tests for individual classes and functions
├── widget/         # Widget tests for UI components  
├── integration/    # Integration tests for complete workflows
└── README.md       # This file
```

## Test Categories

### Unit Tests (`test/unit/`)
- Test individual classes, functions, and business logic
- Fast execution, isolated dependencies
- Example: `BeeRepository` database operations, utility functions

### Widget Tests (`test/widget/`)
- Test individual widgets in isolation
- Verify UI behavior, user interactions, and widget state
- Example: `AppEmpty`, custom buttons, form components

### Integration Tests (`test/integration/`)
- Test complete user workflows and app functionality
- Slower execution, tests real app behavior
- Example: Full transaction creation flow, data synchronization

## Running Tests

### All Tests
```bash
flutter test
```

### Specific Test Categories
```bash
# Unit tests only
flutter test test/unit/

# Widget tests only  
flutter test test/widget/

# Integration tests only
flutter test test/integration/
```

### Specific Test File
```bash
flutter test test/unit/bee_repository_test.dart
```

### With Coverage
```bash
flutter test --coverage
```

## Test Guidelines

### Writing Unit Tests
- Focus on testing public APIs and business logic
- Mock external dependencies (database, network, etc.)
- Test both happy path and error scenarios
- Keep tests fast and isolated

### Writing Widget Tests
- Test user-visible behavior, not implementation details
- Use `testWidgets()` for widget testing
- Verify text, buttons, inputs, and user interactions
- Test different widget states (loading, error, success)

### Writing Integration Tests
- Test complete user workflows end-to-end
- Use real or test databases when needed
- Focus on critical user journeys
- May be slower but provide high confidence

## Current Test Coverage

- ✅ Basic unit tests for `BeeRepository`
- ✅ Widget tests for `AppEmpty` component
- 🔄 Additional tests to be added for core business logic
- 🔄 Integration tests for transaction flows
- 🔄 CI/CD integration for automated testing

## Dependencies

- `flutter_test`: Core Flutter testing framework
- `mocktail`: Mocking library for isolating dependencies  
- `integration_test`: Flutter integration testing package

## Future Improvements

1. Add comprehensive unit tests for all repository methods
2. Add widget tests for complex components (forms, charts)
3. Add integration tests for critical user workflows
4. Set up automated test reporting and coverage tracking
5. Add performance tests for data-heavy operations