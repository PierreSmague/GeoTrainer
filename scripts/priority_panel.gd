extends PanelContainer

const STATS_FILE := "user://stats_detailed.json"

@onready var title_label: Label = $Priorities/Title
@onready var priority_list: VBoxContainer = $Priorities/ScrollContainer/PriorityList
@onready var priority_engine := DeterminePriorities.new()

var priorities: Array = []
var country_names = {
	"us": "United States", "ca": "Canada", "mx": "Mexico", "br": "Brazil", "ar": "Argentina",
	"cl": "Chile", "pe": "Peru", "co": "Colombia", "ec": "Ecuador", "bo": "Bolivia",
	"gb": "United Kingdom", "fr": "France", "de": "Germany", "es": "Spain", "it": "Italy",
	"nl": "Netherlands", "be": "Belgium", "ch": "Switzerland", "at": "Austria", "pl": "Poland",
	"cz": "Czech Republic", "se": "Sweden", "no": "Norway", "fi": "Finland", "dk": "Denmark",
	"ru": "Russia", "ua": "Ukraine", "ro": "Romania", "gr": "Greece", "pt": "Portugal",
	"au": "Australia", "nz": "New Zealand", "jp": "Japan", "cn": "China", "kr": "South Korea",
	"th": "Thailand", "vn": "Vietnam", "my": "Malaysia", "sg": "Singapore", "id": "Indonesia",
	"ph": "Philippines", "in": "India", "bd": "Bangladesh", "pk": "Pakistan", "lk": "Sri Lanka",
	"za": "South Africa", "ke": "Kenya", "ma": "Morocco", "eg": "Egypt", "tn": "Tunisia",
	"tr": "Turkey", "il": "Israel", "jo": "Jordan", "ae": "UAE", "sa": "Saudi Arabia",
	"is": "Iceland", "ie": "Ireland", "rs": "Serbia", "hr": "Croatia", "si": "Slovenia",
	"sk": "Slovakia", "hu": "Hungary", "bg": "Bulgaria", "ee": "Estonia", "lv": "Latvia",
	"lt": "Lithuania", "by": "Belarus", "md": "Moldova", "al": "Albania", "mk": "North Macedonia",
	"ba": "Bosnia and Herzegovina", "me": "Montenegro", "xk": "Kosovo", "cy": "Cyprus",
	"mt": "Malta", "tw": "Taiwan", "hk": "Hong Kong", "mo": "Macau", "mn": "Mongolia",
	"kz": "Kazakhstan", "uz": "Uzbekistan", "kg": "Kyrgyzstan", "tj": "Tajikistan",
	"tm": "Turkmenistan", "af": "Afghanistan", "ir": "Iran", "iq": "Iraq", "sy": "Syria",
	"lb": "Lebanon", "ye": "Yemen", "om": "Oman", "kw": "Kuwait", "bh": "Bahrain", "qa": "Qatar",
	"np": "Nepal", "bt": "Bhutan", "mm": "Myanmar", "la": "Laos", "kh": "Cambodia", "bn": "Brunei",
	"tl": "Timor-Leste", "pg": "Papua New Guinea", "sn": "Senegal", "gh": "Ghana", "ng": "Nigeria",
	"ug": "Uganda", "tz": "Tanzania", "rw": "Rwanda", "et": "Ethiopia", "so": "Somalia",
	"dj": "Djibouti", "mw": "Malawi", "zm": "Zambia", "zw": "Zimbabwe", "bw": "Botswana",
	"na": "Namibia", "ao": "Angola", "mz": "Mozambique", "mg": "Madagascar", "uy": "Uruguay",
	"py": "Paraguay", "ve": "Venezuela", "sr": "Suriname", "gy": "Guyana", "gf": "French Guiana",
	"gt": "Guatemala", "hn": "Honduras", "sv": "El Salvador", "ni": "Nicaragua", "cr": "Costa Rica",
	"pa": "Panama", "cu": "Cuba", "do": "Dominican Republic", "jm": "Jamaica", "bs": "Bahamas",
	"sz": "Eswatini"
}

func _ready():
	_load_and_compute()

func _refresh():
	_load_and_compute()


func _load_and_compute():
	priorities = priority_engine.load_and_compute()
	_display_priorities()
	

# ============================================================
# UI DISPLAY (SCROLLABLE)
# ============================================================
func _display_priorities():
	for child in priority_list.get_children():
		child.queue_free()

	var rank := 1

	for p in priorities:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		var rank_label = Label.new()
		rank_label.text = "%d." % rank
		rank_label.custom_minimum_size.x = 30
		row.add_child(rank_label)

		var country_name :String= p.country.to_lower()
		if country_names.has(country_name):
			country_name = country_names[p.country.to_lower()]

		var desc_label = Label.new()
		desc_label.text = "%s – %s" % [p.type, country_name]
		desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(desc_label)

		var score_label = Label.new()
		score_label.text = str(p.score)
		score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		score_label.custom_minimum_size.x = 70
		row.add_child(score_label)

		priority_list.add_child(row)
		rank += 1
