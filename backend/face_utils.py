import cv2
import numpy as np
import face_recognition
from typing import List


# -------------------------------------------------
# LOAD IMAGE FROM BYTES
# -------------------------------------------------
def load_image_from_bytes(image_bytes: bytes) -> np.ndarray:
    """
    Convert image bytes to OpenCV image
    """
    np_arr = np.frombuffer(image_bytes, np.uint8)
    image = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)

    if image is None:
        raise ValueError("Invalid image data")

    return image


# -------------------------------------------------
# DETECT FACE LOCATIONS
# -------------------------------------------------
def detect_faces(image: np.ndarray) -> List[tuple]:
    """
    Detect face locations in an image
    Returns list of face bounding boxes
    """
    rgb_image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)

    face_locations = face_recognition.face_locations(
        rgb_image,
        model="hog"  # fast & reliable (cnn requires GPU)
    )

    return face_locations


# -------------------------------------------------
# EXTRACT FACE EMBEDDINGS
# -------------------------------------------------
def extract_face_embeddings(image: np.ndarray) -> List[List[float]]:
    """
    Extract 128-d face embeddings from image
    """
    rgb_image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)

    face_encodings = face_recognition.face_encodings(rgb_image)

    if not face_encodings:
        raise ValueError("No face detected")

    # Convert numpy arrays to Python lists (Firestore safe)
    return [encoding.tolist() for encoding in face_encodings]


# -------------------------------------------------
# VERIFY FACE (COMPARE EMBEDDINGS)
# -------------------------------------------------
def verify_face(
    known_embedding: List[float],
    unknown_embedding: List[float],
    threshold: float = 0.6,
) -> bool:
    """
    Compare two face embeddings
    """
    known = np.array(known_embedding)
    unknown = np.array(unknown_embedding)

    distance = np.linalg.norm(known - unknown)

    print(f"🔍 Face distance: {distance}")

    return distance <= threshold
