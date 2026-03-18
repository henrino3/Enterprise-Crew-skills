---
name: model-orchestrator
description: "Intelligent model load balancer for OpenClaw crons — distributes across providers by complexity and cost. Use when optimizing model selection for crons, balancing provider load, or troubleshooting model routing."
---

# Model Orchestrator

Intelligent model load balancer for OpenClaw crons. Distributes crons across providers based on task complexity, provider health, quota status, and cost.

## Architecture

### Tier System
- **Tier 1 (Simple):** Runs bash scripts, reports HEARTBEAT_OK → cheapest available
- **Tier 2 (Medium):** Reads output, screens content, makes simple decisions → mid-tier
- **Tier 3 (Complex):** Strategy, analysis, creative, long context → smartest available

### Provider Priority (per tier)
| Tier | Primary | Secondary | Tertiary | Emergency |
|------|---------|-----------|----------|-----------|
| T1   | MiniMax | Flash 3   | Kimi     | (pause)   |
| T2   | Flash 3 | Kimi      | MiniMax  | (pause)   |
| T3   | Opus    | Sonnet    | Kimi     | Flash 3   |

### Provider Billing Models
**IMPORTANT:** Not all providers use credit-based billing. Know the model before diagnosing.

| Provider | Billing Model | "Down" Diagnosis |
|----------|--------------|------------------|
| **Z.ai (GLM)** | **Rate-limit / quota system** (like Anthropic/OpenAI). $360/yr Coding Max plan. NOT credits. Error 1113 ("余额不足") = quota exhausted for current period, NOT empty balance. Resets periodically. Check dashboard: https://open.bigmodel.cn/ |
| **Anthropic** | Rate-limit tiers (tokens/min, requests/min). Cooldown = temporary. |
| **OpenAI** | Rate-limit tiers. Monthly spend caps optional. |
| **Google** | Rate-limit per model per minute. Free tier available. |
| **MiniMax** | API credits (actual balance). |
| **Kimi** | Rate-limit system. |

**Rule:** When a provider returns quota/limit errors, report it as "quota limit hit — resets on [date]" NOT "balance depleted / needs top-up." Check the dashboard for reset timing before recommending action.

### Crisis Mode
When 2+ providers are down:
1. Move ALL T1 crons to surviving cheap provider
2. PAUSE T2 crons that aren't critical
3. Keep only critical T3 crons running
4. Log everything for recovery

### Recovery
- Scrape provider dashboards for quota reset times
- Create one-shot `at` crons to check recovery
- Auto-redistribute when providers come back

## Files
- `state/cron-tiers.json` — cron ID → tier mapping + metadata
- `state/provider-status.json` — compact current provider health/quota snapshot (backward-compatible)
- `state/provider-tracking.json` — detailed provider registry: status, source, checks, quota payloads, staleness, temp-model registry
- `state/switches.log` — audit trail of all model switches
- `scripts/orchestrate.sh` — main orchestrator (run daily or on-demand)
- `scripts/check-provider.sh` — test a single provider
- `scripts/scrape-quota.sh` — scrape dashboards for quota info
