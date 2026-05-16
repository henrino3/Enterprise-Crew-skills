# Example Codex goal

Goal: Add a small CSV export path to an existing reports page.

Install and run:

```bash
god-scale init --goal "Add CSV export to reports" --mode codex
god-scale mission add "Implement CSV export helper and button" --accept "npm test" --scope "Reports page and export helper only."
god-scale run --mode codex
```
