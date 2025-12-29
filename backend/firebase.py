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
        # Already initialized
        return

    # 🔐 Service account key
    cred = credentials.Certificate("serviceAccountKey.json")

    firebase_admin.initialize_app(
        cred,
        {
            # 🔥 CHANGE THIS TO YOUR BUCKET NAME
            "storageBucket": "YOUR_PROJECT_ID.appspot.com"
        }
    )

    db = firestore.client()
    bucket = storage.bucket()

    print("✅ Firebase initialized successfully")


# -------------------------------------------------
# HELPERS
# -------------------------------------------------
def get_db():
    if db is None:
        raise Exception("Firestore not initialized")
    return db


def get_bucket():
    if bucket is None:
        raise Exception("Storage not initialized")
    return bucket
