## Test Setup Documentation

### Google Fonts in Tests

Google Fonts requires network access and file system caching, which doesn't work well in test environments. 

**Current Issue:**
Tests fail with "Failed to load font" errors when using `google_fonts` package.

**Solution:**
The `google_fonts` package attempts to download and cache fonts during tests. Since this requires network access and file system operations that aren't available in test environments, tests fail.

**Recommended Approaches:**

### Option 1: Use MaterialApp with debugUseMemoryFileSystem (Recommended)
```dart
testWidgets('my widget test', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      // Use default system fonts in tests
      theme: ThemeData(
        textTheme: const TextTheme(), // Default text theme
      ),
      home: MyWidget(),
    ),
  );
});
```

### Option 2: Mock the entire Google Fonts package
This requires creating mocks for the package methods, which is complex.

### Option 3: Skip widget tests that use Google Fonts
For now, focus on:
- Unit tests (services, models, utils)
- Integration tests (don't require font rendering)

### Option 4: Use test-specific widgets
Create test variants of widgets that don't use Google Fonts.

### Current Status
- **Unit tests work**: Services and models don't use fonts
- **Widget tests fail**: Due to Google Fonts loading
- **Solution in progress**: Investigating best mocking approach

### Workaround for Now
The tests are commented to show the expected behavior but won't pass until we either:
1. Mock Google Fonts properly (complex)
2. Create test-specific widget variants (recommended)
3. Use integration tests instead of widget tests (alternative)
