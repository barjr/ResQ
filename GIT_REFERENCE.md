# Git Quick Reference for ResQ Contributors

## 🚀 Daily Workflow Commands

### Starting Work

```bash
# 1. Switch to main and sync
git checkout main
git pull upstream main

# 2. Create feature branch
git checkout -b feature/your-feature-name

# 3. Check current status
git status
```

### Making Changes

```bash
# 1. See what files changed
git status

# 2. See specific changes
git diff

# 3. Stage files for commit
git add .                    # Stage all changes
git add filename.dart        # Stage specific file

# 4. Commit changes
git commit -m "feat(scope): description of changes"

# 5. Push to your branch
git push origin feature/your-feature-name
```

### Keeping Branch Updated

```bash
# 1. Fetch latest changes
git fetch upstream

# 2. Rebase your branch on main
git rebase upstream/main

# 3. Force push updated branch
git push origin feature/your-feature-name --force-with-lease
```

## 📝 Commit Message Templates

Copy and modify these templates:

```bash
# New feature
git commit -m "feat(auth): add user login functionality"

# Bug fix
git commit -m "fix(home): resolve crash when loading contacts"

# Documentation
git commit -m "docs(readme): update installation instructions"

# Code style/formatting
git commit -m "style(main): format code according to dart guidelines"

# Refactoring
git commit -m "refactor(services): extract API calls to separate service"

# Tests
git commit -m "test(auth): add unit tests for login validation"

# Dependencies/build
git commit -m "chore(deps): update flutter dependencies"
```

## 🌿 Branch Naming Examples

```bash
# Features
git checkout -b feature/user-authentication
git checkout -b feature/emergency-contacts
git checkout -b feature/location-tracking

# Bug fixes
git checkout -b fix/login-validation-error
git checkout -b fix/crash-on-startup

# Documentation
git checkout -b docs/readme-update
git checkout -b docs/api-documentation

# Refactoring
git checkout -b refactor/user-service-cleanup
```

## 🆘 Emergency Commands

### Undo Last Commit (not pushed)

```bash
git reset --soft HEAD~1    # Keep changes staged
git reset HEAD~1           # Keep changes unstaged
git reset --hard HEAD~1    # Delete changes completely
```

### Fix Commit Message (last commit, not pushed)

```bash
git commit --amend -m "new commit message"
```

### Stash Changes Temporarily

```bash
git stash                  # Save current changes
git stash pop              # Restore stashed changes
git stash list             # See all stashes
```

### Resolve Merge Conflicts

```bash
# During rebase, after fixing conflicts in files:
git add .
git rebase --continue

# To abort rebase if things go wrong:
git rebase --abort
```

### Switch Branches with Uncommitted Changes

```bash
git stash                  # Save current work
git checkout other-branch  # Switch branches
git checkout -             # Switch back to previous branch
git stash pop              # Restore your work
```

## 🔍 Checking Your Work

### Before Committing

```bash
flutter analyze            # Check for code issues
flutter test              # Run tests
git status                # See what will be committed
git diff --staged         # See staged changes
```

### Before Creating PR

```bash
git log --oneline -5      # Check recent commits
git rebase -i HEAD~3      # Interactive rebase (clean up commits)
```

## 📋 Pre-Commit Checklist

Run these commands before every commit:

```bash
# 1. Format code
dart format .

# 2. Check for issues
flutter analyze

# 3. Run tests
flutter test

# 4. Check what you're committing
git status
git diff --staged

# 5. Commit with good message
git commit -m "type(scope): clear description"
```

## 🔄 Pull Request Workflow

```bash
# 1. Push your branch
git push origin feature/your-feature-name

# 2. Create PR on GitHub
# 3. Address review feedback by making changes and pushing again
git add .
git commit -m "fix: address review feedback"
git push origin feature/your-feature-name

# 4. After PR is merged, clean up
git checkout main
git pull upstream main
git branch -d feature/your-feature-name
git push origin --delete feature/your-feature-name
```

## 🎯 Common Scenarios

### Working on Multiple Features

```bash
# Save current work
git stash

# Switch to other feature
git checkout feature/other-feature

# Work on it...

# Switch back
git checkout feature/original-feature
git stash pop
```

### Accidentally Committed to Wrong Branch

```bash
# If you committed to main instead of feature branch:
git checkout main
git reset --soft HEAD~1    # Undo commit, keep changes
git stash                  # Save changes
git checkout -b feature/correct-branch
git stash pop              # Restore changes
git add .
git commit -m "correct commit message"
```

### Update PR with Latest Main Changes

```bash
git checkout main
git pull upstream main
git checkout feature/your-branch
git rebase main
git push origin feature/your-branch --force-with-lease
```

---

Keep this reference handy while working on ResQ! 🚑⚡
