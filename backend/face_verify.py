from fastapi import APIRouter, UploadFile, File
import numpy as np
import cv2

from face_utils import (
    load_known_faces,
    extract_face_encoding,
    compare_faces
)

router = APIRouter(tags=["Face Verification"])

# Load face encodings once
known_encodings, known_admissions = load_known_faces()


@router.post("/verify")
async def verify_face(image: UploadFile = File(...)):
    """
    Verifies face and returns admission number if matched
    """

    try:
        # --------------------------------------------------
        # 1. READ IMAGE
        # --------------------------------------------------
        contents = await image.read()
        np_arr = np.frombuffer(contents, np.uint8)
        img = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)

        if img is None:
            return {
                "success": False,
                "message": "Invalid image"
            }

        # --------------------------------------------------
        # 2. FACE ENCODING
        # --------------------------------------------------
        encoding = extract_face_encoding(img)

        if encoding is None:
            return {
                "success": False,
                "message": "No face detected or multiple faces"
            }

        # --------------------------------------------------
        # 3. FACE COMPARISON
        # --------------------------------------------------
        match = compare_faces(
            encoding,
            known_encodings,
            known_admissions
        )

        if match is None:
            return {
                "success": False,
                "message": "Face not recognized"
            }

        # --------------------------------------------------
        # 4. SUCCESS
        # --------------------------------------------------
        return {
            "success": True,
            "admissionNo": match
        }

    except Exception as e:
        print("FACE VERIFY ERROR:", e)
        return {
            "success": False,
            "message": "Verification failed"
        }
