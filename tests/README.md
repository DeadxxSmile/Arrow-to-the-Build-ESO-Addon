# Tests

`mock_test.lua` loads every addon Lua file inside a small mocked ESO environment and checks:

- stable multi-character snapshots and rename behavior
- class/race/gender identity fields
- canonical morph and ranked ability IDs
- equipment normalization
- all twelve assignable Champion slots across the three disciplines
- diagnostics, slash commands and SavedVariables revision behavior

Run with a Lua 5.1-compatible interpreter:

```text
lua tests/mock_test.lua addon/ArrowToTheBuild
```

The regression also simulates a full UI reload between two characters and verifies that the first SavedVariables record is retained before the second is appended.
