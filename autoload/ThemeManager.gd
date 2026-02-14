class_name ThemeManager

# ── Palette ──────────────────────────────────────────────────
const BG_MAIN       := Color(0.059, 0.059, 0.102)    # #0F0F1A
const BG_SURFACE    := Color(0.102, 0.102, 0.180)    # #1A1A2E
const BG_SURFACE_ALT:= Color(0.133, 0.133, 0.251)    # #222240
const ACCENT        := Color(0.424, 0.361, 0.906)    # #6C5CE7
const ACCENT_HOVER  := Color(0.545, 0.486, 0.969)    # #8B7CF7
const ACCENT_SEC    := Color(0.0,   0.808, 0.788)    # #00CEC9
const TEXT_PRIMARY   := Color(0.910, 0.910, 0.941)    # #E8E8F0
const TEXT_SECONDARY := Color(0.533, 0.533, 0.667)    # #8888AA
const SUCCESS       := Color(0.180, 0.835, 0.451)    # #2ED573
const ERROR         := Color(1.0,   0.278, 0.341)    # #FF4757
const WARNING       := Color(1.0,   0.647, 0.008)    # #FFA502
const BORDER        := Color(0.2, 0.2, 0.333)        # #333355

static func create_theme() -> Theme:
	var t := Theme.new()

	# ── Default font color ───────────────────────────────────
	t.set_color("font_color", "Label", TEXT_PRIMARY)
	t.set_color("font_color", "Button", TEXT_PRIMARY)
	t.set_color("font_color", "LineEdit", TEXT_PRIMARY)
	t.set_color("font_color", "SpinBox", TEXT_PRIMARY)
	t.set_color("font_color", "OptionButton", TEXT_PRIMARY)
	t.set_color("font_color", "CheckButton", TEXT_PRIMARY)
	t.set_color("font_color", "CheckBox", TEXT_PRIMARY)

	# ── Button ───────────────────────────────────────────────
	t.set_stylebox("normal",  "Button", _btn_normal())
	t.set_stylebox("hover",   "Button", _btn_hover())
	t.set_stylebox("pressed", "Button", _btn_pressed())
	t.set_stylebox("disabled","Button", _btn_disabled())
	t.set_stylebox("focus",   "Button", _btn_focus())
	t.set_color("font_hover_color",    "Button", Color.WHITE)
	t.set_color("font_pressed_color",  "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", TEXT_SECONDARY)

	# ── OptionButton ─────────────────────────────────────────
	t.set_stylebox("normal",  "OptionButton", _btn_normal())
	t.set_stylebox("hover",   "OptionButton", _btn_hover())
	t.set_stylebox("pressed", "OptionButton", _btn_pressed())
	t.set_stylebox("focus",   "OptionButton", _btn_focus())

	# ── LineEdit ─────────────────────────────────────────────
	t.set_stylebox("normal", "LineEdit", _input_normal())
	t.set_stylebox("focus",  "LineEdit", _input_focus())
	t.set_color("font_placeholder_color", "LineEdit", TEXT_SECONDARY)
	t.set_color("caret_color", "LineEdit", ACCENT)

	# ── SpinBox (inherits LineEdit mostly) ───────────────────

	# ── TabContainer ─────────────────────────────────────────
	t.set_stylebox("panel",          "TabContainer", _tab_panel())
	t.set_stylebox("tab_selected",   "TabContainer", _tab_selected())
	t.set_stylebox("tab_unselected", "TabContainer", _tab_unselected())
	t.set_stylebox("tab_hovered",    "TabContainer", _tab_hovered())
	t.set_color("font_selected_color",   "TabContainer", Color.WHITE)
	t.set_color("font_unselected_color", "TabContainer", TEXT_SECONDARY)
	t.set_color("font_hovered_color",    "TabContainer", TEXT_PRIMARY)

	# ── PanelContainer ──────────────────────────────────────
	t.set_stylebox("panel", "PanelContainer", _panel_style())

	# ── PopupPanel ───────────────────────────────────────────
	t.set_stylebox("panel", "PopupPanel", _popup_style())

	# ── AcceptDialog / ConfirmationDialog ────────────────────
	t.set_stylebox("panel", "AcceptDialog", _popup_style())
	t.set_stylebox("panel", "ConfirmationDialog", _popup_style())
	t.set_stylebox("panel", "Window", _popup_style())

	# ── HSlider ──────────────────────────────────────────────
	var slider_bg = StyleBoxFlat.new()
	slider_bg.bg_color = BG_SURFACE_ALT
	slider_bg.corner_radius_top_left = 4
	slider_bg.corner_radius_top_right = 4
	slider_bg.corner_radius_bottom_left = 4
	slider_bg.corner_radius_bottom_right = 4
	slider_bg.content_margin_top = 4
	slider_bg.content_margin_bottom = 4
	t.set_stylebox("slider", "HSlider", slider_bg)

	var grabber_normal = StyleBoxFlat.new()
	grabber_normal.bg_color = ACCENT
	grabber_normal.corner_radius_top_left = 10
	grabber_normal.corner_radius_top_right = 10
	grabber_normal.corner_radius_bottom_left = 10
	grabber_normal.corner_radius_bottom_right = 10
	t.set_stylebox("grabber_area", "HSlider", grabber_normal)

	var grabber_highlight = StyleBoxFlat.new()
	grabber_highlight.bg_color = ACCENT_HOVER
	grabber_highlight.corner_radius_top_left = 10
	grabber_highlight.corner_radius_top_right = 10
	grabber_highlight.corner_radius_bottom_left = 10
	grabber_highlight.corner_radius_bottom_right = 10
	t.set_stylebox("grabber_area_highlight", "HSlider", grabber_highlight)

	# ── HSeparator ───────────────────────────────────────────
	var sep_style = StyleBoxFlat.new()
	sep_style.bg_color = BORDER
	sep_style.content_margin_top = 1
	sep_style.content_margin_bottom = 1
	t.set_stylebox("separator", "HSeparator", sep_style)
	t.set_constant("separation", "HSeparator", 8)

	# ── ScrollContainer ──────────────────────────────────────
	var scroll_bg = StyleBoxFlat.new()
	scroll_bg.bg_color = Color.TRANSPARENT
	t.set_stylebox("panel", "ScrollContainer", scroll_bg)

	return t

# ── StyleBox helpers ─────────────────────────────────────────

static func _rounded(radius: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	return s

static func _btn_normal() -> StyleBoxFlat:
	var s := _rounded(10)
	s.bg_color = BG_SURFACE
	s.border_width_left = 1
	s.border_width_top = 1
	s.border_width_right = 1
	s.border_width_bottom = 1
	s.border_color = BORDER
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s

static func _btn_hover() -> StyleBoxFlat:
	var s := _rounded(10)
	s.bg_color = ACCENT
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s

static func _btn_pressed() -> StyleBoxFlat:
	var s := _rounded(10)
	s.bg_color = ACCENT.darkened(0.15)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s

static func _btn_disabled() -> StyleBoxFlat:
	var s := _rounded(10)
	s.bg_color = BG_SURFACE.darkened(0.3)
	s.border_width_left = 1
	s.border_width_top = 1
	s.border_width_right = 1
	s.border_width_bottom = 1
	s.border_color = BORDER.darkened(0.3)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s

static func _btn_focus() -> StyleBoxFlat:
	var s := _rounded(10)
	s.bg_color = BG_SURFACE
	s.border_width_left = 2
	s.border_width_top = 2
	s.border_width_right = 2
	s.border_width_bottom = 2
	s.border_color = ACCENT
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s

static func _input_normal() -> StyleBoxFlat:
	var s := _rounded(8)
	s.bg_color = BG_SURFACE_ALT
	s.border_width_left = 1
	s.border_width_top = 1
	s.border_width_right = 1
	s.border_width_bottom = 1
	s.border_color = BORDER
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s

static func _input_focus() -> StyleBoxFlat:
	var s := _rounded(8)
	s.bg_color = BG_SURFACE_ALT
	s.border_width_left = 2
	s.border_width_top = 2
	s.border_width_right = 2
	s.border_width_bottom = 2
	s.border_color = ACCENT
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s

static func _tab_panel() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = BG_MAIN
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s

static func _tab_selected() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = ACCENT
	s.corner_radius_top_left = 10
	s.corner_radius_top_right = 10
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s

static func _tab_unselected() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = BG_SURFACE
	s.corner_radius_top_left = 10
	s.corner_radius_top_right = 10
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s

static func _tab_hovered() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = BG_SURFACE_ALT
	s.corner_radius_top_left = 10
	s.corner_radius_top_right = 10
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s

static func _panel_style() -> StyleBoxFlat:
	var s := _rounded(12)
	s.bg_color = BG_SURFACE
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s

static func _popup_style() -> StyleBoxFlat:
	var s := _rounded(12)
	s.bg_color = BG_SURFACE
	s.border_width_left = 1
	s.border_width_top = 1
	s.border_width_right = 1
	s.border_width_bottom = 1
	s.border_color = BORDER
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 16
	s.content_margin_bottom = 16
	return s
