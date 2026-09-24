from bs4 import BeautifulSoup


def extract_student_pfp_base64(html: str) -> str | None:
    """
    Extracts the STUDENT's photo base64 code from VTOP profile HTML.
    Specifically isolates the student's photo from mentor/proctor/faculty photos.
    """
    try:
        soup = BeautifulSoup(html, "html.parser")

        # 1. Search for explicit student photo ID / alt / name / class
        for img in soup.find_all("img"):
            img_id = (img.get("id") or "").lower()
            img_alt = (img.get("alt") or "").lower()
            img_name = (img.get("name") or "").lower()
            if "student" in img_id or "student" in img_alt or "student" in img_name:
                src = img.get("src", "")
                if src.startswith("data:image"):
                    parts = src.split(",", 1)
                    if len(parts) > 1 and len(parts[1].strip()) > 50:
                        return parts[1].strip()

        # 2. Check candidate images that do NOT belong to proctor/faculty container
        student_candidates = []
        for img in soup.find_all("img"):
            src = img.get("src", "")
            if not src.startswith("data:image"):
                continue

            ancestor_text = ""
            for p in img.parents:
                ancestor_text += " " + (p.get("id") or "") + " " + (p.get("class") and " ".join(p.get("class")) or "") + " " + (p.name or "")

            ancestor_lower = ancestor_text.lower()
            img_attrs_lower = ((img.get("id") or "") + " " + (img.get("alt") or "") + " " + (img.get("class") and " ".join(img.get("class")) or "")).lower()

            is_proctor_or_faculty = any(
                k in ancestor_lower or k in img_attrs_lower
                for k in ["proctor", "faculty", "mentor", "dean", "hod", "staff", "teacher"]
            )

            parts = src.split(",", 1)
            if len(parts) > 1 and len(parts[1].strip()) > 50:
                b64 = parts[1].strip()
                if not is_proctor_or_faculty:
                    student_candidates.append(b64)

        if student_candidates:
            return student_candidates[0]

        # 3. Fallback: first valid image
        for img in soup.find_all("img"):
            src = img.get("src", "")
            if src.startswith("data:image"):
                parts = src.split(",", 1)
                if len(parts) > 1 and len(parts[1].strip()) > 50:
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
    try:
        soup = BeautifulSoup(html, "html.parser")

        # 1. Explicit faculty / proctor photo ID / alt
        for img in soup.find_all("img"):
            img_id = (img.get("id") or "").lower()
            img_alt = (img.get("alt") or "").lower()
            if any(k in img_id or k in img_alt for k in ["proctor", "faculty", "mentor", "staff"]):
                src = img.get("src", "")
                if src.startswith("data:image"):
                    parts = src.split(",", 1)
                    if len(parts) > 1 and len(parts[1].strip()) > 50:
                        return parts[1].strip()

        # 2. Return first base64 image on mentor page
        for img in soup.find_all("img"):
            src = img.get("src", "")
            if src.startswith("data:image"):
                parts = src.split(",", 1)
                if len(parts) > 1 and len(parts[1].strip()) > 50:
                    return parts[1].strip()

    except Exception:
        pass
    return None