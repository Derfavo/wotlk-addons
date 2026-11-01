# WotLK Addons

Four addons for World of Warcraft 3.3.5a (Interface 30300), developed for Whitemane Frostmourne Rebuffed.

| Addon | Version | What it does |
| --- | --- | --- |
| [RebuffedHealbot](RebuffedHealbot) | 0.6.3 | Healing frames with click bindings, spell suggestions and personal buff reminders |
| [RebuffedItemLevel](RebuffedItemLevel) | 1.2.3 | Item level and GearScore in character frames, inspect frames and player tooltips |
| [RebuffedRaidMarket](RebuffedRaidMarket) | 1.2.0 | Organizes raid recruitment and trade messages from a chat channel and posts your own ads |
| [RebuffedUpgrade](RebuffedUpgrade) | 1.0.1 | Rates equipment for your current specialization when you hover over an item |

## Installation

1. Click **Code → Download ZIP** above and extract the archive.
2. Close WoW completely.
3. Copy the addon folders you want directly into `World of Warcraft/Interface/AddOns/`. For example, the healing addon should have this path: `AddOns/RebuffedHealbot/RebuffedHealbot.toc`.
4. Start WoW and enable the addons on the character selection screen.

Do not copy the outer `wotlk-addons-main` folder into AddOns. To update an addon, replace its folder. Settings are stored in the WTF folder and are kept when you replace the addon files. If you are upgrading from ChronixHeal, follow the [migration instructions](RebuffedHealbot/README.md#upgrading-from-chronixheal) first.

RebuffedHealbot and RebuffedItemLevel work independently. RebuffedRaidMarket needs RebuffedItemLevel to include GearScore in your own ads; browsing channel messages works without it. RebuffedUpgrade requires **Pawn 1.3.8 for WoW 3.3.5a**, which is not included here.

## Getting started

| Addon | How to open or use it |
| --- | --- |
| RebuffedHealbot | Minimap icon or `…` in the healing frame |
| RebuffedItemLevel | Open your character frame or hover over a player |
| RebuffedRaidMarket | `/raidmarkt`, `/rrm` or the minimap icon; `/raidpost` opens your own ad |
| RebuffedUpgrade | Hover over equipment; `/upgrade` shows the active rating scale |

Each addon has its own README with settings and limitations. These addons target the original 3.3.5a client. Retail and newer Classic clients are not supported. Differences in server APIs may affect individual features.

## Reporting bugs

Include the addon name, its version and the steps needed to reproduce the problem. The client language, other involved addons and the Lua error message are also useful. For a misclassified chat ad, include the message with player names removed.

This repository contains addon files and documentation. Saved character data and other installed addons are not included.
