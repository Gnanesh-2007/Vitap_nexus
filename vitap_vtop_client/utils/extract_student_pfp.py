import base64
import time
import httpx
from bs4 import BeautifulSoup
from vitap_vtop_client.constants import STUDENT_IMAGE_UPLOAD_URL, PFP_PATH, HEADERS


def extract_student_photo_url(html: str) -> str | None:
    """
    Extracts the image URL if the student photo is referenced via an endpoint
    (e.g., /vtop/others/photo/getStudentIdPhotoAndSign1 or users/image).
    """
    if not html:
        return None

    try:
        soup = BeautifulSoup(html, "html.parser")
        for img in soup.find_all("img"):
            src = img.get("src", "")
            if not src or src.startswith("data:image"):
                continue

            src_lower = src.lower()
            if any(k in src_lower for k in ["getstudentidphoto", "others/photo", "users/image", "studentphoto", "studentid"]):
                return src

            classes = " ".join(img.get("class", [])) if isinstance(img.get("class"), list) else (img.get("class") or "").lower()
            img_id = (img.get("id") or "").lower()
            img_alt = (img.get("alt") or "").lower()
            if "border-primary" in classes or "student" in img_id or "student" in img_alt:
                return src
    except Exception:
        pass
    return None


def extract_student_pfp_base64(html: str) -> str | None:
    """
    Extracts the STUDENT's photo base64 code from VTOP profile HTML.
    Specifically isolates the student's photo from mentor/proctor/faculty photos.
    Returns None if no EXPLICIT student photo is found (never falls back to mentor photo).
    """
    if not html:
        return None

    try:
        soup = BeautifulSoup(html, "html.parser")

        # 1. Primary check: VTOP standard student photo tag with 'border-primary'
        for img in soup.find_all("img"):
            classes = " ".join(img.get("class", [])) if isinstance(img.get("class"), list) else (img.get("class") or "")
            if "border-primary" in classes:
                src = img.get("src", "")
                if src.startswith("data:image"):
                    parts = src.split(",", 1)
                    if len(parts) > 1 and len(parts[1].strip()) > 50:
                        return parts[1].strip()

        # 2. Check for explicit student ID / alt / name
        for img in soup.find_all("img"):
            img_id = (img.get("id") or "").lower()
            img_alt = (img.get("alt") or "").lower()
            img_name = (img.get("name") or "").lower()
            if any(k in img_id or k in img_alt or k in img_name for k in ["student", "studphoto", "stud_photo", "studentphoto"]):
                src = img.get("src", "")
                if src.startswith("data:image"):
                    parts = src.split(",", 1)
                    if len(parts) > 1 and len(parts[1].strip()) > 50:
                        return parts[1].strip()

        # 3. Check images strictly inside a student details container
        for container in soup.find_all(["table", "div", "section"]):
            header = container.get_text(separator=" ")[:300].lower()
            # Must NOT be a proctor/mentor container
            if any(k in header for k in ["proctor", "mentor", "faculty advisor", "counsellor"]):
                continue
            # Must have student indicators
            if any(k in header for k in ["student profile", "student name", "application number", "date of birth", "blood group"]):
                for img in container.find_all("img"):
                    src = img.get("src", "")
                    if src.startswith("data:image"):
                        parts = src.split(",", 1)
                        if len(parts) > 1 and len(parts[1].strip()) > 50:
                            return parts[1].strip()

    except Exception:
        pass

    # DO NOT FALL BACK TO ARBITRARY BASE64 (prevents returning mentor photo)
    return None


def extract_pfp_base64(html: str) -> str | None:
    return extract_student_pfp_base64(html)


def extract_mentor_pfp_base64(html: str) -> str | None:
    """
    Extracts the FACULTY/MENTOR's photo base64 code from VTOP mentor HTML.
    """
    if not html:
        return None

    try:
        soup = BeautifulSoup(html, "html.parser")

        # 1. Explicit faculty / proctor photo ID / alt / class
        for img in soup.find_all("img"):
            img_id = (img.get("id") or "").lower()
            img_alt = (img.get("alt") or "").lower()
            classes = " ".join(img.get("class", [])) if isinstance(img.get("class"), list) else (img.get("class") or "").lower()
            if any(k in img_id or k in img_alt or k in classes for k in ["proctor", "faculty", "mentor", "staff", "border-secondary"]):
                src = img.get("src", "")
                if src.startswith("data:image"):
                    parts = src.split(",", 1)
                    if len(parts) > 1 and len(parts[1].strip()) > 50:
                        return parts[1].strip()

        # 2. Check candidate images inside proctor/mentor containers
        for container in soup.find_all(["table", "div", "section", "fieldset"]):
            header = container.get_text(separator=" ")[:200].lower()
            if any(k in header for k in ["proctor", "mentor", "faculty"]):
                for img in container.find_all("img"):
                    src = img.get("src", "")
                    if src.startswith("data:image"):
                        parts = src.split(",", 1)
                        if len(parts) > 1 and len(parts[1].strip()) > 50:
                            return parts[1].strip()

        # 3. Return first valid base64 image on mentor page (> 500 chars to avoid tiny icons)
        for img in soup.find_all("img"):
            src = img.get("src", "")
            if src.startswith("data:image"):
                parts = src.split(",", 1)
                if len(parts) > 1 and len(parts[1].strip()) > 500:
                    return parts[1].strip()

        # 4. Any base64 image
        for img in soup.find_all("img"):
            src = img.get("src", "")
            if src.startswith("data:image"):
                parts = src.split(",", 1)
                if len(parts) > 1 and len(parts[1].strip()) > 50:
                    return parts[1].strip()

    except Exception:
        pass
    return None


async def fetch_student_pfp(
    client: httpx.AsyncClient,
    registration_number: str,
    csrf_token: str,
    photo_url: str | None = None,
    application_number: str | None = None,
) -> str | None:
    """
    Fetches the student's ID photo directly from VTOP using STUDENT_IMAGE_UPLOAD_URL
    or the photo URL extracted from StudentProfileAllView.
    Returns base64 encoded string or None.
    """
    photo_headers = {
        **HEADERS,
        "Referer": "https://vtop.vitap.ac.in/vtop/studentsRecord/StudentProfileAllView",
        "Accept": "image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8",
    }

    ids_to_try = [registration_number]
    if application_number and application_number != registration_number:
        ids_to_try.append(application_number)

    candidates = []

    # 1. Dynamic URL found in StudentProfileAllView
    if photo_url:
        normalized_url = photo_url
        if not normalized_url.startswith("http"):
            if not normalized_url.startswith("/"):
                normalized_url = "/" + normalized_url
            if not normalized_url.startswith("/vtop"):
                normalized_url = "/vtop" + normalized_url
        candidates.append(("GET", normalized_url, None))
        for ident in ids_to_try:
            candidates.append(("POST", normalized_url, {"authorizedID": ident, "_csrf": csrf_token}))

    for ident in ids_to_try:
        # STUDENT_IMAGE_UPLOAD_URL with query parameter
        candidates.append(("GET", f"{STUDENT_IMAGE_UPLOAD_URL}?authorizedID={ident}", None))
        candidates.append(("GET", f"{STUDENT_IMAGE_UPLOAD_URL}?type=photo&authorizedID={ident}", None))
        candidates.append(("GET", f"{STUDENT_IMAGE_UPLOAD_URL}?type=1&authorizedID={ident}", None))

        # STUDENT_IMAGE_UPLOAD_URL with standard VTOP form data
        candidates.append((
            "POST",
            STUDENT_IMAGE_UPLOAD_URL,
            {
                'verifyMenu': 'true',
                'authorizedID': ident,
                '_csrf': csrf_token,
                'nocache': int(round(time.time() * 1000))
            }
        ))

        # Simple POST
        candidates.append(("POST", STUDENT_IMAGE_UPLOAD_URL, {'authorizedID': ident}))

        # PFP_PATH
        candidates.append(("GET", f"{PFP_PATH}{ident}", None))

    # Plain GET without params (cookie session identifies student)
    candidates.append(("GET", STUDENT_IMAGE_UPLOAD_URL, None))

    for method, url, data in candidates:
        try:
            if method == "POST":
                res = await client.post(url, data=data, headers=photo_headers, timeout=6.0)
            else:
                res = await client.get(url, headers=photo_headers, timeout=6.0)

            if res.status_code == 200 and len(res.content) > 100:
                # Binary image check (JPEG, PNG, GIF, WebP)
                if (
                    res.content.startswith(b'\xff\xd8\xff')
                    or res.content.startswith(b'\x89PNG')
                    or res.content.startswith(b'GIF8')
                    or res.content.startswith(b'RIFF')
                    or res.headers.get("content-type", "").startswith("image/")
                ):
                    return base64.b64encode(res.content).decode("utf-8")

                # Text check for data URI
                if res.text.startswith("data:image"):
                    parts = res.text.split(",", 1)
                    if len(parts) > 1 and len(parts[1].strip()) > 50:
                        return parts[1].strip()

                # HTML response containing img tag
                if "<img" in res.text:
                    soup = BeautifulSoup(res.text, "html.parser")
                    for img in soup.find_all("img"):
                        src = img.get("src", "")
                        if src.startswith("data:image"):
                            parts = src.split(",", 1)
                            if len(parts) > 1 and len(parts[1].strip()) > 50:
                                return parts[1].strip()

                # Plain base64 string
                clean_text = res.text.strip().strip('"').strip("'")
                if len(clean_text) > 200 and "<html" not in clean_text.lower() and "<!doctype" not in clean_text.lower():
                    try:
                        base64.b64decode(clean_text[:100] + "==")
                        return clean_text
                    except Exception:
                        pass
        except Exception:
            continue

    return None