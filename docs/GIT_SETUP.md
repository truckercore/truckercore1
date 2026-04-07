# Git Setup Quick Guide

This guide shows the basic steps to initialize a repository, stage your files, commit changes, and add a remote. Use these commands from the project root.

Note: This repository already appears to be a Git repository. If you see a .git folder or git status works, you can skip the initialize step.

1) Initialize the repository (only if not already initialized)
```
# Initialize a new Git repository
git init

# Optional: Set your identity (recommended)
git config user.name "Your Name"
git config user.email "you@example.com"
```

2) Add your files to staging
```
# Add all files
git add .

# Or add specific files
git add path\to\filename.ext
```

3) Commit your changes
```
# Commit with a descriptive message
git commit -m "Your commit message describing the changes"
```

4) Add a remote and push
```
# Replace placeholders with your actual GitHub info
git remote add origin https://github.com/your-username/your-repository.git

# If the branch is new, set upstream on first push
git push -u origin main
```

Tips
- Check status anytime: `git status`
- See recent commits: `git log --oneline --graph --decorate --all`
- Update local from remote: `git pull --rebase`
- Change the remote URL later: `git remote set-url origin https://github.com/your-username/your-repository.git`

Windows/PowerShell notes
- These commands work in PowerShell, Command Prompt, and Git Bash.
- If Git is not recognized, install Git for Windows: https://git-scm.com/download/win
