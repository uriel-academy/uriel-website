# Firebase Analytics Integration for Uriel Academy

## Overview
This document explains how Firebase Analytics is integrated into the Uriel Academy web application.

## Architecture

### Flutter Firebase Integration
- **Primary Firebase handling**: Flutter packages (`firebase_core`, `firebase_auth`, etc.) handle all Firebase operations within the Flutter app
- **Automatic initialization**: Firebase is initialized automatically by Flutter when the app starts
- **No manual scripts needed**: Standard Firebase features work without additional HTML configuration

### Custom HTML-Level Analytics
- **Purpose**: For custom analytics events that need to be tracked at the HTML/DOM level
- **Compatibility mode**: Uses Firebase compat versions to avoid ES module conflicts
- **Conditional loading**: Only initializes if Flutter hasn't already initialized Firebase
- **Dual tracking**: Events are sent to both Firebase Analytics and Google Analytics

## Usage

### Custom Event Tracking
Use the global `trackCustomEvent` function for custom analytics events:

```javascript
// Track a custom event
window.trackCustomEvent('button_click', {
  button_name: 'start_quiz',
  subject: 'mathematics',
  user_level: 'beginner'
});

// Track user engagement
window.trackCustomEvent('feature_usage', {
  feature: 'quick_actions',
  action: 'continue_study',
  timestamp: Date.now()
});
```

### Page View Tracking
Use the global `trackPageView` function for page view events:

```javascript
// Track page views
window.trackPageView('home_dashboard');
window.trackPageView('quiz_categories');
```

### From Flutter/Dart Code
For analytics within Flutter, continue using the standard Firebase Analytics package:

```dart
import 'package:firebase_analytics/firebase_analytics.dart';

final analytics = FirebaseAnalytics.instance;

// Log events
await analytics.logEvent(
  name: 'quiz_started',
  parameters: {
    'subject': 'mathematics',
    'difficulty': 'medium',
  },
);

// Set user properties
await analytics.setUserProperty(
  name: 'user_level',
  value: 'advanced',
);
```

## Configuration

### Firebase Config
The Firebase configuration is automatically loaded from `lib/firebase_options.dart`. The HTML initialization uses the same web configuration.

### Google Analytics Integration
Events tracked via `trackCustomEvent` are automatically forwarded to Google Analytics as well, providing dual analytics coverage.

## Files Modified

- `web/index.html`: Added Firebase compat scripts and custom initialization
- `lib/firebase_options.dart`: Contains Firebase configuration (unchanged)

## Troubleshooting

### ES Module Errors
If you see "Unexpected token 'export'" errors:
1. Ensure you're using compat versions (`firebase-app-compat.js`)
2. Make sure scripts load after Flutter bootstrap
3. Check that Firebase isn't initialized twice

### Analytics Not Working
1. Verify Firebase config matches `firebase_options.dart`
2. Check browser console for initialization messages
3. Ensure events are called after `flutter-first-frame` event

### Conflicts with Flutter Firebase
1. HTML Firebase only initializes if Flutter hasn't already done so
2. Use different Firebase app instances if needed
3. Consider removing HTML Firebase if not needed for custom analytics

## Maintenance

### Updating Firebase Version
1. Update the version numbers in `web/index.html`
2. Test compatibility with Flutter Firebase packages
3. Update documentation if APIs change

### Removing Custom Analytics
If custom HTML-level analytics are no longer needed:
1. Remove the Firebase script tags from `web/index.html`
2. Remove the Firebase initialization script
3. Keep only Flutter Firebase integration

## Best Practices

1. **Use Flutter Analytics First**: Prefer Firebase Analytics through Flutter packages for app-level tracking
2. **HTML Analytics for Edge Cases**: Use HTML-level tracking only when Flutter can't access the needed data
3. **Consistent Event Naming**: Use consistent event names across both tracking methods
4. **Privacy Compliance**: Ensure analytics comply with privacy regulations
5. **Testing**: Test analytics events in development before deploying</content>
<parameter name="filePath">c:\uriel_mainapp\FIREBASE_ANALYTICS_INTEGRATION.md