# Dashboard
{{["scripts/today.lua"]}}


## Active tasks
{{["scripts/tasks.lua", {"path":"quests","status": "/", "label": "🟦"} ]}}
---
## Urgent tasks (example using tags)
{{["scripts/tasks.lua", {"path":"quests","tags": ["urgent"], "label": "🟦"} ]}}

## Today habits
--------------
{{["scripts/tasks.lua", {"path":"journal","status": "_", "label": "🟥", "today": "true"} ]}}
--------------
{{["scripts/tasks.lua", {"path": "journal","status": "x", "label": "✅", "today": "true"} ]}}

## Active quests
{{[ "scripts/quests.lua", {"path": "quests/"} ] }}


