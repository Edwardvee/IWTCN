class_name BalanceReport
extends RefCounted
## Resumen legible de los resultados del simulador de equilibrio. Recibe filas
## (Dictionary) con los campos que produce BalanceSim.results_to_rows().


static func summarize(rows: Array[Dictionary], profiles: Array[StringName]) -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("")
	lines.append("=== RITMO DE PARTIDA ===")
	lines.append_array(_pace_section(rows))
	lines.append("")
	lines.append("=== SESGO POR LADO (abajo vs arriba, sin contar espejos) ===")
	lines.append_array(_side_section(rows))
	lines.append("")
	lines.append("=== TASA DE VICTORIA POR PERFIL (contra otros perfiles) ===")
	lines.append_array(_profile_section(rows, profiles))
	lines.append("")
	lines.append("=== MATRIZ: % de victorias de la fila contra la columna ===")
	lines.append_array(_matrix_section(rows, profiles))
	lines.append("")
	lines.append("=== ECONOMÍA Y EJÉRCITO (medias por partida) ===")
	lines.append_array(_economy_section(rows, profiles))
	return "\n".join(lines)


static func _pace_section(rows: Array[Dictionary]) -> PackedStringArray:
	var durations: Array[float] = []
	var first_combat: Array[float] = []
	var first_castle: Array[float] = []
	var timeouts: int = 0
	var draws: int = 0
	for row: Dictionary in rows:
		durations.append(float(row["duration"]))
		if float(row["first_combat"]) >= 0.0:
			first_combat.append(float(row["first_combat"]))
		if float(row["first_castle_hit"]) >= 0.0:
			first_castle.append(float(row["first_castle_hit"]))
		if bool(row["timed_out"]):
			timeouts += 1
		elif int(row["winner"]) == MatchTypes.NO_PLAYER:
			draws += 1
	var lines: PackedStringArray = PackedStringArray()
	lines.append("partidas: %d · sin terminar (tiempo máx.): %d · empates: %d" % [rows.size(), timeouts, draws])
	lines.append("duración   media %s · mediana %s · p10 %s · p90 %s · máx %s" % [_t(_mean(durations)), _t(_percentile(durations, 0.5)), _t(_percentile(durations, 0.1)), _t(_percentile(durations, 0.9)), _t(_max(durations))])
	lines.append("1er golpe  media %s · 1er golpe al castillo media %s" % [_t(_mean(first_combat)), _t(_mean(first_castle))])
	var end_phase: Array[float] = []
	for row: Dictionary in rows:
		if float(row["first_castle_hit"]) >= 0.0 and not bool(row["timed_out"]):
			end_phase.append(float(row["duration"]) - float(row["first_castle_hit"]))
	lines.append("del primer golpe al castillo hasta el final: media %s · p90 %s" % [_t(_mean(end_phase)), _t(_percentile(end_phase, 0.9))])
	return lines


static func _side_section(rows: Array[Dictionary]) -> PackedStringArray:
	var bottom_wins: int = 0
	var top_wins: int = 0
	for row: Dictionary in rows:
		if row["bottom"] == row["top"]:
			continue
		match int(row["winner"]):
			MatchTypes.PLAYER_BOTTOM:
				bottom_wins += 1
			MatchTypes.PLAYER_TOP:
				top_wins += 1
	var total: int = bottom_wins + top_wins
	var lines: PackedStringArray = PackedStringArray()
	lines.append("abajo %d (%s) · arriba %d (%s)" % [bottom_wins, _pct(bottom_wins, total), top_wins, _pct(top_wins, total)])
	var mirror_bottom: int = 0
	var mirror_top: int = 0
	for row: Dictionary in rows:
		if row["bottom"] != row["top"]:
			continue
		if int(row["winner"]) == MatchTypes.PLAYER_BOTTOM:
			mirror_bottom += 1
		elif int(row["winner"]) == MatchTypes.PLAYER_TOP:
			mirror_top += 1
	lines.append("espejos (mismo perfil): abajo %d · arriba %d" % [mirror_bottom, mirror_top])
	return lines


static func _profile_section(rows: Array[Dictionary], profiles: Array[StringName]) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for profile: StringName in profiles:
		var wins: int = 0
		var losses: int = 0
		for row: Dictionary in rows:
			if row["bottom"] == row["top"] or (row["bottom"] != profile and row["top"] != profile):
				continue
			var side: int = MatchTypes.PLAYER_BOTTOM if row["bottom"] == profile else MatchTypes.PLAYER_TOP
			var winner: int = int(row["winner"])
			if winner == side:
				wins += 1
			elif winner == MatchTypes.opponent_of(side):
				losses += 1
		lines.append("%-10s %s (%d-%d)" % [profile, _pct(wins, wins + losses), wins, losses])
	return lines


static func _matrix_section(rows: Array[Dictionary], profiles: Array[StringName]) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var header: String = "%-10s" % ""
	for profile: StringName in profiles:
		header += "%9s" % profile
	lines.append(header)
	for row_profile: StringName in profiles:
		var line: String = "%-10s" % row_profile
		for column_profile: StringName in profiles:
			if row_profile == column_profile:
				line += "%9s" % "-"
				continue
			var wins: int = 0
			var games: int = 0
			for row: Dictionary in rows:
				var row_side: int = -1
				if row["bottom"] == row_profile and row["top"] == column_profile:
					row_side = MatchTypes.PLAYER_BOTTOM
				elif row["top"] == row_profile and row["bottom"] == column_profile:
					row_side = MatchTypes.PLAYER_TOP
				if row_side < 0:
					continue
				games += 1
				if int(row["winner"]) == row_side:
					wins += 1
			line += "%9s" % _pct(wins, games)
		lines.append(line)
	return lines


static func _economy_section(rows: Array[Dictionary], profiles: Array[StringName]) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("%-10s %8s %8s %8s %8s %10s %8s %8s" % ["perfil", "oro gan.", "pico oro", "unidades", "plots", "estruct.", "granjas", "torres"])
	for profile: StringName in profiles:
		var earned: Array[float] = []
		var peak: Array[float] = []
		var units: Array[float] = []
		var plots: Array[float] = []
		var structures: Array[float] = []
		var farms: Array[float] = []
		var towers: Array[float] = []
		for row: Dictionary in rows:
			for side_name: String in ["bottom", "top"]:
				if row[side_name] != profile:
					continue
				earned.append(float(row["earned_" + side_name]))
				peak.append(float(row["peak_gold_" + side_name]))
				units.append(float(row["units_" + side_name]))
				plots.append(float(row["plots_" + side_name]))
				var built: int = 0
				for count: Variant in (row["structures_" + side_name] as Dictionary).values():
					built += int(count)
				structures.append(float(built))
				farms.append(float((row["structures_" + side_name] as Dictionary).get(&"farm", 0)))
				towers.append(float((row["structures_" + side_name] as Dictionary).get(&"tower", 0)))
		lines.append("%-10s %8.0f %8.0f %8.0f %8.1f %10.1f %8.1f %8.1f" % [profile, _mean(earned), _mean(peak), _mean(units), _mean(plots), _mean(structures), _mean(farms), _mean(towers)])
	return lines


# --- Utilidades -----------------------------------------------------------------

static func _pct(part: int, total: int) -> String:
	return "%.0f%%" % (100.0 * part / total) if total > 0 else "n/a"


static func format_time(seconds: float) -> String:
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]


static func _t(seconds: float) -> String:
	return format_time(seconds)


static func _mean(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total: float = 0.0
	for value: float in values:
		total += value
	return total / values.size()


static func _max(values: Array[float]) -> float:
	var result: float = 0.0
	for value: float in values:
		result = maxf(result, value)
	return result


static func _percentile(values: Array[float], fraction: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	return sorted[clampi(roundi((sorted.size() - 1) * fraction), 0, sorted.size() - 1)]
