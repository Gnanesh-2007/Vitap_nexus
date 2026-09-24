import base64
from bs4 import BeautifulSoup


def extract_student_pfp_base64(html: str) -> str | None:
    """
    Extracts the STUDENT's photo base64 code from VTOP profile HTML.
    Specifically isolates the student's photo from mentor/proctor/faculty photos.
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

        # 3. Check candidate images that do NOT belong to an immediate proctor/faculty container
        student_candidates = []
        for img in soup.find_all("img"):
            src = img.get("src", "")
            if not src.startswith("data:image"):
                continue

            parts = src.split(",", 1)
            if len(parts) <= 1 or len(parts[1].strip()) <= 50:
                continue
            b64 = parts[1].strip()

            # Inspect immediate 3 parent levels (e.g. td, tr, table, card)
            is_proctor_or_faculty = False
            current = img.parent
            level = 0
            while current and level < 4:
                p_text = (current.get("id") or "") + " " + (" ".join(current.get("class", [])) if isinstance(current.get("class"), list) else "")
                p_header = ""
                if current.name in ["table", "div", "section", "fieldset", "tr"]:
                    p_header = current.get_text(separator=" ")[:200].lower()

                check_str = (p_text + " " + p_header).lower()
                if any(k in check_str for k in ["proctor", "mentor", "faculty advisor", "faculty details"]):
                    is_proctor_or_faculty = True
                    break
                current = current.parent
                level += 1

            if not is_proctor_or_faculty:
                student_candidates.append(b64)

        if student_candidates:
            return student_candidates[0]

        # 4. Fallback: first valid base64 image (skip small icons < 500 chars)
        for img in soup.find_all("img"):
            src = img.get("src", "")
            if src.startswith("data:image"):
                parts = src.split(",", 1)
                if len(parts) > 1 and len(parts[1].strip()) > 500:
                    return parts[1].strip()

    except Exception:
        pass
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