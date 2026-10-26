# Contributing

Thanks for your interest in Inspector.

## Scope

Inspector shows what macOS hides. Anything that increases *clarity* is in scope:
new catalog entries, better safety explanations, boot / permission views.
Anything that pushes aggressive cleanup or auto-removal is out of scope.

## Development

1. Open the project in Xcode 15 or later.
2. Build and run on macOS 14 or later.
3. Follow existing SwiftUI patterns in `Inspector/`.

## Pull requests

- Keep changes small and focused — one concern per PR.
- Prefix titles with `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, or `ci:`.
- Describe *what changed* and *why* in the PR body.
- No AI-generated boilerplate in commits or descriptions.

## Adding a catalog entry

Each entry needs a plain-English `whatItIs` and `whatHappensIfRemoved`,
and an honest `SafetyLevel`. If you're not sure, mark it `.review`.
