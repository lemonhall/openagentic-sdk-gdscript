extends RefCounted

const PASTEL_COLORS: Array[Color] = [
	Color(0.98, 0.80, 0.82, 0.35), # pink
	Color(0.80, 0.92, 0.98, 0.35), # blue
	Color(0.86, 0.98, 0.84, 0.35), # mint
	Color(0.99, 0.93, 0.77, 0.35), # peach
	Color(0.88, 0.83, 0.98, 0.35), # lavender
	Color(0.82, 0.98, 0.96, 0.35), # aqua
]

static func color_for_index(color_index: int) -> Color:
	return PASTEL_COLORS[wrapi(color_index, 0, PASTEL_COLORS.size())]

