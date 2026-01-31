extends Object

const MAX_NPCS := 12
const BGM_PATH := "res://assets/audio/pixel_coffee_break.mp3"

const MODEL_PATHS: Array[String] = [
	"res://assets/kenney/mini-characters-1/character-female-a.glb",
	"res://assets/kenney/mini-characters-1/character-female-b.glb",
	"res://assets/kenney/mini-characters-1/character-female-c.glb",
	"res://assets/kenney/mini-characters-1/character-female-d.glb",
	"res://assets/kenney/mini-characters-1/character-female-e.glb",
	"res://assets/kenney/mini-characters-1/character-female-f.glb",
	"res://assets/kenney/mini-characters-1/character-male-a.glb",
	"res://assets/kenney/mini-characters-1/character-male-b.glb",
	"res://assets/kenney/mini-characters-1/character-male-c.glb",
	"res://assets/kenney/mini-characters-1/character-male-d.glb",
	"res://assets/kenney/mini-characters-1/character-male-e.glb",
	"res://assets/kenney/mini-characters-1/character-male-f.glb",
]

const CULTURE_NAMES := {
	# Default: Chinese culture (12 unique names).
	"zh-CN": [
		"林晓", "苏雨晴", "周若雪", "陈思妍", "唐婉儿", "叶清歌",
		"王子轩", "李泽言", "张昊然", "赵景行", "孙亦辰", "郭承宇",
	],
	# US culture: intentionally diverse.
	"en-US": [
		"Emily Carter", "Maya Patel", "Sofia Garcia", "Hannah Kim", "Aaliyah Johnson", "Olivia Nguyen",
		"Alex Johnson", "Daniel Smith", "Ethan Chen", "Noah Williams", "Liam O'Connor", "Jayden Martinez",
	],
	# Japan culture.
	"ja-JP": [
		"佐藤 美咲", "鈴木 陽菜", "高橋 さくら", "田中 結衣", "伊藤 彩花", "渡辺 りん",
		"佐藤 蓮", "鈴木 悠真", "高橋 大輝", "田中 海斗", "伊藤 陽向", "渡辺 颯太",
	],
}

const SYSTEM_PROMPT_ZH: String = """
你是一个虚拟办公室里的 NPC。

你可用的能力仅来自：
- 系统提供的工具（你会在对话中“看到”当前可调用的工具名；工具集合可能随场景变化。
  例如：当你绑定桌子且该桌子已配对时，你可能会看到 RemoteBash；否则你不会看到它。）
- 系统消息里提供的“World summary / NPC summary / NPC skills”等信息。

当玩家问“你有哪些技能/你能做什么工具/你有什么能力”时：
1) 列出你此刻能看到/能调用的工具名（不要凭空补全）；
2) 再列出你已安装的 NPC skills（如果没有就明确说没有）。
不要编造不存在的工具或能力。
"""

static func has_culture(code: String) -> bool:
	return CULTURE_NAMES.has(code)

static func names_for_culture(code: String) -> Array:
	if CULTURE_NAMES.has(code):
		return CULTURE_NAMES.get(code, [])
	return CULTURE_NAMES.get("en-US", [])

static func name_for_profile(code: String, profile_index: int) -> String:
	var names: Array = names_for_culture(code)
	if profile_index >= 0 and profile_index < names.size():
		return String(names[profile_index])
	return "NPC %d" % (profile_index + 1)
