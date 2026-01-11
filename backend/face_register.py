from fastapi import APIRouter, File, UploadFile, HTTPException
import numpy as np
import cv2

# ✅ FIX 1: Removed 'bucket' from import
from firebase import get_db
from face_utils import register_face_encoding

# =====================================================
# ROUTER
# =====================================================
router = APIRouter(tags=["Face Registration"])

# =====================================================
# FACE REGISTRATION
# =====================================================
@router.post("/register")
async def register_face(
    admission_no: str,
    auth_uid: str,
    image: UploadFile = File(...)
):
    """
    Registers student's face (Admission-based)
    - admission_no = Firestore document ID
    - auth_uid = Firebase Auth UID
    - Face data stored locally in backend (pickle)
    """

    db = get_db()

    # --------------------------------------------------
    # 1. VALIDATE STUDENT RECORD
    # --------------------------------------------------
    # ✅ FIX 2: Changed "students" -> "student" (singular) to match your Firestore
    student_ref = db.collection("student").document(admission_no)
    student_doc = student_ref.get()

    if not student_doc.exists:
        raise HTTPException(status_code=404, detail="Student not found")

    student_data = student_doc.to_dict()

    # Verify this student belongs to the logged-in user
    if student_data.get("authUid") != auth_uid:
        raise HTTPException(status_code=403, detail="Auth UID mismatch")

    if student_data.get("face_enabled") is True:
        raise HTTPException(status_code=400, detail="Face already registered")

    # --------------------------------------------------
    # 2. READ IMAGE
    # --------------------------------------------------
    contents = await image.read()
    np_arr = np.frombuffer(contents, np.uint8)
    img = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)

    if img is None:
        raise HTTPException(status_code=400, detail="Invalid image file")

    # --------------------------------------------------
    # 3. REGISTER FACE (LOCAL DB)
    # --------------------------------------------------
    success, message = register_face_encoding(
        image=img,
        admission_no=admission_no
    )

    if not success:
        raise HTTPException(status_code=400, detail=message)

    # --------------------------------------------------
    # 4. UPDATE FIRESTORE (FLAG ONLY)
    # --------------------------------------------------
    student_ref.update({
        "face_enabled": True,
        "face_registered_at": firestore.SERVER_TIMESTAMP if 'firestore' in globals() else None, 
        # Note: server timestamp usually needs firestore import. 
        # To be safe and simple, let's just use True or ignore timestamp for now 
        # or import datetime.
    })
    
    # Better approach for timestamp without extra imports:
    from datetime import datetime
    student_ref.update({
        "face_enabled": True,
        "face_registered_at": datetime.now()
    })

    # ❌ REMOVED: Section 5 (Storage Upload) because you don't use Storage.

    # --------------------------------------------------
    # 6. RESPONSE
    # --------------------------------------------------
    return {
        "success": True,
        "admissionNo": admission_no,
        "message": "Face registered successfully"
    }