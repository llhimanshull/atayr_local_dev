import os
from supabase import create_client
from dotenv import load_dotenv

load_dotenv()

supabase = create_client(os.getenv('SUPABASE_URL'), os.getenv('SUPABASE_SERVICE_ROLE_KEY'))

# 1. Fetch all users from auth.users
users_response = supabase.auth.admin.list_users()

# 2. Fetch existing profiles
profiles_response = supabase.table('profiles').select('*').execute()
existing_profiles = {p['id']: p for p in profiles_response.data}

for user in users_response:
    meta = user.user_metadata
    full_name = meta.get('full_name') or meta.get('name')
    if not full_name:
        continue
    
    # Check if we should update
    existing = existing_profiles.get(user.id)
    should_update = False
    
    if not existing:
        should_update = True
    else:
        current_name = existing.get('display_name', '')
        # Only overwrite if current name is placeholder
        if not current_name or current_name in ['User', 'Unknown', 'empty'] or current_name == user.id:
            should_update = True

    if should_update:
        print(f"Updating user {user.id} with name {full_name}")
        supabase.table('profiles').upsert({
            'id': user.id,
            'display_name': full_name
        }).execute()
        
print("Sync complete.")
