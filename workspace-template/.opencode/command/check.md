---
description: Acceptance level for a topic (usage: /check <topic>)
agent: workshop
---
!`ws-check $ARGUMENTS`

Report the level and the evidence lines in two or three lines. If the level is
below 3, the `hint:` line names the missing item: name the one step that
fixes it and take it (the harness prompts for edits and submissions). If no
topic was given, use the `topic:` field of PROGRESS.md and run
`ws-check <topic>` (add `--tailored` if PLAN.md names a TAILOR.md variant)
yourself.
