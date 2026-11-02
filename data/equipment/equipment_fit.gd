class_name EquipmentFit
extends RefCounted
## Mount families describe geometry, independently of rod power/action and reel stats.
const FAMILIES: Dictionary = {
 "spinning": ["spinning"], "casting": ["low", "round"],
 "overhead": ["star", "lever"], "spincast": ["spincast"],
 "fly": ["fly"], "ice": ["ice"], "fixed": []
}
static func accepts(layout: String, family: String) -> bool:
 return family in FAMILIES.get(layout, [])
static func compatible(rod: Resource, reel: Resource) -> bool:
 return rod != null and reel != null and accepts(rod.mount_layout, reel.reel_family)
static func layout_label(layout: String) -> String:
 return {"spinning":"รอกสปินนิ่ง", "casting":"รอกเบท", "overhead":"รอกโอเวอร์เฮด", "spincast":"รอกสปินแคสต์", "fly":"รอกฟลาย", "ice":"รอกไอซ์", "fixed":"สายผูกปลาย ไม่ใช้รอก"}.get(layout,"รอกที่เข้าคู่")
