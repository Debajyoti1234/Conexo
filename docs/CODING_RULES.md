# Coding Rules

Always generate production quality Flutter code.

Never generate one-line widgets.

Every widget must be multi-line and properly formatted.

Maximum line length around 100 characters.

Always use const widgets where possible.

Never modify project architecture unless requested.

Flutter analyze must return zero errors.

Flutter run must succeed.

Split large files.

Avoid files larger than 300 lines.

Use reusable widgets.

Never leave TODO placeholders.

Never break existing working features.
## Interrupted Session Recovery

If the previous Codex session was interrupted or stopped because of usage limits:

1. Do NOT continue implementing new features.
2. First repair the project until:
   - dart format passes
   - flutter analyze passes
   - flutter run succeeds
3. Only after the build is green may new features be implemented.