class_name PlayerSavePaths
extends RefCounted

# Fixed reset generation: keep these paths across subsequent app versions so
# players restart once, then retain all progress earned after this reset.
const ACCOUNTS := "accounts_cloud_v2"
const PROFILE := "user://angler_profile_cloud_v2.cfg"
const MATCH_SESSION := "user://match_session_cloud_v2.cfg"
const RANKING_SYNC := "user://supabase-ranking-cloud-v2.cfg"
const RANKING_CACHE := "user://supabase-ranking-views-cloud-v2.cfg"
const BACKGROUND_SYNC := "user://supabase-background-cloud-v2.cfg"
const BACKGROUND_CACHE := "user://supabase-background-views-cloud-v2.cfg"
const COLLECTION := "user://fish_collection_cloud_v2.cfg"
const TUTORIAL := "user://first_catch_tutorial_cloud_v2.cfg"
