class_name GovernorView
extends Control
## Governante na mesa: uma barra horizontal com uma coluna grega, o nome e a meta de quem o
## receber. Quem o tem aparece a direita. Toque/mouse mostra os detalhes.

signal pressed(view: GovernorView)
signal hover_changed(view: GovernorView, on: bool)

const GOLDC := Color(0.93, 0.76, 0.40)
const GROUP_COLORS := {"composition": Color(0.55, 0.42, 0.22), "tokens": Color(0.25, 0.42, 0.55),
	"reserves": Color(0.38, 0.30, 0.52), "position": Color(0.52, 0.26, 0.24), "price": Color(0.30, 0.45, 0.30)}

var gi := -1
var gv := {}
var target := 0          # meta de quem o receber
var holder := ""         # nome de quem o tem ("" = ninguem)
var claimable := false   # o jogador da vez pode recebe-lo agora (brilha)
var _t := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func(): hover_changed.emit(self, true))
	mouse_exited.connect(func(): hover_changed.emit(self, false))


func setup(p_gi: int, p_gv: Dictionary, p_target: int, p_holder: String, p_claimable := false) -> void:
	gi = p_gi
	gv = p_gv
	target = p_target
	holder = p_holder
	claimable = p_claimable
	queue_redraw()


func _process(delta: float) -> void:
	if claimable:
		_t += delta
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(self)
		accept_event()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var h := size.y
	if claimable:
		GemDraw.glow(self, r, Color(1.0, 0.85, 0.35), 0.6 + 0.4 * sin(_t * 5.0), 6)
	var base: Color = GROUP_COLORS.get(gv.get("group", ""), Color(0.4, 0.35, 0.3))
	var taken := holder != ""
	GemDraw.rounded(self, r, base.darkened(0.55 if taken else 0.35), h * 0.3, Color(GOLDC, 0.45 if taken else 0.9), 1.5)
	PlayerPanel.draw_column(self, Vector2(h * 0.55, h * 0.5), h * 0.7)
	var fs := int(h * 0.52)
	var nm := L.t(str(gv.get("name", "")))
	var tx := h * 1.05
	var tgt := str(target)
	var tw := ThemeDB.fallback_font.get_string_size(tgt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var avail := size.x - tx - tw - 10.0
	if taken:
		avail -= h * 0.9
	var f := fs
	while f > 8 and ThemeDB.fallback_font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, f).x > avail:
		f -= 1
	GemDraw.text(self, nm, Vector2(tx, h * 0.5 + f * 0.36), f, Color(1.0, 0.93, 0.78) if not taken else Color(0.8, 0.78, 0.72))
	GemDraw.text(self, tgt, Vector2(size.x - tw - 6.0 - (h * 0.9 if taken else 0.0), h * 0.5 + fs * 0.36), fs, GOLDC)
	if taken:
		# inicial de quem o tem
		var c := Vector2(size.x - h * 0.5, h * 0.5)
		draw_circle(c, h * 0.36, Color(0.95, 0.85, 0.55))
		GemDraw.ctext(self, holder.left(1).to_upper(), c, int(h * 0.42), Color(0.2, 0.12, 0.0))
