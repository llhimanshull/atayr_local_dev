import asyncio
import os
from supabase import create_client

supabase_url = os.environ.get("SUPABASE_URL", "http://localhost:8000")
supabase_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "dummy")
supabase = create_client(supabase_url, supabase_key)

user_id = "00000000-0000-0000-0000-000000000000"
date = "2026-10-03"

async def test_reserve():
    try:
        res = supabase.rpc("reserve_ai_suggestion", {"p_user_id": user_id, "p_date": date}).execute()
        return res.data
    except Exception as e:
        return False

async def main():
    # clear state
    supabase.table("ai_suggestion_usage").delete().eq("user_id", user_id).execute()
    
    print("Testing 0/2 with 5 concurrent requests...")
    results = await asyncio.gather(*[test_reserve() for _ in range(5)])
    print("Results:", results)
    
    successes = sum(1 for r in results if r)
    print("Expected: 2, Actual:", successes)
    
    # We must finalize to actually use the slots
    for r in results:
        if r:
            supabase.rpc("finalize_ai_suggestion", {"p_user_id": user_id, "p_date": date, "p_success": True}).execute()

    print("\nTesting 1/2 with 5 concurrent requests...")
    supabase.table("ai_suggestion_usage").update({"successful_count": 1, "reserved_count": 0}).eq("user_id", user_id).execute()
    results2 = await asyncio.gather(*[test_reserve() for _ in range(5)])
    print("Results:", results2)
    
    successes2 = sum(1 for r in results2 if r)
    print("Expected: 1, Actual:", successes2)

if __name__ == "__main__":
    asyncio.run(main())
