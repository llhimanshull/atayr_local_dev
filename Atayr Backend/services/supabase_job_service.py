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
