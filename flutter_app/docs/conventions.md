# HOPE Flutter App — Coding Conventions

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

Example:
```dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../models/session.dart';
import '../services/api_service.dart';
```

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
- Avoid inline widget definitions unless trivial

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
