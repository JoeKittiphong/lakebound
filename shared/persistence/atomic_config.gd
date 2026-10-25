class_name AtomicConfig
extends RefCounted

## Commit a fully written ConfigFile without replacing the last good save on write failure.
static func save(config: ConfigFile, path: String) -> Error:
 var temporary := path + ".tmp"
 var error := config.save(temporary)
 return DirAccess.rename_absolute(temporary, path) if error == OK else error
