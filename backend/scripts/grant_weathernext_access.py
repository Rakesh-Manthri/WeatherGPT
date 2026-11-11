"""
Grant storage.objectViewer IAM role to our service account on weathernext3_spatial.
Run once: backend\venv\Scripts\python backend\scripts\grant_weathernext_access.py
"""
import sys
sys.path.insert(0, "backend")

KEY_PATH = "backend/service_account.json"
PROJECT = "weathergpt-509714"
BUCKET_NAME = "weathernext3_spatial"
SA_EMAIL = "weather-service@weathergpt-509714.iam.gserviceaccount.com"

from google.oauth2 import service_account
from google.cloud import storage

creds = service_account.Credentials.from_service_account_file(
    KEY_PATH,
    scopes=["https://www.googleapis.com/auth/cloud-platform"],
)

client = storage.Client(credentials=creds, project=PROJECT)
bucket = client.bucket(BUCKET_NAME, user_project=PROJECT)

try:
    policy = bucket.get_iam_policy(requested_policy_version=3)
    print("Current IAM policy retrieved, version:", policy.version)
    for b in policy.bindings:
        print(" role:", b["role"], "| members:", b.get("members", []))
except Exception as e:
    print("Could not get IAM policy (may not have setIamPolicy permission):", e)
    print()
    print("ACTION REQUIRED: Please go to the Google Cloud Console and manually grant:")
    print(f"  Service Account: {SA_EMAIL}")
    print(f"  Role: roles/storage.objectViewer")
    print(f"  Bucket: {BUCKET_NAME}")
    print()
    print("OR run this gcloud command (if gcloud is installed):")
    print(f"  gcloud storage buckets add-iam-policy-binding gs://{BUCKET_NAME}")
    print(f"    --member=serviceAccount:{SA_EMAIL}")
    print(f"    --role=roles/storage.objectViewer")
    print(f"    --billing-project={PROJECT}")
    sys.exit(1)
