# RebuffedRaidMarket

RebuffedRaidMarket collects raid recruitment and trade messages from a chat source you choose. The window groups raid ads by raid name and trade ads into buying and selling sections. Clicking an ad opens a whisper draft addressed to its author.

The current window labels are German: **Kaufen** means buying, **Verkaufen** means selling, and **Eigene Anzeige** opens your own ad.

## Choosing a chat source

Open the window through the minimap icon, `/raidmarkt` or `/rrm`. Enter the channel name or number at the top. The default is `world`. Guild, party, raid and say chat are also supported, for example `g`, `p`, `raid` or `s`.

The addon does not join channels for you. It only records new messages from the selected source. The list starts empty after `/reload` or a channel change.

Classification uses German and English keywords. Ads mentioning several raids appear in each relevant section. Messages expire after 15 minutes, and the list holds up to 300 entries. Repeated ads refresh their timestamp.

Raid markers such as `{star}` and `{rt1}` are shown as icons. Hover over item links to see their tooltips. Hold the left mouse button and drag to move the minimap icon.

## Posting your own ad

**Eigene Anzeige** or `/raidpost` opens the draft. Choose LFM or LFG, your class or specialization, your role and the raids you want. You can select several raids and set the size and difficulty for each one. **Beliebig** means any and omits that detail from the message.

GearScore comes from RebuffedItemLevel and is rounded to one decimal place in thousands, for example `3.6k GS`. RebuffedItemLevel must be enabled and have a valid value for posting to work.

Generated messages are in English. Known German class names, specializations and extra details are translated. Text fields only accept recognized terms. Unknown words prevent posting until you change them; this is not a general text translation service.

**Start** sends the ad immediately to the selected chat, then every five minutes. Posting stops when you join a party or raid, or press **Stopp**. LFM ads can also only be started while ungrouped. Closing the window does not stop posting.

Editing the draft or changing the channel stops the running ad. After `/reload`, restarting the game or leaving a group, you must start it manually. Drafts are saved per character. Messages longer than 255 bytes are not sent.

## Limitations

Classification depends on message text and may get abbreviations or unusual wording wrong. The addon cannot search earlier chat history or check whether an advertised group still has room. Browsing channel messages does not require any other addons.
