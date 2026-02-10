class_name GeoUtils

static func point_in_polygon_latlon(lat: float, lng: float, polygon: Array) -> bool:
	var inside = false
	var j = polygon.size() - 1
	for i in range(polygon.size()):
		var xi = polygon[i][0]
		var yi = polygon[i][1]
		var xj = polygon[j][0]
		var yj = polygon[j][1]
		var intersect = ((yi > lat) != (yj > lat)) and (lng < (xj - xi) * (lat - yi) / (yj - yi) + xi)
		if intersect:
			inside = !inside
		j = i
	return inside

static func haversine_distance(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
	var R = 6371000.0
	var phi1 = deg_to_rad(lat1)
	var phi2 = deg_to_rad(lat2)
	var delta_phi = deg_to_rad(lat2 - lat1)
	var delta_lambda = deg_to_rad(lng2 - lng1)
	var a = sin(delta_phi / 2.0) * sin(delta_phi / 2.0) + \
			cos(phi1) * cos(phi2) * \
			sin(delta_lambda / 2.0) * sin(delta_lambda / 2.0)
	var c = 2.0 * atan2(sqrt(a), sqrt(1.0 - a))
	return R * c

static func detect_country(lat: float, lng: float, geometries: Dictionary) -> String:
	for country_code in geometries.keys():
		var geometry = geometries[country_code]
		if geometry["type"] == "Polygon":
			if point_in_polygon_latlon(lat, lng, geometry["coordinates"][0]):
				return country_code
		elif geometry["type"] == "MultiPolygon":
			for polygon in geometry["coordinates"]:
				if point_in_polygon_latlon(lat, lng, polygon[0]):
					return country_code
	return "UNKNOWN"
