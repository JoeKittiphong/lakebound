class_name SheetsConnectionSettings
extends RefCounted

const SAVE_PATH := "user://sheets_connection.cfg"
const LEGACY_PATH := "user://server_connection.cfg"

static func normalize(value: String) -> String:
 return value.strip_edges().trim_suffix("/")

static func valid_url(value: String) -> bool:
 var address := normalize(value)
 if address.length() > 253:
  return false
 var pattern := RegEx.new()
 pattern.compile("^https://script\\.google\\.com/macros/s/[A-Za-z0-9_-]+/exec$")
 return pattern.search(address) != null

static func resolve(fallback: String, path: String = SAVE_PATH, legacy_path: String = LEGACY_PATH) -> String:
 # Read the previous setting only if it is already a Google Web App URL.
 # An obsolete custom-server override must not hide the packaged Sheets URL.
 for candidate in [path, legacy_path]:
  var config := ConfigFile.new()
  if config.load(candidate) != OK: continue
  var saved := str(config.get_value("sheets", "url", config.get_value("server", "url", "")))
  if valid_url(saved): return normalize(saved)
 return normalize(fallback) if valid_url(fallback) else ""

static func save_url(value: String, path: String = SAVE_PATH) -> Error:
 if not valid_url(value):
  return ERR_INVALID_PARAMETER
 var config := ConfigFile.new()
 config.set_value("sheets", "url", normalize(value))
 return AtomicConfig.save(config, path)

static func failure_message(result: int, code: int, api_error: String = "") -> String:
 if api_error == "invalid_credentials":
  return "ระบบปฏิเสธสิทธิ์ผู้เล่น · อย่าลบข้อมูลเกม ให้ติดต่อผู้ดูแล"
 if api_error in ["invalid_payload", "invalid_name", "invalid_catch", "conflicting_catch", "name_required", "invalid_query"]:
  return "ระบบไม่รับข้อมูลสถิติ · ให้ติดต่อผู้ดูแลโดยไม่ลบเซฟ"
 if api_error in ["busy_retry", "write_failed_retry", "refresh_failed_retry", "snapshot_not_ready"]:
  return "ระบบอันดับยังไม่พร้อม · ลองใหม่อีกครั้งภายหลัง"
 if result == HTTPRequest.RESULT_CANT_RESOLVE:
  return "ไม่พบที่อยู่ Google Sheets · เปิดการเชื่อมต่อเพื่อตรวจ URL"
 if result == HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
  return "ยืนยัน HTTPS ไม่สำเร็จ · ตรวจวันเวลาเครื่องและอินเทอร์เน็ต"
 if result == HTTPRequest.RESULT_TIMEOUT:
  return "ระบบอันดับไม่ตอบภายในเวลาที่กำหนด · กดลองใหม่"
 if result != HTTPRequest.RESULT_SUCCESS:
  return "เชื่อมต่อไม่สำเร็จ · ตรวจอินเทอร์เน็ตแล้วลองใหม่"
 if code == 401 or code == 403:
  return "ระบบปฏิเสธสิทธิ์ผู้เล่น · อย่าลบข้อมูลเกม ให้ติดต่อผู้ดูแล"
 if code == 429:
  return "เชื่อมต่อบ่อยเกินไป · รอสักครู่แล้วลองใหม่"
 if code == 400 or code == 409:
  return "ระบบไม่รับข้อมูลสถิติ · ให้ติดต่อผู้ดูแลโดยไม่ลบเซฟ"
 if code >= 500:
  return "ระบบอันดับยังไม่พร้อมใช้งาน · ลองใหม่อีกครั้งภายหลัง"
 return "ข้อมูลอันดับไม่ถูกต้อง · ตรวจที่อยู่ในการเชื่อมต่อ"
