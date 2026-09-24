from bs4 import BeautifulSoup


def extract_pfp_base64(html: str):
    """
    Finds and returns the base64 code of the user's profile photo from HTML content.
    """
    try:
        soup = BeautifulSoup(html, "html.parser")

        # 1. Direct search for any image with base64 data URI
        for img in soup.find_all("img"):
            src = img.get("src", "")
            if src.startswith("data:image"):
                parts = src.split(",", 1)
                if len(parts) > 1 and len(parts[1].strip()) > 50:
                    return parts[1].strip()

        # 2. Check by class or ID
        userProfileTag = soup.find(
            "img",
            class_=lambda c: c and any(k in str(c).lower() for k in ["border", "img", "photo", "profile", "student"]),
        )
        if userProfileTag:
            src = userProfileTag.get("src", "")
            if "data:" in src and "," in src:
                return src.split(",", 1)[1].strip()

    except Exception:
        pass
    return None