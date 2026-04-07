# Contributing to TruckerCore

Thank you for considering contributing to TruckerCore! This document provides guidelines for contributing to the project.

## 🎯 How Can I Contribute?

### Reporting Bugs
Before creating bug reports, please check existing issues. When creating a bug report, include:
- Clear title and description
- Steps to reproduce
- Expected vs actual behavior
- Screenshots (if applicable)
- Environment details:
  - OS version
  - Flutter version
  - App version
  - Device model (for mobile)

Bug report template:

```markdown
**Description:**
Brief description of the bug

**To Reproduce:**
1. Go to '...'
2. Click on '...'
3. See error

**Expected behavior:**
What should happen

**Screenshots:**
Add screenshots if applicable

**Environment:**
- OS: [e.g. Windows 11, macOS 14.0, Android 13]
- Flutter version: [e.g. 3.24.0]
- App version: [e.g. 1.0.0]
- Device: [e.g. iPhone 15, Samsung Galaxy S23]

**Additional context:**
Any other relevant information
```

### Suggesting Enhancements
Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion, include:
- Clear title and description
- Use case: Why is this enhancement useful?
- Proposed solution: How should it work?
- Alternatives considered
- Mockups/diagrams (if applicable)

### Pull Requests
1. Fork the repository
2. Create a feature branch
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. Make your changes
4. Follow the coding style
5. Add tests for new features
6. Update documentation
7. Commit your changes
   ```bash
   git commit -m "feat: add amazing feature"
   ```
8. Use conventional commits:
   - feat: New feature
   - fix: Bug fix
   - docs: Documentation changes
   - style: Code style changes
   - refactor: Code refactoring
   - test: Adding tests
   - chore: Maintenance tasks
9. Push to your fork
   ```bash
   git push origin feature/your-feature-name
   ```
10. Create a Pull Request

## 💻 Development Setup
```bash
# Clone your fork
git clone https://github.com/your-username/truckercore1.git

# Add upstream remote
git remote add upstream https://github.com/original-org/truckercore1.git

# Install dependencies
flutter pub get

# Run tests
flutter test

# Run the app
aflutter run
```

## 📝 Coding Guidelines

### Dart/Flutter Style
- Follow Effective Dart
- Use `flutter analyze` to check code quality
- Format code with `dart format`
- Maximum line length: 120 characters

### Code Organization
```dart
// 1. Imports (organized by category)
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/widgets/app_button.dart';
import '../models/load.dart';

// 2. Constants
const kMaxRetries = 3;

// 3. Providers
final loadProvider = Provider<LoadService>((ref) => LoadService());

// 4. Main class
class LoadScreen extends ConsumerWidget {
  const LoadScreen({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Implementation
  }
}

// 5. Private helper widgets/functions
class _LoadCard extends StatelessWidget {
  // Implementation
}
```

### Documentation
- Add doc comments for public APIs
- Use `///` for documentation comments
- Include examples for complex functions

```dart
/// Calculates the remaining drive time based on HOS rules.
///
/// Takes into account the current [driveTime] and [maxDriveTime].
/// Returns the remaining time in hours as a [double].
///
/// Example:
/// ```dart
/// final remaining = calculateRemainingDriveTime(5.5, 11.0);
/// print(remaining); // 5.5
/// ```
double calculateRemainingDriveTime(double driveTime, double maxDriveTime) {
  return (maxDriveTime - driveTime).clamp(0.0, maxDriveTime);
}
```

### Testing
- Write tests for all new features
- Aim for >80% code coverage
- Use meaningful test descriptions

```dart
void main() {
  group('LoadService', () {
    test('should fetch active loads for driver', () async {
      // Arrange
      final service = LoadService();
      
      // Act
      final loads = await service.getActiveLoads(driverId: 'test-id');
      
      // Assert
      expect(loads, isNotEmpty);
      expect(loads.first.status, 'in_transit');
    });
  });
}
```

## 🔄 Git Workflow
- Keep your fork up to date
  ```bash
  git fetch upstream
  git checkout main
  git merge upstream/main
  ```
- Create feature branches from main
  ```bash
  git checkout main
  git checkout -b feature/new-feature
  ```
- Commit often with clear messages
  ```bash
  git commit -m "feat: add load filtering"
  git commit -m "test: add tests for load filtering"
  git commit -m "docs: update load filtering documentation"
  ```
- Rebase before submitting PR
  ```bash
  git fetch upstream
  git rebase upstream/main
  ```

## 📋 Pull Request Checklist
Before submitting a PR, ensure:
- Code follows style guidelines
- Self-review completed
- Comments added for complex code
- Documentation updated
- No new warnings from `flutter analyze`
- All tests pass (`flutter test`)
- New tests added for new features
- PR description clearly explains changes
- Screenshots included (for UI changes)
- Breaking changes documented

## 🎨 UI/UX Guidelines
- Consistency: Use existing components when possible
- Accessibility: Ensure readable contrast, proper tap targets
- Responsiveness: Test on multiple screen sizes
- Performance: Avoid unnecessary rebuilds

### Component Usage
```dart
// Good: Use existing components
ElevatedButton(
  onPressed: handleSubmit,
  child: const Text('Submit'),
)

// Bad: Creating custom button unnecessarily
GestureDetector(
  onTap: handleSubmit,
  child: Container(
    padding: EdgeInsets.all(16),
    decoration: BoxDecoration(/* ... */),
    child: Text('Submit'),
  ),
)
```

## 🐛 Debugging Tips
- Enable debug mode
  ```bash
  flutter run --dart-define=DEBUG_LOGGING=true
  ```
- View logs
  - Mobile: Connect to device and run `flutter logs`
  - Desktop: Check console output
  - Production: View Sentry dashboard

### Common Issues
- Hot reload not working
  ```bash
  # Sometimes need to restart
  flutter run
  ```
- Build errors after merging
  ```bash
  flutter clean
  flutter pub get
  flutter run
  ```

## 📞 Getting Help
- Questions: Open a GitHub Discussion
- Bugs: Create a GitHub Issue
- Chat: Join our Discord server
- Email: dev@truckercore.com

## 🙏 Recognition
Contributors will be recognized in:
- README.md contributors section
- Release notes
- Annual contributor spotlight

Thank you for contributing to TruckerCore! 🚛💨
