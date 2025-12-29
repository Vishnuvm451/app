from fastapi import APIRouter, UploadFile, File, HTTPException
from datetime import datetime
import numpy as np
import cv2
import face_recognition

from firebase import db
from face_utils import extract_face_embedding

router = APIRouter(prefix="/attendance", tags=["Face Attendance"])

# 🔐 Strict threshold (same as verify)
FACE_MATCH_THRESHOLD = 0.45


@router.post("/mark")
async def mark_attendance_by_face(
    student_uid: str,
    class_id: str,
    session_type: str,  # morning | afternoon
    image: UploadFile = File(...)
):
    """
    Marks attendance using face recognition
    - Validates active attendance session
    - Verifies face
    - Writes attendance to Firestore
    """

    # --------------------------------------------------
    # 1. VALIDATE SESSION TYPE
    # --------------------------------------------------
    if session_type not in ["morning", "afternoon"]:
        raise HTTPException(status_code=400, detail="Invalid session type")

    today = datetime.now().strftime("%Y-%m-%d")
    session_id = f"{class_id}_{today}_{session_type}"

    # --------------------------------------------------
    # 2. CHECK ATTENDANCE SESSION
    # --------------------------------------------------
    session_ref = db.collection("attendance_sessions").document(session_id)
    session_doc = session_ref.get()

    if not session_doc.exists:
        raise HTTPException(
            status_code=404,
            detail="Attendance session not started"
        )

    session_data = session_doc.to_dict()

    if not session_data.get("isActive"):
        raise HTTPException(
            status_code=400,
            detail="Attendance session ended"
        )

    # --------------------------------------------------
    # 3. LOAD STUDENT DATA
    # --------------------------------------------------
    student_ref = db.collection("students").document(student_uid)
    student_doc = student_ref.get()

    if not student_doc.exists:
        raise HTTPException(status_code=404, detail="Student not found")

    student_data = student_doc.to_dict()

    if student_data.get("classId") != class_id:
        raise HTTPException(status_code=403, detail="Invalid class")

    if not student_data.get("face_enabled"):
        raise HTTPException(
            status_code=400,
            detail="Face not registered"
        )

    stored_embedding = student_data.get("face_embedding")
    if not stored_embedding:
        raise HTTPException(
            status_code=400,
            detail="Face data missing"
        )

    stored_embedding = np.array(stored_embedding)

    # --------------------------------------------------
    # 4. READ & PROCESS IMAGE
    # --------------------------------------------------
    contents = await image.read()
    np_arr = np.frombuffer(contents, np.uint8)
    img = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)

    if img is None:
        raise HTTPException(status_code=400, detail="Invalid image")

    live_embedding = extract_face_embedding(img)

    # --------------------------------------------------
    # 5. FACE MATCH
    # --------------------------------------------------
    distance = face_recognition.face_distance(
        [stored_embedding], live_embedding
    )[0]

    if distance > FACE_MATCH_THRESHOLD:
        raise HTTPException(
            status_code=401,
            detail="Face verification failed"
        )

    # --------------------------------------------------
    # 6. SAVE ATTENDANCE
    # --------------------------------------------------
    attendance_ref = (
        db.collection("attendance")
        .document(session_id)
        .collection("students")
        .document(student_uid)
    )

    attendance_ref.set({
        "studentId": student_uid,
        "classId": class_id,
        "sessionType": session_type,
        "status": "present",
        "method": "face",
        "markedAt": datetime.utcnow(),
    })

    return {
        "success": True,
        "message": "Attendance marked successfully",
        "distance": round(float(distance), 4),
    }
