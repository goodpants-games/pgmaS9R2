## Programming conventions
- Constants must be in `UPPERCASE_SNAKE_CASE`.
- Non-constant global variables must be in `PascalCase`.
- Avoid using globals.
  - The only module that should be exported to a global is batteries and
    sceneman. The remaining modules are not used frequently enough for them to
    need to be globals. (sceneman is an exception).
- Modules and classes must be in `PascalCase`.
- Use `camelCase` for everything else. (Note: Some old code uses snake case.
  Ignore it.)

## Misc. conventions
- File and directory names must be in `snake_case`.