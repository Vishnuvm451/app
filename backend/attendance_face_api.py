from fastapi import APIRouter, UploadFile, File

router = APIRouter(
    prefix="/attendance",
    tags=["Face Attendance (Disabled)"]
)

@router.post("/mark")
async def mark_attendance_by_face(
    image: UploadFile = File(...)
):
    """
    ⚠️ Attendance is handled in Flutter.
    This endpoint is intentionally disabled
    to avoid duplicate attendance logic.
    """

    return {
        "success": False,
        "message": "Attendance is handled by the Flutter app"
    }
