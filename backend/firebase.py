import firebase_admin
from firebase_admin import credentials, firestore, storage

# -------------------------------------------------
# GLOBAL OBJECTS
# -------------------------------------------------
db = None
bucket = None


# -------------------------------------------------
# INIT FIREBASE (RUN ONCE)
# -------------------------------------------------
def init_firebase():
    global db, bucket

    if firebase_admin._apps:
        return  # Already initialized

    # 🔐 Service account key (same folder as app.py)
    cred = credentials.Certificate("serviceAccountKey.json")

    firebase_admin.initialize_app(
        cred,
        {
            # 🔥 MUST MATCH YOUR FIREBASE PROJECT
            # Example: darzo-attendance.appspot.com
            "storageBucket": "darzo-attendance.appspot.com"
        }
    )

    db = firestore.client()
    bucket = storage.bucket()

    print("✅ Firebase initialized successfully")


# -------------------------------------------------
# SAFE ACCESSORS (OPTIONAL BUT GOOD PRACTICE)
# -------------------------------------------------
def get_db():
    if db is None:
        raise RuntimeError("❌ Firestore not initialized. Call init_firebase() first.")
    return db


def get_bucket():
    if bucket is None:
        raise RuntimeError("❌ Storage not initialized. Call init_firebase() first.")
    return bucket
