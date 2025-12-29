from fastapi import APIRouter, File, UploadFile, HTTPException
import numpy as np
import cv2
import face_recognition

from firebase import db, bucket

router = APIRouter(prefix="/face", tags=["Face Registration"])


@router.post("/register")
async def register_face(
    student_uid: str,
    image: UploadFile = File(...)
):
    """
    Registers student's face:
    - Accepts image
    - Extracts face embedding
    - Stores embedding in Firestore
    - Uploads image to Firebase Storage
    """

    # --------------------------------------------------
    # 1. READ IMAGE
    # --------------------------------------------------
    contents = await image.read()
    np_arr = np.frombuffer(contents, np.uint8)
    img = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)

    if img is None:
        raise HTTPException(status_code=400, detail="Invalid image file")

    # Convert BGR → RGB
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
            detail="Multiple faces detected. Only one allowed."
        )

    # --------------------------------------------------
    # 3. FACE EMBEDDING
    # --------------------------------------------------
    face_encodings = face_recognition.face_encodings(
        rgb_img, face_locations
    )

    if not face_encodings:
        raise HTTPException(
            status_code=400,
            detail="Face encoding failed"
        )

    embedding = face_encodings[0]  # 128-d vector

    # --------------------------------------------------
    # 4. FIRESTORE UPDATE
    # --------------------------------------------------
    student_ref = db.collection("students").document(student_uid)

    student_doc = student_ref.get()
    if not student_doc.exists:
        raise HTTPException(
            status_code=404,
            detail="Student not found"
        )

    student_ref.update({
        "face_embedding": embedding.tolist(),
        "face_enabled": True
    })

    # --------------------------------------------------
    # 5. UPLOAD IMAGE TO FIREBASE STORAGE
    # --------------------------------------------------
    blob = bucket.blob(f"face_images/{student_uid}/register.jpg")
    blob.upload_from_string(
        contents,
        content_type=image.content_type
    )

    blob.make_private()

    # --------------------------------------------------
    # 6. RESPONSE
    # --------------------------------------------------
    return {
        "success": True,
        "message": "Face registered successfully"
    }
