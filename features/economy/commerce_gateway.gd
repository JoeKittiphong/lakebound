class_name CommerceGateway
extends Node

signal status_changed
# Platform adapters publish these inherited callback signals after server verification.
# The disabled base adapter deliberately never emits a reward or purchase.
@warning_ignore("unused_signal")
signal reward_completed(receipt: String, recovery_id: String)
@warning_ignore("unused_signal")
signal purchase_completed(receipt: String, diamonds: int)
var status := "ยังไม่เปิดบริการโฆษณา / เติมเพชร / Top 10 ออนไลน์"

# Replace through a platform-specific adapter only after integrating SDKs and
# server verification. Default production adapter never grants test rewards.
func ad_available() -> bool:
 return false

func request_recovery(_recovery_id: String) -> bool:
 status = "โฆษณายังไม่พร้อม — ไม่มีการหักเพชร"
 status_changed.emit()
 return false

func request_purchase(_product_id: String) -> bool:
 status = "ยังไม่ได้ตั้งค่าการซื้อเพชร"
 status_changed.emit()
 return false
