extends Control
## Stage-C: help, grade, high score, menu; score formula aligned to configService.

const INIT_LIFE := 3
const INIT_MONEY := 100
const ROUND_TIME := 30.0
const PRODUCTS := [
	{"name": "源石锭礼包", "kind": "money", "cost": 20, "value": 30},
	{"name": "高价零食", "kind": "money", "cost": 35, "value": 25},
	{"name": "神秘折扣券", "kind": "money", "cost": 15, "value": 40},
	{"name": "危险实验", "kind": "life", "cost": 0, "value": 50},
	{"name": "陷阱盲盒", "kind": "life", "cost": 10, "value": 60},
	{"name": "安全理财", "kind": "money", "cost": 25, "value": 35},
]

@onready var _hud: Label = $UI/HUD
@onready var _card: Label = $Center/VBox/Card
@onready var _buy: Button = $Center/VBox/Buy
@onready var _skip: Button = $Center/VBox/Skip
@onready var _overlay: ColorRect = $UI/Overlay
@onready var _over_msg: Label = $UI/Overlay/VBox/Msg
@onready var _retry: Button = $UI/Overlay/VBox/Retry

var _life: int = INIT_LIFE
var _money: int = INIT_MONEY
var _score: int = 0
var _buys: int = 0
var _time_left: float = ROUND_TIME
var _alive: bool = false
var _in_menu: bool = true
var _product: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _menu: ColorRect
var _to_menu: Button
var _help: Button

func _ready() -> void:
	_rng.randomize()
	_buy.pressed.connect(_on_buy)
	_skip.pressed.connect(_on_skip)
	_retry.pressed.connect(_restart_play)
	_build_shell()
	_show_menu()

func _build_shell() -> void:
	_menu = ColorRect.new()
	_menu.color = Color(0.12, 0.1, 0.14, 1)
	_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_CENTER)
	vb.offset_left = -150
	vb.offset_top = -170
	vb.offset_right = 150
	vb.offset_bottom = 170
	vb.add_theme_constant_override("separation", 10)
	var title := Label.new()
	title.text = "谋财害命"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.75, 0.35))
	vb.add_child(title)
	var hi := Label.new()
	hi.name = "High"
	hi.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(hi)
	var start := Button.new()
	start.text = "开始游戏"
	start.custom_minimum_size = Vector2(260, 44)
	start.pressed.connect(_begin)
	vb.add_child(start)
	var help := Label.new()
	help.text = "谋财：花钱换分（钱越多加成越高）\n害命：扣命换分（命越少加成越高）\n30 秒或命尽结算，评级 S–D"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 12)
	vb.add_child(help)
	_menu.add_child(vb)
	$UI.add_child(_menu)
	_to_menu = Button.new()
	_to_menu.text = "返回菜单"
	_to_menu.pressed.connect(_show_menu)
	$UI/Overlay/VBox.add_child(_to_menu)
	_help = Button.new()
	_help.text = "规则"
	_help.position = Vector2(280, 8)
	_help.size = Vector2(70, 28)
	_help.pressed.connect(_show_help)
	$UI.add_child(_help)

func _show_help() -> void:
	if _in_menu:
		return
	_card.text = "规则速览\n谋财扣源石锭，害命扣生命\n跳过可换下一件商品"

func _show_menu() -> void:
	_alive = false
	_in_menu = true
	_overlay.visible = false
	_menu.visible = true
	$Center.visible = false
	_help.visible = false
	(_menu.get_node("VBoxContainer/High") as Label).text = "最高分 %d" % SaveData.high_score
	_hud.text = "谋财害命"

func _begin() -> void:
	_in_menu = false
	_menu.visible = false
	$Center.visible = true
	_help.visible = true
	_restart_play()

func _restart_play() -> void:
	_life = INIT_LIFE
	_money = INIT_MONEY
	_score = 0
	_buys = 0
	_time_left = ROUND_TIME
	_alive = true
	_overlay.visible = false
	_buy.disabled = false
	_skip.disabled = false
	_roll_product()
	_update_ui()

func _process(delta: float) -> void:
	if not _alive or _in_menu:
		return
	_time_left -= delta
	_update_ui()
	if _time_left <= 0.0:
		_end("时间到")

func _roll_product() -> void:
	_product = PRODUCTS[_rng.randi_range(0, PRODUCTS.size() - 1)].duplicate()

func _product_score(value: int, kind: String) -> int:
	if kind == "money":
		return value + int(_money / 10)
	return value + (INIT_LIFE - _life) * 5

func _grade(score: int) -> String:
	if score >= 400:
		return "S"
	if score >= 280:
		return "A"
	if score >= 180:
		return "B"
	if score >= 100:
		return "C"
	return "D"

func _update_ui() -> void:
	_hud.text = "生命 %d  源石锭 %d\n得分 %d  最高 %d  已购 %d\n倒计时 %.1fs" % [
		_life, _money, _score, SaveData.high_score, _buys, maxf(0.0, _time_left)
	]
	var kind: String = str(_product.get("kind", "money"))
	var tip := "谋财（扣钱）" if kind == "money" else "害命（扣生命）"
	_card.text = "%s\n%s\n花费 %d · 基础价值 %d" % [
		str(_product.get("name", "")), tip, int(_product.get("cost", 0)), int(_product.get("value", 0))
	]

func _on_buy() -> void:
	if not _alive or _in_menu:
		return
	var kind: String = str(_product.get("kind", "money"))
	var cost: int = int(_product.get("cost", 0))
	var value: int = int(_product.get("value", 0))
	if kind == "money":
		if _money < cost:
			return
		_money -= cost
		_score += _product_score(value, kind)
	else:
		_life -= 1
		_money = maxi(0, _money - cost)
		_score += _product_score(value, kind)
	_buys += 1
	if _life <= 0:
		_end("生命耗尽")
		return
	_roll_product()
	_update_ui()

func _on_skip() -> void:
	if not _alive or _in_menu:
		return
	_roll_product()
	_update_ui()

func _end(reason: String) -> void:
	_alive = false
	_buy.disabled = true
	_skip.disabled = true
	var g := _grade(_score)
	var best: int = SaveData.record(_score)
	_over_msg.text = "%s\n评级 %s\n总分 %d · 购买 %d\n最高 %d" % [reason, g, _score, _buys, best]
	_overlay.visible = true
