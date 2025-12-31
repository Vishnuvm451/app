from fastapi import APIRouter, File, UploadFile, HTTPException
import numpy as np
import cv2
import face_recognition

from firebase import db, bucket

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
    Registers student's face (Admission-based):
    - admission_no = Firestore document ID
    - auth_uid = Firebase Auth UID
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

    rgb_img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)

    # --------------------------------------------------
    # 3. FACE DETECTION
    # --------------------------------------------------
    face_locations = face_recognition.face_locations(rgb_img)

    if len(face_locations) == 0:
        raise HTTPException(status_code=400, detail="No face detected")

    if len(face_locations) > 1:
        raise HTTPException(
            status_code=400,
            detail="Multiple faces detected. Only one allowed"
        )

    # --------------------------------------------------
    # 4. FACE ENCODING
    # --------------------------------------------------
    encodings = face_recognition.face_encodings(rgb_img, face_locations)

    if not encodings:
        raise HTTPException(status_code=400, detail="Face encoding failed")

    embedding = encodings[0]  # 128-d vector

    # --------------------------------------------------
    # 5. UPDATE FIRESTORE
    # --------------------------------------------------
    student_ref.update({
        "face_embedding": embedding.tolist(),
        "face_enabled": True,
        "face_registered_at": db.SERVER_TIMESTAMP,
    })

    # --------------------------------------------------
    # 6. UPLOAD IMAGE (OPTIONAL)
    # --------------------------------------------------
    blob = bucket.blob(f"face_images/{admission_no}/register.jpg")
    blob.upload_from_string(contents, content_type=image.content_type)
    blob.make_private()

    # --------------------------------------------------
    # 7. RESPONSE
    # --------------------------------------------------
    return {
        "success": True,
        "admissionNo": admission_no,
        "message": "Face registered successfully"
    }
