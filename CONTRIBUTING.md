# Contributing

For non-trivial work:

1. Open or reference an issue.
2. Use a feature branch.
3. Add deterministic tests using temporary files.
4. Keep filesystem and privacy boundaries explicit.
5. Let CI and CodeQL pass without weakening checks.
6. Merge through a pull request.

Do not add analytics, telemetry, remote APIs, cloud sync, or network dependencies to the core without an explicit design decision and privacy review.
