import os
from supabase import create_client, Client

class SupabaseJobService:
    """
    Service for the backend to interact with Supabase processing_jobs
    using the service_role key, allowing it to bypass Row Level Security (RLS)
    and update statuses securely.
    """
    def __init__(self):
        supabase_url: str = os.environ.get("SUPABASE_URL")
        supabase_key: str = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
        
        if not supabase_url or not supabase_key:
            raise ValueError("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set in environment variables.")
            
        self.supabase: Client = create_client(supabase_url, supabase_key)

    def update_job_status(self, job_id: str, status: str, error_message: str = None, total_items: int = None, completed_items: int = None, failed_items: int = None):
        """
        Updates the status and counts of a processing job.
        """
        payload = {"status": status}
        if error_message is not None:
            payload["error_message"] = error_message
        if total_items is not None:
            payload["total_items"] = total_items
        if completed_items is not None:
            payload["completed_items"] = completed_items
        if failed_items is not None:
            payload["failed_items"] = failed_items
            
        return self.supabase.table("processing_jobs").update(payload).eq("id", job_id).execute()

    def update_job_item_status(self, item_id: str, status: str, progress: float = None, error_message: str = None):
        """
        Updates the status and progress of a single job item.
        """
        payload = {"status": status}
        if progress is not None:
            payload["progress"] = progress
        if error_message is not None:
            payload["error_message"] = error_message
            
        return self.supabase.table("processing_job_items").update(payload).eq("id", item_id).execute()

    def get_job_items(self, job_id: str):
        response = self.supabase.table("processing_job_items").select("*").eq("job_id", job_id).execute()
        return response.data

    def get_job(self, job_id: str):
        response = self.supabase.table("processing_jobs").select("*").eq("id", job_id).execute()
        return response.data[0] if response.data else None

    def insert_garment(self, garment_data: dict):
        embedding = garment_data.get('embedding')
        print(f"[EMBEDDING WRITE] garment_id={garment_data.get('id')} embedding_present={bool(embedding)} dims={len(embedding) if embedding else 0}")
        return self.supabase.table("garments").insert(garment_data).execute()

    def insert_garment_observation(self, observation_data: dict):
        embedding = observation_data.get('embedding')
        print(f"[EMBEDDING WRITE] garment_id={observation_data.get('garment_id')} embedding_present={bool(embedding)} dims={len(embedding) if embedding else 0}")
        return self.supabase.table("garment_observations").insert(observation_data).execute()

    def get_garments_by_ids(self, garment_ids: list[str]):
        if not garment_ids:
            return []
        response = self.supabase.table("garments").select("*").in_("id", garment_ids).execute()
        return response.data

    def match_garment_observation(self, user_id: str, category: str, embedding: list[float], threshold: float = 0.05):
        """
        Calls the RPC match_garment_observation to find candidate garments.
        Returns a list of dicts with 'garment_id' and 'similarity'.
        """
        response = self.supabase.rpc(
            "match_garment_observation",
            {
                "p_user_id": user_id,
                "p_category": category,
                "p_embedding": embedding,
                "p_match_threshold": threshold
            }
        ).execute()
        return response.data if response.data else []

    def claim_job_item(self, item_id: str) -> bool:
        """
        Atomically claims a job item by changing its status from 'queued' to 'analyzing'.
        Returns True if successful, False if it was already claimed.
        """
        response = self.supabase.table("processing_job_items") \
            .update({"status": "analyzing", "progress": 0.1}) \
            .eq("id", item_id) \
            .eq("status", "queued") \
            .execute()
        return len(response.data) > 0

    def claim_paused_job_item(self, item_id: str) -> bool:
        """
        Atomically claims a paused job item by changing its status to 'generating'.
        """
        response = self.supabase.table("processing_job_items") \
            .update({"status": "generating", "progress": 0.5}) \
            .eq("id", item_id) \
            .eq("status", "paused") \
            .execute()
        return len(response.data) > 0
