extends Node
## StoryDB — every spoken line in the game plus the rules for when it fires.
##
## ╔═══════════════════════════════════════════════════════════════════════╗
## ║  ADDING DIALOG                                                        ║
## ║  1. Append one dict to SCENES (below). That's it.                     ║
## ║  2. New character? Append one dict to VOICES and use its key as `who`. ║
## ╚═══════════════════════════════════════════════════════════════════════╝
##
## A scene looks like this:
##
##   {
##     "id": "death_3",                 # unique; remembered in Global.story_seen
##     "at": "death",                   # death | menu_open | shop_open | run_start
##     "when": {"deaths_at": [3]},      # all keys must pass (see _matches below)
##     "mode": "black",                 # black = full lore cut, scrim = over live scene
##     "blocks": [                      # one tap per block
##       {"who": "narrator", "text": "Three deaths. You are improving."},
##       {"who": "soul",     "text": "he counts wrong on purpose"},
##     ],
##   }
##
## Condition keys understood by "when" (every key is optional, all are AND-ed):
##   deaths_at: [3, 5]            exact death counts
##   deaths_at_least: 10          death count floor
##   distance_at_least: 400       metres reached in the run that just ended
##   best_at_least: 900           best distance ever
##   purchased: "procgen"         that skill is owned (fires the next trigger)
##   not_purchased: "coins"       that skill is NOT owned
##   requires_unlocked: "ui"      feature key is unlocked
##   not_unlocked: "ui"           feature key is not unlocked
##   days_away_at_least: 2.0      real days since the previous session
##   unspent_tokens_at_least: 15  hoarding check
##
## Extra scene keys: "once" (default true), "priority" (higher wins ties).

const FONT_TERMINUS := preload("res://assets/fonts/Terminus.ttf")
const FONT_KA1      := preload("res://assets/fonts/ka1.ttf")
const FONT_JUICE    := preload("res://assets/fonts/orange juice 2.0.ttf")
const FONT_NERVOUS  := preload("res://assets/fonts/Nervous.ttf")
const FONT_NASA     := preload("res://assets/fonts/nasalization-rg.ttf")

## ─── THE CAST ───────────────────────────────────────────────────────────
## fx_open/fx_close are BBCode — story_cut.gd renders bodies in a
## RichTextLabel, so [shake]/[wave]/[pulse] work out of the box.
const VOICES := {
	"narrator": {
		"name": "NARRATOR", "font": FONT_TERMINUS, "size": 30,
		"color": Color(0.87, 0.86, 0.83),
		"fx_open": "", "fx_close": "",
		"speed": 0.032, "tick_db": -10.0,
	},
	"purple": {
		"name": "???", "font": FONT_KA1, "size": 42,
		"color": Color(0.60, 0.15, 0.90),
		"fx_open": "[shake rate=18.0 level=6]", "fx_close": "[/shake]",
		"speed": 0.055, "tick_db": -4.0, "upper": true, "glitch": true,
	},
	"princess": {
		"name": "THE PINK ONE", "font": FONT_JUICE, "size": 40,
		"color": Color(1.00, 0.56, 0.82),
		"fx_open": "[wave amp=22.0 freq=4.0]", "fx_close": "[/wave]",
		"speed": 0.030, "tick_db": -13.0,
	},
	"soul": {
		"name": "· · ·", "font": FONT_NERVOUS, "size": 26,
		"color": Color(0.44, 0.85, 0.82),
		"fx_open": "[pulse freq=1.0 color=#6fd9d055]", "fx_close": "[/pulse]",
		"speed": 0.070, "tick_db": -17.0, "lower": true,
	},
	"sponsor": {
		"name": "A WORD FROM OUR SPONSOR", "font": FONT_NASA, "size": 25,
		"color": Color(0.31, 0.88, 1.00),
		"fx_open": "", "fx_close": "",
		"speed": 0.024, "tick_db": -9.0, "upper": true,
	},
	"system": {
		"name": "", "font": FONT_TERMINUS, "size": 19,
		"color": Color(0.42, 0.42, 0.47),
		"fx_open": "", "fx_close": "",
		# [lb] is the BBCode escape for a literal "[" — a bare one would be
		# parsed as an (unknown) tag and swallowed.
		"speed": 0.010, "tick_db": -20.0, "prefix": "[lb] ", "suffix": " ]",
	},
}

func voice(who: String) -> Dictionary:
	return VOICES.get(who, VOICES["narrator"])


## ─── SCENES ─────────────────────────────────────────────────────────────
## `at: "guide"` scenes never auto-fire; onboarding.gd requests them by id.
const SCENES: Array = [

# ══ INTRO COLD OPEN ═══════════════════════════════════════════════════════
{
	"id": "intro_cold_open", "at": "guide", "mode": "black",
	"blocks": [
		{"who": "sponsor",  "text": "Welcome to your new platformer! Fully featured. Feature-complete. Complete with features."},
		{"who": "sponsor",  "text": "Please enjoy responsibly. Terms apply. Terms are not available."},
		{"who": "princess", "text": "oh! oh, a new one! hello! nobody tell it what happened to the last one"},
		{"who": "narrator", "text": "Nothing happened to the last one."},
		{"who": "soul",     "text": "something happened to the last one"},
		{"who": "narrator", "text": "Ignore that. It leaks in through the save file. Harmless."},
		{"who": "purple",   "text": "I am not harmless."},
		{"who": "system",   "text": "sponsor disconnected"},
	],
},

# ══ GUIDED ONBOARDING ═════════════════════════════════════════════════════
{
	"id": "guide_buy_ui", "at": "guide", "mode": "scrim",
	"blocks": [
		{"who": "narrator", "text": "Right. It took the game and left you the physics. Generous, technically."},
		{"who": "narrator", "text": "You died, so you were paid. That is the entire economy. Dying is the job."},
		{"who": "purple",   "text": "You cannot buy back what is mine."},
		{"who": "narrator", "text": "You can, actually. It kept the receipts. Start with the interface — you'll want menus before you want anything nice."},
	],
},
{
	"id": "guide_menu", "at": "guide", "mode": "scrim",
	"blocks": [
		{"who": "narrator", "text": "Congratulations. You now own a menu. Some people own houses."},
		{"who": "princess", "text": "a MENU! it has BUTTONS! i'm so proud of you, little runner"},
		{"who": "narrator", "text": "Everything else lives in the Shop. Tokens in, world out. Go on."},
	],
},
{
	"id": "guide_shop_intro", "at": "guide", "mode": "scrim",
	"blocks": [
		{"who": "narrator", "text": "This is the tree. Every branch is something that used to be here for free."},
		{"who": "sponsor",  "text": "MONETIZE YOUR SUFFERING! Tokens are earned exclusively through failure. No purchase necessary. No purchase possible."},
		{"who": "narrator", "text": "It isn't a real sponsor. It just found the ad slot and moved in."},
	],
},
{
	"id": "guide_procgen", "at": "guide", "mode": "scrim",
	"blocks": [
		{"who": "narrator", "text": "Buy the level generator first. I'll be honest with you, which I try to ration."},
		{"who": "narrator", "text": "Right now there is one level. One. You have already seen all of it, and it has seen all of you."},
		{"who": "purple",   "text": "I left you the flat part. Be grateful."},
		{"who": "soul",     "text": "he ran the flat part four thousand times. ask him."},
		{"who": "narrator", "text": "Procedural generation, then. New ground every run. Farther runs pay more. Greed is the tutorial."},
	],
},
{
	"id": "guide_enemies", "at": "guide", "mode": "scrim",
	"blocks": [
		{"who": "narrator", "text": "Now buy the enemies. Yes, on purpose. Yes, they kill you."},
		{"who": "narrator", "text": "Every tier of enemy in the world pays twenty percent more per token. The danger is the interest rate."},
		{"who": "princess", "text": "they're not MEAN, they just don't have anywhere else to be!"},
		{"who": "purple",   "text": "They work for me."},
		{"who": "narrator", "text": "They work for the payout multiplier. So do you. Tap the node."},
	],
},

# ══ DEATH-COUNT MILESTONES ════════════════════════════════════════════════
{
	"id": "death_3", "at": "death", "mode": "black",
	"when": {"deaths_at": [3]},
	"blocks": [
		{"who": "narrator", "text": "Three deaths. Statistically, that is a trend."},
		{"who": "princess", "text": "or a HOBBY! some people collect stamps"},
	],
},
{
	"id": "death_5", "at": "death", "mode": "black",
	"when": {"deaths_at": [5]},
	"blocks": [
		{"who": "purple",   "text": "Five. I have stopped watching. It replays them for me."},
		{"who": "narrator", "text": "I do not replay them. I file them. There is a difference and it is my whole personality."},
	],
},
{
	"id": "death_7", "at": "death", "mode": "black",
	"when": {"deaths_at": [7]},
	"blocks": [
		{"who": "narrator", "text": "Seven. Lucky number. Not here. Here it is just seven."},
		{"who": "soul",     "text": "he told the last one it was lucky"},
		{"who": "narrator", "text": "The last one had different circumstances."},
		{"who": "soul",     "text": "the last one had the same circumstances"},
	],
},
{
	"id": "death_10", "at": "death", "mode": "black",
	"when": {"deaths_at": [10]},
	"blocks": [
		{"who": "sponsor",  "text": "TEN DEATHS! You have unlocked: nothing. But you have unlocked it TEN TIMES."},
		{"who": "narrator", "text": "Round numbers bring it out. Like a fly to a window."},
		{"who": "princess", "text": "double digits!! i baked something. i can't give it to you. i can't reach"},
	],
},
{
	"id": "death_15", "at": "death", "mode": "black",
	"when": {"deaths_at": [15]},
	"blocks": [
		{"who": "purple",   "text": "Fifteen. You are wearing a groove in my floor."},
		{"who": "narrator", "text": "It is not its floor. It is a rented asset. I have said this."},
		{"who": "purple",   "text": "The rent is you."},
	],
},
{
	"id": "death_21", "at": "death", "mode": "black",
	"when": {"deaths_at": [21]},
	"blocks": [
		{"who": "narrator", "text": "Twenty-one. You are legally an adult in most of this level."},
		{"who": "princess", "text": "he's so proud of that one. he's been saving it since eleven"},
		{"who": "narrator", "text": "I was not saving it."},
	],
},
{
	"id": "death_30", "at": "death", "mode": "black",
	"when": {"deaths_at": [30]},
	"blocks": [
		{"who": "narrator", "text": "Thirty. At this point the deaths are the content and the running is the loading screen."},
		{"who": "soul",     "text": "he says that to everyone. he said it to me. i believed it"},
		{"who": "purple",   "text": "Quiet."},
		{"who": "system",   "text": "one voice removed from the transcript"},
	],
},
{
	"id": "death_50", "at": "death", "mode": "black",
	"when": {"deaths_at": [50]},
	"blocks": [
		{"who": "purple",   "text": "Fifty. I have never had to work this little."},
		{"who": "narrator", "text": "Fifty deaths is, and I want to be precise, a lot of deaths."},
		{"who": "princess", "text": "i've stopped counting. i lied. i haven't. it's fifty"},
	],
},
{
	"id": "death_100", "at": "death", "mode": "black",
	"when": {"deaths_at": [100]},
	"blocks": [
		{"who": "system",   "text": "death 100"},
		{"who": "narrator", "text": "A hundred. I would like to say something cutting here. I have run out."},
		{"who": "purple",   "text": "You outlasted its material. That has happened once before."},
		{"who": "soul",     "text": "that was me. i outlasted the material. this is what's left"},
		{"who": "princess", "text": "...keep going, little runner. genuinely. i mean it this once"},
	],
},

# ══ DISTANCE MILESTONES ═══════════════════════════════════════════════════
{
	"id": "dist_250", "at": "death", "mode": "black",
	"when": {"distance_at_least": 250},
	"blocks": [
		{"who": "narrator", "text": "You got some distance in. The far parts are less finished. Try not to look directly at them."},
	],
},
{
	"id": "dist_600", "at": "death", "mode": "black",
	"when": {"distance_at_least": 600},
	"blocks": [
		{"who": "princess", "text": "you went PAST the bit i live in! nobody goes past the bit i live in"},
		{"who": "narrator", "text": "There is no bit it lives in. It is a text style."},
		{"who": "princess", "text": "rude. accurate. rude"},
	],
},
{
	"id": "dist_1200", "at": "death", "mode": "black",
	"when": {"distance_at_least": 1200},
	"blocks": [
		{"who": "purple",   "text": "Far. Too far. I did not build past here."},
		{"who": "narrator", "text": "It did not build any of it. It found it. Like a hermit crab with opinions."},
		{"who": "soul",     "text": "keep going. there's an edge. i'd like someone to see it"},
	],
},

# ══ KEY-SKILL PURCHASES ═══════════════════════════════════════════════════
{
	"id": "buy_procgen", "at": "shop_open", "mode": "black",
	"when": {"purchased": "procgen"},
	"blocks": [
		{"who": "purple",   "text": "You put the ground back. I removed that personally."},
		{"who": "narrator", "text": "It removed it by unplugging one node. It talks about it like heavy labour."},
		{"who": "princess", "text": "there's SO MUCH of it now. it just keeps happening!"},
	],
},
{
	"id": "buy_enemies", "at": "shop_open", "mode": "black",
	"when": {"purchased": "enemies_basic"},
	"blocks": [
		{"who": "purple",   "text": "You bought my staff back. With my money."},
		{"who": "narrator", "text": "Technically your money. Earned by dying. It is a closed loop and everyone in it is tired."},
		{"who": "soul",     "text": "the loop isn't closed. i got out. this is out"},
	],
},
{
	"id": "buy_coins", "at": "shop_open", "mode": "black",
	"when": {"purchased": "coins"},
	"blocks": [
		{"who": "sponsor",  "text": "CURRENCY RESTORED! Shiny objects now spawn in the world. Collect them. Do not ask where they come from."},
		{"who": "purple",   "text": "They come from me."},
		{"who": "narrator", "text": "They come from a spawn table. Everyone here is very dramatic about arrays."},
	],
},
{
	"id": "buy_leaderboard", "at": "shop_open", "mode": "black",
	"when": {"purchased": "leaderboard"},
	"blocks": [
		{"who": "narrator", "text": "You bought the leaderboard. Now strangers can see exactly how you're doing."},
		{"who": "princess", "text": "other people?? other people exist?? put me on it. put my name on it"},
		{"who": "purple",   "text": "Rebuild it all if you like. I only ever needed the part that keeps score."},
	],
},

# ══ IDLE / RETURN / HOARDING ══════════════════════════════════════════════
{
	"id": "return_gap", "at": "run_start", "mode": "black", "once": false,
	"when": {"days_away_at_least": 2.0},
	"blocks": [
		{"who": "narrator", "text": "Oh. You're back. No, it's fine. I kept everything exactly where you left it, because I can't move."},
		{"who": "princess", "text": "I MISSED YOU. he did too. he arranged the tiles"},
		{"who": "narrator", "text": "I did not arrange the tiles."},
	],
},
{
	"id": "hoard_tokens", "at": "shop_open", "mode": "scrim", "once": false,
	"when": {"unspent_tokens_at_least": 20},
	"blocks": [
		{"who": "narrator", "text": "That is a substantial pile of tokens you are not spending. No pressure. It's only the world."},
		{"who": "sponsor",  "text": "SAVING IS A VALID STRATEGY! Saving is also how the last one ended. But it is VALID!"},
	],
},
{
	# Nudge toward the shop once there's real money on the table. Low priority so a
	# death-count milestone always wins the slot, and once=false so it can come back
	# in a later session if the tokens are still sitting there.
	"id": "spend_reminder", "at": "death", "mode": "scrim", "once": false,
	"priority": -5,
	"when": {"unspent_tokens_at_least": 10, "requires_unlocked": "ui",
		"no_guide_pending": true},
	"blocks": [
		{"who": "narrator", "text": "You are carrying ten tokens around a world that does not have a shop in it yet, because you haven't been to the shop."},
		{"who": "princess", "text": "SPEND THEM! spend them on something SILLY! spend them on ME"},
		{"who": "narrator", "text": "The Shop button is on this screen. It has been on this screen the whole time."},
	],
},

# ══ POLISH GUIDE (SECOND PASS) ════════════════════════════════════════════
# Requested by id from onboarding.gd's phase-2 runners, never auto-fired.
{
	"id": "guide2_intro", "at": "guide", "mode": "scrim",
	"blocks": [
		{"who": "narrator", "text": "You have money now. Quite a lot of it, for someone whose only income is dying."},
		{"who": "purple",   "text": "It runs. It lands. It is not pleasant to look at."},
		{"who": "narrator", "text": "He means the game has no feel. Everything moves, nothing lands. Let's fix that part."},
		{"who": "narrator", "text": "Shop. I'll point."},
	],
},
{
	"id": "guide2_shop", "at": "guide", "mode": "scrim",
	"blocks": [
		{"who": "narrator", "text": "Squash and stretch, a sprite that isn't a rectangle, and a menu that isn't an apology."},
		{"who": "sponsor",  "text": "POLISH IS NOT COSMETIC! Polish is how the player knows the thing happened! That one is FREE ADVICE and I regret it!"},
		{"who": "narrator", "text": "It's right, irritatingly. Buy them in the order I point."},
	],
},

]

## ─── MATCHING ───────────────────────────────────────────────────────────
## Scenes with once=true are remembered forever in Global.story_seen.
## Scenes with once=false fire at most once per app session.
var _session_seen: Dictionary = {}

func scene_by_id(id: String) -> Dictionary:
	for s in SCENES:
		if String(s.get("id", "")) == id:
			return s
	push_warning("[StoryDB] no scene with id '%s'" % id)
	return {}

## First unseen scene whose conditions pass for this trigger point, else {}.
## Trigger points: "death", "menu_open", "shop_open", "run_start".
func pending(at: String) -> Dictionary:
	# The guided onboarding owns the screen while it runs — never talk over it.
	var ob = get_node_or_null("/root/Onboarding")
	if ob and ob.has_method("is_active") and ob.is_active():
		return {}
	var best: Dictionary = {}
	var best_priority := -9999
	for s in SCENES:
		if String(s.get("at", "")) != at: continue
		if is_seen(String(s.get("id", ""))): continue
		if not _matches(s.get("when", {})): continue
		var p := int(s.get("priority", 0))
		if p > best_priority:
			best_priority = p
			best = s
	return best

func is_seen(id: String) -> bool:
	if id == "": return true
	if _session_seen.has(id): return true
	return bool(Global.story_seen.get(id, false))

func mark_seen(scene: Dictionary) -> void:
	var id := String(scene.get("id", ""))
	if id == "": return
	if bool(scene.get("once", true)):
		Global.story_seen[id] = true
		Global.save_state()
	else:
		_session_seen[id] = true

func _skills() -> Node:
	return get_node_or_null("/root/SkillsDB")

func _deaths() -> int:
	return int(Global.stats.get("deaths", 0))

func _purchased(sid: String) -> bool:
	var sk := _skills()
	if sk and sk.has_method("is_purchased"):
		return bool(sk.is_purchased(sid))
	return bool(Global.unlocked.get(sid, false))

## True when a guide is unfinished, or the polish guide is armed with something it
## can actually point at — i.e. the finger is about to speak on this very screen.
## Reminders stand down rather than double up.
func _guide_pending() -> bool:
	var ob = get_node_or_null("/root/Onboarding")
	if ob == null: return false
	if ob.has_method("is_done") and not ob.is_done(): return true
	if ob.has_method("phase2_ready") and ob.phase2_ready(): return true
	return false

func _matches(when: Dictionary) -> bool:
	for key in when.keys():
		var want = when[key]
		match key:
			"deaths_at":
				if not (_deaths() in want): return false
			"deaths_at_least":
				if _deaths() < int(want): return false
			"distance_at_least":
				if Global.last_run_distance < int(want): return false
			"best_at_least":
				if Global.best_distance < int(want): return false
			"purchased":
				if not _purchased(String(want)): return false
			"not_purchased":
				if _purchased(String(want)): return false
			"requires_unlocked":
				if not Global.is_unlocked(String(want)): return false
			"not_unlocked":
				if Global.is_unlocked(String(want)): return false
			"days_away_at_least":
				if Global.session_gap_days < float(want): return false
			"unspent_tokens_at_least":
				if Global.tokens < int(want): return false
			"no_guide_pending":
				if bool(want) and _guide_pending(): return false
			_:
				push_warning("[StoryDB] unknown condition key '%s'" % key)
				return false
	return true


## ─── ONE-LINERS ─────────────────────────────────────────────────────────
## Short jabs for the game-over hint line. Not a scene — no tapping, no cut.
const TAUNTS: Array = [
	"The spikes were placed by a professional. Respect the craft.",
	"Gravity remains unpurchased. It works anyway. Enjoy the freebie.",
	"You were doing so well, in a sense, briefly.",
	"That was a decision. Not the one I'd have made, but a decision.",
	"Spend the tokens. Hoarding them is how the last one ended.",
	"Each death funds the world. You are its most reliable donor.",
	"Somewhere a leaderboard is quietly writing this down.",
	"The far parts of the level are unfinished. You will never know.",
	"I could tell you what killed you. It's in the name of the thing.",
	"Try going right. Right is where the tokens live.",
]

const FALL_TAUNTS: Array = [
	"Down is not a direction the design accounted for.",
	"You found the bottom. There is nothing there. That's the joke.",
	"The floor was optional and you opted out.",
]

## cause matches Global.last_death_cause (e.g. "fall", "spike", "enemy").
func taunt(cause: String = "", distance: int = 0, deaths: int = 0) -> String:
	var pool: Array = TAUNTS
	if cause.to_lower().contains("fall"):
		pool = FALL_TAUNTS + TAUNTS
	if deaths > 0 and deaths % 10 == 0:
		return "Death number %d. Round numbers deserve silence." % deaths
	if distance > 0 and distance >= Global.best_distance and Global.best_distance > 0:
		return "A personal best. The bar was on the floor and you cleared it."
	return pool[randi() % pool.size()]

