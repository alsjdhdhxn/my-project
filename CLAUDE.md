## Memory Bank Extension

`claude-memory-bank` has been installed in this project:

- `.claude/agents/`
- `.claude/commands/context/`
- `.claude/workflows/memory-bank/`
- `.claude/memory_bank/` (local memory store)
- `.claude/CLAUDE.memory-bank.md` (reference instructions)

When using Claude Code context commands, keep memory updates inside:

- `.claude/memory_bank/decisions/`
- `.claude/memory_bank/patterns/`
- `.claude/memory_bank/architecture/`
- `.claude/memory_bank/troubleshooting/`

Do not write into `.claude/memory_bank/archive/` except for explicit archival tasks.
