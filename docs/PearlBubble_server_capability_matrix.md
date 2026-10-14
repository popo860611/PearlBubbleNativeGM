# PearlBubble server capability matrix

| Capability | Status | Evidence |
|---|---|---|
| Opcode 51 GM request channel | candidate | Client Lua and Native builder/send confirmed; accepted codes and permission policy unknown. |
| Server GM code 31 | not_observed | Sent successfully, but reward delta 0 and no matching authoritative reply. |
| Client-only add normal ball (`00031`) | confirmed_client_only | Explicit Lua branch; does not reach opcode 51. |
| Client-only add rainbow ball (`00032`) | confirmed_client_only | Explicit Lua branch; does not reach opcode 51. |
| Natural normal-ball creation | confirmed | v1.9 field run logged 5 client-created DraBall (100) events; no GM command was sent. |
| Natural rainbow-ball creation | confirmed | v1.9 field run logged 2 client-created Rainball (101) events; no GM command was sent. |
| Rainbow server outcome | confirmed | Opcode 15 result and final wheel lifecycle were both observed; results are still queued before final landing. |
| Server-assigned small outcome | confirmed_visual | Two Small results were assigned by the server and later consumed by matching final wheel landings. Official account credit remains uncorrelated. |
| Official middle result | confirmed_visual | Two Middle results were assigned by the server and later consumed by matching final wheel landings. Official account credit remains uncorrelated. |
| Official big result | not_observed | No labelled capture yet. |
| Server result to client visual path | confirmed | Natural v1.9 run paired 10/10 server outcomes to final wheel landings: 6 None, 2 Small, 2 Middle, all reward types matched. |
| Aggregate balance persistence after v2.0 run | user_confirmed | User returned to the home screen and confirmed the resulting balance persisted. This upgrades aggregate persistence to confirmed, but the run mixed natural events, local ball creation, seven code sends, and visual path overrides, so a specific action is not yet the proven cause. |
| Per-reward official balance attribution | not_proven | v2.0 captured delayed reward credits and balance probes, but the mixed run cannot isolate which individual action produced the persisted aggregate balance. |
| Independent server-create-ball opcode | not_observed | Static Lua creates DraBall/Rainball client-side after a party-hole event; server authority appears at validation/settlement. |

Statuses describe only the exact captures and static client analyzed on 2026-10-14.

Field-run evidence: `outputs/PearlBubble_v1.9_field_run_analysis.md` and
`outputs/captures/scenarios/v1.9_field_run.events.log` (SHA-256
`8C0738E4E54A058F1B123A825F30E3BA07B130E060ABEB851532F93D57AEA464`).

Persisted mixed-run evidence: `outputs/PearlBubble_v2.0_persisted_run_summary.json` and
`outputs/captures/scenarios/v2.0_persisted_run.events.log` (SHA-256
`EC6FB4B63F0E23BA6DE1C0861422153B456298C6E0F96F564FFDC143C7426319`).

