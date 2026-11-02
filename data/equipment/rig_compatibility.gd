class_name RigCompatibility
extends RefCounted

const CAST_METHODS := ["cast_float", "cast_bottom", "cast_retrieve"]
const ACTIVE_METHODS := ["cast_float", "cast_bottom", "cast_retrieve", "pole_float", "vertical_jig", "boat_drop"]
const KG_PER_LB := 0.45359237

static func evaluate(rod: TackleItem, reel: TackleItem, line: TackleItem, bait: TackleItem, rig: TerminalRigSpec) -> Dictionary:
 var result := {"allowed": false, "reasons": PackedStringArray(), "codes": PackedStringArray(), "notes": PackedStringArray(), "payload_g": 0.0, "capacity_m": 0.0, "drag_limit_kgf": 0.0, "technique": ""}
 if rod == null or line == null or bait == null or rig == null:
  return _block(result, "missing_rig", "เลือกชุดปลายสายให้ครบก่อนตกปลา")
 if rod.kind != "rod" or line.kind != "line" or bait.kind not in ["bait", "lure"] or rig not in bait.terminal_rigs:
  return _block(result, "invalid_slots", "ชุดอุปกรณ์หรือชุดปลายสายไม่ตรงกับเหยื่อ")
 if not rig.valid() or not is_finite(bait.payload_g) or bait.payload_g <= 0.0:
  return _block(result, "unknown_mass", "ชุดนี้ยังไม่มีสเปกน้ำหนัก — เลือกชุดอื่น")
 result.payload_g = bait.payload_g + rig.extra_mass_g()
 if not is_finite(result.payload_g): return _block(result, "unknown_mass", "น้ำหนักชุดปลายสายไม่ถูกต้อง")
 result.technique = rig.technique
 result["rig_id"] = str(rig.id)
 var rs := rod.rod_spec
 var ls := line.line_spec
 if rs == null or ls == null or not is_finite(ls.diameter_mm) or ls.diameter_mm <= 0 or not is_finite(ls.break_kgf) or ls.break_kgf <= 0:
  return _block(result, "unknown_spec", "อุปกรณ์นี้ยังไม่มีสเปกครบ — เลือกอุปกรณ์อื่น")
 for value in [rs.cast_min_g, rs.cast_max_g, rs.jig_min_g, rs.jig_max_g, rs.drop_min_g, rs.drop_max_g, rs.pole_min_g, rs.pole_max_g, rs.max_working_drag_kgf]:
  if not is_finite(value): return _block(result, "invalid_rod", "สเปกคันไม่ถูกต้อง")
 if rig.technique not in rs.techniques:
  return _block(result, "technique", "คันนี้ไม่รองรับ %s" % rig.display_name)
 if rod.mount_layout != "fixed":
  if reel == null or reel.kind != "reel" or not EquipmentFit.compatible(rod, reel):
   return _block(result, "mount", "คันกับรอกไม่เข้าประเภท")
  if reel.reel_spec == null:
   return _block(result, "unknown_reel", "รอกยังไม่มีสเปกครบ")
  var spool := reel.reel_spec
  for value in [spool.cast_min_g, spool.cast_max_g, spool.diameter_min_mm, spool.diameter_max_mm, spool.reference_diameter_mm, spool.reference_capacity_m, spool.max_drag_kgf]:
   if not is_finite(value): return _block(result, "invalid_reel", "สเปกรอกไม่ถูกต้อง")
  if rig.technique not in spool.techniques:
   return _block(result, "reel_method", "รอกนี้ไม่รองรับวิธีตกของชุดปลายสาย")
  if (ls.material == "fly") != (reel.reel_family == "fly"):
   return _block(result, "fly_line", "สายฟลายต้องใช้กับชุดฟลายเท่านั้น")
  if ls.material == "fly":
   if ls.fly_weight != rs.fly_weight or ls.fly_weight < spool.fly_weight_min or ls.fly_weight > spool.fly_weight_max:
    return _block(result, "fly_weight", "หมายเลขสายฟลายไม่ตรงกับคันและรอก")
  elif spool.diameter_min_mm < 0 or spool.diameter_max_mm <= 0:
   return _block(result, "unknown_diameter", "ยังไม่มีช่วงขนาดสายของรอก")
  elif ls.diameter_mm < spool.diameter_min_mm - 0.00001 or ls.diameter_mm > spool.diameter_max_mm + 0.00001:
   return _block(result, "diameter", "สาย %.2f mm / รอกรองรับ %.2f–%.2f mm" % [ls.diameter_mm, spool.diameter_min_mm, spool.diameter_max_mm])
  result.capacity_m = minf(reel.length, spool.capacity_for(ls.diameter_mm))
  result.drag_limit_kgf = minf(spool.max_drag_kgf, minf(rs.max_working_drag_kgf, ls.break_kgf * 0.3))
 else:
  if ls.material == "fly" and rig.technique != "fly_cast":
   return _block(result, "fly_line", "ชุดสายผูกปลายนี้ใช้สายธรรมดา ไม่ใช้สายฟลาย")
  result.capacity_m = minf(line.length, rs.length_m * 1.15)
  result.drag_limit_kgf = minf(rs.max_working_drag_kgf, ls.break_kgf * 0.3)
 if rig.technique not in ACTIVE_METHODS:
  return _block(result, "mode_unavailable", "โหมดฟลาย/ไอซ์ยังไม่เปิดให้เล่น — เลือกชุดตกแบบอื่น")
 var low := -1.0
 var high := -1.0
 if rig.technique in CAST_METHODS:
  low = rs.cast_min_g; high = rs.cast_max_g
  low = maxf(low, reel.reel_spec.cast_min_g)
  high = minf(high, reel.reel_spec.cast_max_g)
  if rs.cast_min_g < 0 or reel.reel_spec.cast_min_g < 0: low = -1.0
 elif rig.technique == "vertical_jig": low = rs.jig_min_g; high = rs.jig_max_g
 elif rig.technique == "pole_float": low = rs.pole_min_g; high = rs.pole_max_g
 else: low = rs.drop_min_g; high = rs.drop_max_g
 if not is_finite(low) or not is_finite(high) or low < 0 or high <= 0 or low > high:
  return _block(result, "unknown_range", "ยังไม่มีช่วงน้ำหนักสำหรับวิธีตกนี้")
 if result.payload_g < low - 0.0001 or result.payload_g > high + 0.0001:
  return _block(result, "payload", "ชุดนี้ %.1f g / คันและรอกรองรับ %.1f–%.1f g" % [result.payload_g, low, high])
 if ls.material == "fluoro" and bait.kind == "lure" and bait.motion == "float":
  result.notes.append("สายฟลูออโรจม อาจดึงหน้าเหยื่อผิวน้ำ — แนะนำ mono หรือ braid")
 if rs.line_max_lb > 0 and ls.break_kgf > rs.line_max_lb * KG_PER_LB:
  result.notes.append("สายแรงดึงสูงกว่าช่วงแนะนำคัน — ตั้งเบรกตามกำลังคัน")
 if rs.line_min_lb > 0 and ls.break_kgf < rs.line_min_lb * KG_PER_LB:
  result.notes.append("สายเบากว่าช่วงแนะนำคัน — ระวังแรงกระชาก")
 if bait.lure_visual == "Frog" or str(bait.id) == "frog":
  if ls.material != "braid": result.notes.append("กบยางในหญ้าหนาแนะนำสาย braid")
  if rs.power not in ["MH", "H", "XH"]: result.notes.append("กบยางในพื้นที่รกแนะนำคัน MH ขึ้นไป")
 if bait.lure_visual == "Crank" and rs.action in ["Fast", "Extra-Fast"]:
  result.notes.append("แครงก์เบ็ดสามทางแนะนำคันที่โค้งต่อเนื่องกว่า")
 result.allowed = true
 return result

static func _block(result: Dictionary, code: String, message: String) -> Dictionary:
 result.codes.append(code); result.reasons.append(message)
 return result

static func summary(result: Dictionary) -> String:
 if not result.allowed: return "ใช้ไม่ได้ · " + " · ".join(result.reasons)
 var text := "ใช้ได้ · %.1f g" % result.payload_g
 if not result.notes.is_empty(): text += " · " + " · ".join(result.notes)
 return text
