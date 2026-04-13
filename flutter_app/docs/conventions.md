# HOPE Flutter App — Coding Conventions

## Architecture Ground Rules

- **No Bluetooth.** The glove talks to the backend over WiFi. The app talks to the backend over HTTP. The app and glove never communicate directly.
- **App does NOT call `/ingest` in the normal patient flow.** That's the glove's endpoint. The debug "Simulate Glove" button is the only exception — it calls `/ingest` to mimic the glove during development/demos. This code path lives in `ApiService.simulateGlove()` and is only reachable from the debug waiting screens.
- **Device linking is a database write**, not a hardware pairing. `PUT /sessions/{id}/device` just stores a `device_id` string so the backend knows which session to route glove data to.

## File & Naming Conventions

- **File naming**: `snake_case.dart` — one primary class per file
- **Class naming**: `UpperCamelCase` (e.g., `SessionProvider`, `AssessmentResult`)
- **Variable/method naming**: `lowerCamelCase`
- **Constants**: `lowerCamelCase` (Dart convention, NOT `kPrefix`)

## Import Ordering

Organize imports in this order, alphabetically within each section:

1. `dart:` imports
2. `package:flutter/` imports
3. `package:` third-party imports (alphabetical)
4. Relative imports (alphabetical)

## State Management

- Single `SessionProvider` at app root via `ChangeNotifierProvider`
- Use `context.watch<SessionProvider>()` for rebuilds
- Use `context.read<SessionProvider>()` for one-shot method calls
- Business logic lives in provider only — screens are thin

## Error Handling

- `ApiException` thrown by `ApiService` → caught in provider
- Provider sets `errorMessage` and calls `notifyListeners()`
- Screens show `SnackBar` when `errorMessage != null`
- Call `provider.clearError()` after displaying error

## Widget Composition

- **Screens**: Thin widgets that read state and call provider methods
- **Reusable widgets**: Pure stateless widgets in `lib/widgets/`

## Navigation

- Use `Navigator.push` / `Navigator.pop` — no named routes
- Use `Navigator.popUntil((route) => route.isFirst)` to return home
- Use `Navigator.pushReplacement` for flow transitions

## Polling Pattern

```dart
void startPolling() {
  _pollCount = 0;
  _pollingTimer?.cancel();
  _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
    _pollCount++;
    if (_pollCount > 20) { // 60 second timeout
      _pollingTimer?.cancel();
      _errorMessage = 'Timed out';
      notifyListeners();
      return;
    }
    // Check condition...
  });
}

@override
void dispose() {
  _pollingTimer?.cancel();
  super.dispose();
}
```

## Color Usage

- Primary: `Colors.teal` (brand color)
- Success: `Colors.green`
- Warning: `Colors.amber`
- Error: `Colors.red`
- Use `Color.withValues(alpha: x)` instead of deprecated `Color.withOpacity(x)`
