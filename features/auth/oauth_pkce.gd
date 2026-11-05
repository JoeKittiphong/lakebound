class_name OAuthPKCE
extends RefCounted
static func base64url(bytes: PackedByteArray) -> String:
 return Marshalls.raw_to_base64(bytes).replace("+","-").replace("/","_").replace("=","")
static func verifier() -> String:
 return base64url(Crypto.new().generate_random_bytes(32))
static func challenge(value: String) -> String:
 var hash := HashingContext.new()
 hash.start(HashingContext.HASH_SHA256)
 hash.update(value.to_utf8_buffer())
 return base64url(hash.finish())
static func callback_code(url: String, expected: String) -> String:
 if url.length()>4096 or not url.begins_with(expected+"?") or url.contains("#"): return ""
 var code := ""
 for pair in url.get_slice("?",1).split("&"):
  var key := pair.get_slice("=",0).uri_decode()
  if key=="error" or key=="error_code": return ""
  if key=="code":
   if not code.is_empty(): return ""
   code=pair.substr(pair.find("=")+1).uri_decode()
 if code.length()<8 or code.length()>2048 or code.contains("\n") or code.contains("\r"): return ""
 return code
