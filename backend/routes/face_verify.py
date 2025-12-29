from fastapi import APIRouter, File, UploadFile, HTTPException
import numpy as np
import cv2
import face_recognition

from firebase import db

router = APIRouter(prefix="/face", tags=["Face Verification"])

# 🔐 Distance threshold (industry safe)
FACE_MATCH_THRESHOLD = 0.45


@router.post("/verify")
async def verify_face(
    student_uid: str,
    image: UploadFile = File(...)
):
    """
    Verifies student's face:
    - Accepts live image
    - Extracts face embedding
    - Compares with stored embedding
    - Returns MATCH / NO MATCH
    """

    # --------------------------------------------------
    # 1. READ IMAGE
    # --------------------------------------------------
    contents = await image.read()
    np_arr = np.frombuffer(contents, np.uint8)
    img = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)

    if img is None:
        raise HTTPException(status_code=400, detail="Invalid image")

    rgb_img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)

    # --------------------------------------------------
    # 2. FACE DETECTION
    # --------------------------------------------------
    face_locations = face_recognition.face_locations(rgb_img)

    if len(face_locations) == 0:
        raise HTTPException(status_code=400, detail="No face detected")

    if len(face_locations) > 1:
        raise HTTPException(
            status_code=400,
            detail="Multiple faces detected"
        )

    # --------------------------------------------------
    # 3. FACE ENCODING
    # --------------------------------------------------
    encodings = face_recognition.face_encodings(
        rgb_img, face_locations
    )

    if not encodings:
        raise HTTPException(
            status_code=400,
            detail="Face encoding failed"
        )

    live_embedding = encodings[0]

    # --------------------------------------------------
    # 4. FETCH STORED EMBEDDING
    # --------------------------------------------------
    student_ref = db.collection("students").document(student_uid)
    student_doc = student_ref.get()

    if not student_doc.exists:
        raise HTTPException(
            status_code=404,
            detail="Student not found"
        )

    student_data = student_doc.to_dict()

    if not student_data.get("face_enabled"):
        raise HTTPException(
            status_code=400,
            detail="Face not registered"
        )

    stored_embedding = student_data.get("face_embedding")

    if not stored_embedding:
        raise HTTPException(
            status_code=400,
            detail="Stored face data missing"
        )

    stored_embedding = np.array(stored_embedding)

    # --------------------------------------------------
    # 5. FACE COMPARISON
    # --------------------------------------------------
    distance = face_recognition.face_distance(
        [stored_embedding], live_embedding
    )[0]

    is_match = distance <= FACE_MATCH_THRESHOLD

    # --------------------------------------------------
    # 6. RESPONSE
    # --------------------------------------------------
    return {
        "match": is_match,
        "distance": round(float(distance), 4),
        "threshold": FACE_MATCH_THRESHOLD
    }

