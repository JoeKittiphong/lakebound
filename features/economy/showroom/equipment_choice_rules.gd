class_name EquipmentChoiceRules
extends RefCounted

static func error(profile:AnglerProfile,item:TackleItem)->String:
 if profile==null or item==null:return "เลือกคันเบ็ดก่อน"
 return profile.equipment_fit_error(item)

static func explanation(profile:AnglerProfile,item:TackleItem)->String:
 var reason:=error(profile,item)
 if reason.is_empty():return "ใช้กับชุดที่เลือกได้"
 if item.kind=="reel":
  var names:=PackedStringArray()
  for rod:TackleItem in TackleCatalog.ITEMS:
   if rod.kind=="rod" and EquipmentFit.compatible(rod,item):names.append(rod.display_name)
  return reason+"\n\nใช้กับคัน: "+(" · ".join(names) if not names.is_empty() else "ยังไม่มีคันที่รองรับ")
 if item.kind in ["bait","lure"]:
  var names:=PackedStringArray()
  for rod:TackleItem in TackleCatalog.ITEMS:
   if rod.kind!="rod":continue
   var reel:TackleItem=profile.reel_for_rod(rod)
   var fits:=false
   for rig:TerminalRigSpec in item.terminal_rigs:
    if RigCompatibility.evaluate(rod,reel,profile.equipped("line"),item,rig).allowed:fits=true;break
   if fits:names.append(rod.display_name)
  return reason+"\n\nคันที่รองรับเมื่อใช้เอ็นปัจจุบัน: "+(" · ".join(names) if not names.is_empty() else "ตรวจขนาดเอ็น รอก และวิธีตกของเหยื่อนี้")
 return reason
