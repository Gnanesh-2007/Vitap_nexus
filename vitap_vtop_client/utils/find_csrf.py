import re


def find_csrf(html: str) -> str | None:
    """
    Finds and returns the CSRF token from HTML content.
    Supports standard input tags and embedded JavaScript csrfValue definitions.
    Rejects dummy all-zero placeholder tokens.

    Args:
        html (str): The HTML content to search for the CSRF token.

    Returns:
        str or None: The CSRF token if found, otherwise None.
    """
    if not html:
        return None

    def _is_valid(val: str) -> bool:
        if not val or not val.strip():
            return False
        clean = val.strip().lower()
        if clean.startswith("00000000-0000-0000-0000-000000000000"):
            return False
        if re.match(r"^[0-]+$", clean):
            return False
        return True

    # 1. Search for JS variable definitions (e.g. var csrfValue = "...";)
    js_patterns = [
        r'var\s+csrfValue\s*=\s*["\']([0-9a-fA-F-]+)["\']',
        r'csrfValue\s*=\s*["\']([0-9a-fA-F-]+)["\']',
        r'["\']_csrf["\']\s*[:=]\s*["\']([0-9a-fA-F-]+)["\']',
        r'name=["\']_csrf["\']\s+value=["\']([0-9a-fA-F-]+)["\']',
        r'value=["\']([0-9a-fA-F-]+)["\']\s+name=["\']_csrf["\']',
    ]

    for pattern in js_patterns:
        matches = re.findall(pattern, html, re.IGNORECASE)
        for m in matches:
            if _is_valid(m):
                return m.strip()

    # 2. Search for standard hidden input tags
    input_patterns = [
        r'<input[^>]+name=["\']_csrf["\'][^>]+value=["\']([0-9a-fA-F-]+)["\']',
        r'<input[^>]+value=["\']([0-9a-fA-F-]+)["\'][^>]+name=["\']_csrf["\']',
    ]

    for pattern in input_patterns:
        matches = re.findall(pattern, html, re.IGNORECASE)
        for m in matches:
            if _is_valid(m):
                return m.strip()

    return None