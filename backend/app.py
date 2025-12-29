from fastapi import FastAPI, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from typing import Optional

# Local imports (we will create these files next)
from firebase import init_firebase 
from face_register import register_face
from face_verify import verify_face

# -------------------------------------------------
# APP INIT
# -------------------------------------------------
app = FastAPI(
    title="DARZO Face Recognition API",
    description="Face registration & verification for attendance",
    version="1.0.0"
)

# -------------------------------------------------
# CORS (ALLOW FLUTTER APP)
# -------------------------------------------------
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],   # ⚠️ later restrict to your app
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# -------------------------------------------------
# INIT FIREBASE (ON SERVER START)
# -------------------------------------------------
init_firebase()

# -------------------------------------------------
# HEALTH CHECK
# -------------------------------------------------
@app.get("/")
def root():
    return {
        "status": "ok",
        "message": "DARZO Face Recognition API running"
    }

# -------------------------------------------------
# FACE REGISTRATION (MANDATORY)
# -------------------------------------------------
@app.post("/face/register")
async def face_register(
    student_id: str = Form(...),
    image: UploadFile = File(...)
):
    """
    Registers a student's face.
    - Called after student registration
    - Stores face embedding in Firestore
    """
    result = await register_face(
        student_id=student_id,
        image=image
    )
    return result

# -------------------------------------------------
# FACE VERIFICATION (LOGIN / ATTENDANCE)
# -------------------------------------------------
@app.post("/face/verify")
async def face_verify(
    student_id: Optional[str] = Form(None),
    image: UploadFile = File(...)
):
    """
    Verifies face for:
    - Attendance
    - Face login
    """
    result = await verify_face(
        student_id=student_id,
        image=image
    )
    return result
