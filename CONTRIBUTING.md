# Contributing to ResQ

Welcome to the ResQ project! This guide will help you contribute effectively while maintaining clean and organized code practices.

## 📋 Table of Contents

- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Branch Naming Conventions](#branch-naming-conventions)
- [Commit Message Guidelines](#commit-message-guidelines)
- [Pull Request Process](#pull-request-process)
- [Code Style Guidelines](#code-style-guidelines)
- [Testing](#testing)

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (latest stable version)
- Git
- A GitHub account
- Access to the ResQ repository

### Initial Setup

1. **Fork the repository** (if you're an external contributor)

   ```bash
   # Navigate to https://github.com/barjr/ResQ and click "Fork"
   ```

2. **Clone your fork** (or the main repo if you're a team member)

   ```bash
   git clone https://github.com/YOUR_USERNAME/ResQ.git
   cd ResQ/resq
   ```

3. **Add upstream remote** (for forks)

   ```bash
   git remote add upstream https://github.com/barjr/ResQ.git
   ```

4. **Install dependencies**

   ```bash
   flutter pub get
   ```

5. **Verify setup**
   ```bash
   flutter doctor
   flutter test
   ```

## 🔄 Development Workflow

### 1. Sync with Main Branch

Always start by syncing with the latest changes:

```bash
# Switch to main branch
git checkout main

# Pull latest changes from upstream
git pull upstream main

# Push to your fork (if applicable)
git push origin main
```

### 2. Create a Feature Branch

Create a new branch for your work:

```bash
# Create and switch to a new branch
git checkout -b feature/your-feature-name

# Or for bug fixes
git checkout -b fix/issue-description

# Or for hotfixes
git checkout -b hotfix/critical-fix
```

### 3. Make Your Changes

- Write clean, readable code
- Follow Flutter and Dart best practices
- Add comments where necessary
- Write/update tests as needed

### 4. Test Your Changes

```bash
# Run all tests
flutter test

# Run the app to test manually
flutter run

# Check for linting issues
flutter analyze
```

## 🌿 Branch Naming Conventions

Use descriptive branch names with the following prefixes:

- **feature/**: New features

  - `feature/user-authentication`
  - `feature/emergency-contacts`
  - `feature/location-tracking`

- **fix/**: Bug fixes

  - `fix/login-validation-error`
  - `fix/crash-on-startup`

- **hotfix/**: Critical fixes for production

  - `hotfix/security-vulnerability`
  - `hotfix/data-loss-bug`

- **refactor/**: Code refactoring

  - `refactor/user-service-cleanup`
  - `refactor/widget-structure`

- **docs/**: Documentation updates

  - `docs/readme-update`
  - `docs/api-documentation`

- **chore/**: Maintenance tasks
  - `chore/dependency-updates`
  - `chore/build-configuration`

## 📝 Commit Message Guidelines

Write clear, concise commit messages using the conventional commit format:

### Format

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

### Types

- **feat**: A new feature
- **fix**: A bug fix
- **docs**: Documentation changes
- **style**: Code style changes (formatting, etc.)
- **refactor**: Code refactoring
- **test**: Adding or updating tests
- **chore**: Build process or auxiliary tool changes

### Examples

```bash
# Good commit messages
git commit -m "feat(auth): add user login functionality"
git commit -m "fix(home): resolve crash when loading emergency contacts"
git commit -m "docs(readme): update installation instructions"
git commit -m "style(main): format code according to dart style guide"
git commit -m "refactor(services): extract API calls to separate service"
git commit -m "test(auth): add unit tests for login validation"
git commit -m "chore(deps): update flutter dependencies"

# Bad commit messages (avoid these)
git commit -m "fix stuff"
git commit -m "WIP"
git commit -m "asdf"
git commit -m "updated files"
```

### Multi-line Commit Messages

For complex changes, provide more detail:

```bash
git commit -m "feat(emergency): add emergency contact management

- Add ability to add/edit/delete emergency contacts
- Implement contact validation and phone number formatting
- Add emergency contact list view with search functionality
- Include tests for contact management service

Closes #123"
```

## 🔄 Pull Request Process

### 1. Push Your Branch

```bash
# Push your feature branch to your fork
git push origin feature/your-feature-name
```

### 2. Create Pull Request

1. Go to GitHub and create a Pull Request
2. Use a descriptive title following the same convention as commits
3. Fill out the PR template (if available)
4. Link any related issues using keywords like "Closes #123"

### 3. PR Title Format

```
<type>(<scope>): <description>
```

Examples:

- `feat(auth): implement user registration flow`
- `fix(home): resolve emergency button not responding`
- `docs(contributing): add detailed Git workflow guide`

### 4. PR Description Template

```markdown
## Description

Brief description of changes made.

## Type of Change

- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update

## Testing

- [ ] I have added tests that prove my fix is effective or that my feature works
- [ ] New and existing unit tests pass locally with my changes
- [ ] I have tested this change on device/emulator

## Screenshots (if applicable)

Add screenshots or GIFs showing the changes.

## Checklist

- [ ] My code follows the style guidelines of this project
- [ ] I have performed a self-review of my own code
- [ ] I have commented my code, particularly in hard-to-understand areas
- [ ] My changes generate no new warnings
- [ ] Any dependent changes have been merged and published
```

### 5. Address Review Feedback

When reviewers provide feedback:

```bash
# Make requested changes
# Stage and commit changes
git add .
git commit -m "fix(auth): address review feedback - improve error handling"

# Push updated branch
git push origin feature/your-feature-name
```

### 6. Keep Branch Updated

If the main branch is updated while your PR is open:

```bash
# Switch to main and pull latest changes
git checkout main
git pull upstream main

# Switch back to your branch and rebase
git checkout feature/your-feature-name
git rebase main

# Force push the updated branch (only for your feature branches!)
git push origin feature/your-feature-name --force-with-lease
```

## 🎨 Code Style Guidelines

### Dart/Flutter Specific

1. **Follow Dart style guide**: Use `dart format` to format your code
2. **Use meaningful variable names**: `userEmail` instead of `e`
3. **Add documentation comments** for public APIs:

   ```dart
   /// Validates the user's email address format.
   ///
   /// Returns `true` if the email is valid, `false` otherwise.
   bool validateEmail(String email) {
     // Implementation
   }
   ```

4. **Use const constructors** when possible:
   ```dart
   const Text('Hello World')  // Good
   Text('Hello World')        // Avoid if const is possible
   ```

### File Organization

```
lib/
  ├── main.dart
  ├── models/
  │   ├── user.dart
  │   └── emergency_contact.dart
  ├── services/
  │   ├── auth_service.dart
  │   └── api_service.dart
  ├── pages/
  │   ├── home.dart
  │   ├── login.dart
  │   └── profile.dart
  ├── widgets/
  │   ├── custom_button.dart
  │   └── loading_indicator.dart
  └── utils/
      ├── constants.dart
      └── validators.dart
```

## 🧪 Testing

### Running Tests

```bash
# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage

# Run specific test file
flutter test test/widget_test.dart
```

### Writing Tests

1. **Unit tests** for business logic
2. **Widget tests** for UI components
3. **Integration tests** for full app flows

Example test structure:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:resq/services/auth_service.dart';

void main() {
  group('AuthService', () {
    test('should validate email correctly', () {
      // Arrange
      final authService = AuthService();

      // Act
      final result = authService.validateEmail('test@example.com');

      // Assert
      expect(result, true);
    });
  });
}
```

## 🚨 Common Issues and Solutions

### Merge Conflicts

If you encounter merge conflicts:

```bash
# Start rebase
git rebase main

# Resolve conflicts in your editor
# After resolving, stage the files
git add .

# Continue rebase
git rebase --continue

# Push updated branch
git push origin feature/your-feature-name --force-with-lease
```

### Accidental Commits to Main

If you accidentally commit to main:

```bash
# Reset main to upstream
git checkout main
git reset --hard upstream/main

# Create new branch with your changes
git checkout -b feature/your-feature-name
git cherry-pick <commit-hash>
```

### Large Files

Avoid committing large files. Use Git LFS for assets if needed:

```bash
# Track large files with Git LFS
git lfs track "*.png"
git lfs track "*.jpg"
git add .gitattributes
```

## 📞 Getting Help

- **Issues**: Create an issue on GitHub for bugs or feature requests
- **Discussions**: Use GitHub Discussions for questions
- **Code Review**: Don't hesitate to ask for help in PR comments

## 🎯 Final Checklist

Before submitting any PR, ensure:

- [ ] Code compiles without errors
- [ ] All tests pass
- [ ] Code follows style guidelines
- [ ] Commit messages are clear and follow conventions
- [ ] PR description is complete
- [ ] No sensitive information is committed
- [ ] Branch is up to date with main

---

Thank you for contributing to ResQ! Your efforts help make emergency response more effective and accessible. 🚑✨
