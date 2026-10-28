# @carl/dev

CLI tools for managing Carl projects, including importing external repositories.

## Running

Requires Node.js 26.12.1 or later and pnpm 12.16.0 or later.

```bash
pnpm run start import <repository-url> [--prefix <prefix>]
```

## Configuration

This package reads `carl-repo.json` from the current or parent directories to determine the project configuration.

## How it works

The `import` command fetches an external git repository from GitHub, GitLab, or Tangled, scans it for `.lua` files (excluding test directories), and registers them in your project's `carl-repo.json`. Each file is linked via its raw URL at the latest commit, and a version string is generated from the repository's most recent commit date.
