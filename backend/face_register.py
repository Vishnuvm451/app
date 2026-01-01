from fastapi import APIRouter, File, UploadFile, HTTPException
import numpy as np
import cv2

from firebase import db, bucket
from face_utils import register_face_encoding

# =====================================================
# ROUTER
# =====================================================
router = APIRouter(prefix="/face", tags=["Face Registration"])

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

    # --------------------------------------------------
    # 1. VALIDATE STUDENT RECORD
    # --------------------------------------------------
    student_ref = db.collection("students").document(admission_no)
    student_doc = student_ref.get()

    if not student_doc.exists:
        raise HTTPException(status_code=404, detail="Student not found")

    student_data = student_doc.to_dict()

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
        "face_registered_at": db.SERVER_TIMESTAMP,
    })

    # --------------------------------------------------
    # 5. UPLOAD IMAGE (OPTIONAL – FOR AUDIT)
    # --------------------------------------------------
    blob = bucket.blob(f"face_images/{admission_no}/register.jpg")
    blob.upload_from_string(contents, content_type=image.content_type)
    blob.make_private()

    # --------------------------------------------------
    # 6. RESPONSE
    # --------------------------------------------------
    return {
        "success": True,
        "admissionNo": admission_no,
        "message": "Face registered successfully"
    }
