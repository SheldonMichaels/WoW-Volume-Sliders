# Preset System — How It Works

Volume Sliders includes a layered preset system that can automatically adjust your volume levels based on context (zones, fishing, LFG queues) or manual toggles. This document explains exactly how presets interact with your volumes, mute states, and each other — including the edge cases.

If you've ever wondered *"why did my volume change when I walked into Duskwood?"* or *"why didn't my preset unmute that channel?"*, the answer is here.

---

## The Three-Layer State Stack

All preset evaluation flows through a deterministic layering model:

| Layer | Name | Source | Conflict Resolution |
|-------|------|--------|---------------------|
| **0** | Baseline | Your intended volumes | N/A — this is the foundation |
| **1** | Automation | Zones, Fishing, LFG | Sorted by priority number (user-configured) |
| **2** | Manual | Presets you explicitly toggle | Most recently toggled wins |

Higher layers always overwrite lower layers on conflicting channels. Within a layer, the conflict resolution method listed above determines which preset wins.

### Mathematical Modes

Each channel in a preset operates in one of three modes. These control *how* a value is applied, not *whether* it is applied:

| Mode | Behavior | Example |
|------|----------|---------|
| **Absolute** | Overwrites the current value | "Set Master to 80%" |
| **Floor** | Ensures a minimum value | "Master should be at *least* 80%" |
| **Ceiling** | Ensures a maximum value | "Master should be at *most* 20%" |

> **Note:** Contradictory constraints (e.g., one preset floors Master at 80% while another ceilings it at 20%) are an inherent mathematical conflict. The higher-priority or more-recent preset determines which constraint evaluates last. This is expected behavior, not a bug.

---

## The Rules

These rules define how your actions interact with presets and automation.

---

### Rule 1 — Manual Toggles Command Everything ("The Iron Fist")

Toggling a manual preset ON is an absolute command. It forcefully:
1. **Overrides any slider adjustments** you made on the channels the preset targets
2. **Unmutes** any targeted channel — unless the preset itself is configured to mute that channel

This is the **only** mechanism (besides clicking a mute checkbox) that can reverse a mute. Automated presets (zones, fishing, LFG) can never unmute a channel.

**What the toggle does NOT touch:**
- Channels marked as "ignored" in the preset configuration (left completely alone)
- Channels the preset is specifically configured to mute

**Why:** A button click is the strongest possible expression of intent. When you toggle "Raid Time" and it sets SFX to 80%, your intent is clearly "I want to hear SFX at 80%." A muted channel at 80% is functionally useless — the preset's intent would be silently defeated. If you don't want a channel affected, mark it as ignored in the preset configuration.

---

### Rule 2 — Zone Changes Reset Your Tweaks

A zone transition replaces the old acoustic environment with a new one. When a new zone preset activates, any slider adjustments you made in the previous zone are cleared for the channels the new zone targets.

**Why:** Slider adjustments are tweaks for "this place." Walking into a new zone is a fundamentally new context — your old tweaks shouldn't persist and block the new zone's automation.

**Why only zones:** Zones are continuous environmental boundaries. Fishing and LFG are temporary spikes that overlay the current environment — they don't replace it (see Rule 4).

---

### Rule 3 — Automation Cannot Unmute

If you manually mute a channel using the mute checkbox, **no automated preset can unmute it.** Only two things can reverse a manual mute:
1. Clicking the mute checkbox again
2. Toggling a manual preset that targets that channel (Rule 1)

**Preset-applied mutes are different.** If a preset mutes a channel as part of its configuration, that mute *will* revert when the preset deactivates — but only if you didn't also manually mute the channel yourself. Your manual mute always takes priority.

**Why:** Muting is a deliberate, conscious action. If you muted SFX, you don't want a zone transition to unmute it. Automation is passive and should never surprise you.

---

### Rule 4 — Fishing & LFG Punch Through

Fishing and LFG presets are temporary spikes, not state changes. They bypass any slider adjustments you've made to do their job, then vanish. When the event ends, your volumes fall gracefully back to what they were before.

**Why bypass instead of reset:** If fishing *erased* your slider adjustments, then when fishing ends, your tweaks would be forgotten — volumes would snap back to baseline instead of where you had them. By temporarily overriding without erasing, your adjustments survive and reassert when the event ends.

---

### Rule 5 — Last Click Wins (Manual Presets)

When multiple manual presets are active and target the same channel, the most recently toggled preset wins. No priority configuration is needed — your last click takes effect.

Automated presets (Layer 1) use priority numbers instead, since they activate passively and there's no "click" to establish recency.

---

### Rule 6 — Active Means Active

Multiple manual presets can be active simultaneously, even if one overshadows another on a shared channel. Toggling a preset ON means it stays ON until you toggle it OFF.

**Example:** If "Late Night" (Master = 20%) and "Raid Time" (Master = 100%) are both active, disabling "Raid Time" reveals "Late Night" underneath — your Master drops to 20%, not back to baseline. The system stacks all active presets and resolves conflicts by recency.

---

### Rule 7 — Slider Adjustments Are Temporary

If you drag a slider while presets are active, that adjustment is a temporary tweak for your current context. It:
- **Is cleared** when you enter a new zone (Rule 2)
- **Survives** fishing and LFG events (Rule 4)
- **Is overwritten** by toggling a manual preset on that channel (Rule 1)

Mute checkbox clicks are **not** temporary adjustments — they update your baseline mute state directly (see Rule 11).

**Why:** If you lower Master to 60% in Elwynn Forest, that's an Elwynn-specific preference. Walking into Duskwood is a new context. Casting a fishing line isn't.

---

### Rule 8 — Your Baseline Survives Logout

Your "intended volumes" (the baseline) are never lost due to logout timing. When you log back in, the addon uses a smart merge to distinguish between "the volume the addon set via a preset" and "the volume the user actually wants." This prevents logging out inside a preset zone from permanently corrupting your true volume preferences.

---

### Rule 9 — The Kill Switch

When all presets are deactivated (every type — zone, fishing, LFG, and manual — is empty), all temporary slider adjustments are wiped. This prevents stale tweaks from leaking into future sessions or zones.

**Why:** Slider adjustments exist to say "keep this channel where I put it despite active presets." When there are no active presets, that statement is meaningless — and leftover adjustments could silently block future presets from working.

---

### Rule 10 — Deleting Active Presets Is Safe

If you delete a preset while it's currently active, the addon immediately cleans up:
1. Removes the preset from the active list
2. Recalculates all remaining preset effects
3. Ensures other presets in the list aren't affected by the index shift

You won't end up in a broken state by deleting an active preset.

---

### Rule 11 — Volume and Mute Are Independent

Volume levels and mute states are tracked on **separate, parallel tracks.** When an automated preset changes a channel's volume, the mute state is left alone.

- If SFX is muted and a zone preset sets SFX to 80%, the volume changes to 80% behind the scenes — but the channel stays muted. When you manually unmute, you'll hear it at 80%.
- Automated presets can mute a channel (if configured to), and that mute reverts when the preset deactivates. But they can never *unmute* a channel that you muted yourself.
- Manual presets are the exception — the Iron Fist (Rule 1) can unmute channels because the toggle is an explicit user action.

**Why:** Muting and adjusting volume are different intentions. Automation should adjust levels in the background without surprising you by unmuting something you silenced.

---

### Rule 12 — Manual Presets Survive Logout

Which manual presets are toggled ON persists across logout, UI reloads, and character switches. When you log back in, previously active presets are re-applied and visible in the minimap tooltip.

**What persists:** Which presets are active and their relative activation order.

**What doesn't persist:** Temporary slider adjustments (they're session-specific per Rule 7).

**Why:** If you log in and your Master is at 20% because "Late Night" was toggled on, you need to see that "Late Night" is active so you can toggle it off. Without persistence, the addon would show no active presets and you'd have no idea why your volumes are different.

---

### Rule 13 — All-Ignored Presets Are Valid

A preset with every channel set to "ignored" is perfectly valid. It sits inert in the system, preserving its configured values for future editing. This is a simple way to temporarily disable a preset without deleting it.

---

## Interaction Quick Reference

This table summarizes what happens to your audio state for every meaningful action:

| Your Action | Slider Adjustments | Active Presets | Mute State | Baseline |
|---|---|---|---|---|
| **Drag a slider** (presets active) | Stored as temporary tweak | No change | No change | Volume value updated |
| **Toggle manual preset ON** | **Cleared** for preset's channels | Preset added | **Unmutes** targeted channels (unless preset mutes them) | No change |
| **Toggle manual preset OFF** | No change | Preset removed | No change | No change |
| **Enter a new zone** (automation on) | **Cleared** for zone's channels | Zone preset replaces previous | No change | No change |
| **Leave a zone** (no new match) | No change | Zone preset removed | No change | No change |
| **Cast fishing** | No change (punches through) | Fishing preset added | No change | No change |
| **Stop fishing** | No change | Fishing preset removed | No change | No change |
| **LFG queue pops** | No change (punches through) | LFG preset added | No change | No change |
| **LFG proposal ends** | No change | LFG preset removed | No change | No change |
| **All presets deactivated** | **Wiped entirely** (kill switch) | All empty | No change | No change |
| **Delete a preset** (settings) | No change | Removed + shifted | No change | No change |
| **Click mute checkbox** | No change | No change | Toggled in saved data | Mute baseline updated |
| **Log in** | Fresh (empty) | Zones re-evaluate; manual presets restored | Loaded from saved data | Smart merge |
