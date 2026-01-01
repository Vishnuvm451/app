import os
import pickle
import face_recognition
import numpy as np

# -------------------------------------------------
# LOCAL FACE DATABASE
# -------------------------------------------------
FACES_DB = "faces_db.pkl"


# -------------------------------------------------
# LOAD KNOWN FACES
# -------------------------------------------------
def load_known_faces():
    """
    Loads saved face encodings and admission numbers
    """
    if not os.path.exists(FACES_DB):
        return [], []

    with open(FACES_DB, "rb") as f:
        data = pickle.load(f)

    return data.get("encodings", []), data.get("admissions", [])


# -------------------------------------------------
# REGISTER FACE ENCODING
# -------------------------------------------------
def register_face_encoding(image, admission_no):
    """
    Extract and store face encoding for a student
    """
    rgb = image[:, :, ::-1]
    locations = face_recognition.face_locations(rgb)

    if len(locations) != 1:
        return False, "Exactly one face must be visible"

    encoding = face_recognition.face_encodings(rgb, locations)[0]

    if os.path.exists(FACES_DB):
        with open(FACES_DB, "rb") as f:
            data = pickle.load(f)
    else:
        data = {"encodings": [], "admissions": []}

    # Prevent duplicate registration
    if admission_no in data["admissions"]:
        return False, "Face already registered"

    data["encodings"].append(encoding)
    data["admissions"].append(admission_no)

    with open(FACES_DB, "wb") as f:
        pickle.dump(data, f)

    return True, "Face registered successfully"


# -------------------------------------------------
# EXTRACT FACE ENCODING
# -------------------------------------------------
def extract_face_encoding(image):
    """
    Extract face encoding from image
    """
    rgb = image[:, :, ::-1]
    locations = face_recognition.face_locations(rgb)

    if len(locations) != 1:
        return None

    encodings = face_recognition.face_encodings(rgb, locations)
    return encodings[0] if encodings else None


# -------------------------------------------------
# COMPARE FACE ENCODINGS
# -------------------------------------------------
def compare_faces(
    unknown_encoding,
    known_encodings,
    admissions,
    tolerance=0.45
):
    """
    Compare unknown face with known faces
    Returns admission number if matched
    """
    if not known_encodings:
        return None

    results = face_recognition.compare_faces(
        known_encodings,
        unknown_encoding,
        tolerance=tolerance
    )

    for i, matched in enumerate(results):
        if matched:
            return admissions[i]

    return None
