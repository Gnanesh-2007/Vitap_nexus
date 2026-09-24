import re
from bs4 import BeautifulSoup

_OUTCOME_WORDS = ("Successfully", "Applied", "Deleted", "Approved", "Registered")
_FAILURE_WORDS = ("Error", "Failed", "Not Allowed", "Invalid", "Window", "Exceeded", "Pending")

# Boilerplate shown on the outing form that is not an error message.
_FORM_NOTICES = ("disciplinary measures", "logs will be retained")


def parse_outing_response(html: str) -> str:
    """
    Reads the outcome of an outing submission or deletion.
    """
    soup = BeautifulSoup(html, "lxml")

    # 1. Explicit error styling wins over everything else.
    for span in soup.select(
        "span[style*='color: red'], span[style*='color:red'], .error, .alert-danger, .alert-warning, .text-danger"
    ):
        text = span.get_text(strip=True)
        if text and not any(notice in text.lower() for notice in _FORM_NOTICES):
            return f"Error: {text}"

    # 2. Green span carrying the outcome (any class or structure).
    for span in soup.select(
        "span[style*='color: green'], span[style*='color:green'], span[style*='color: #008000'], .alert-success, .text-success"
    ):
        text = span.get_text(strip=True)
        if text and any(word.lower() in text.lower() for word in _OUTCOME_WORDS):
            return text

    # 3. SweetAlert modal heading & text (common in general outing).
    for el in soup.select("div.sweet-alert h2, div.sweet-alert p, .swal2-title, .swal2-html-container"):
        text = el.get_text(strip=True)
        if text:
            return text

    # 4. Check alert containers or message divs.
    for el in soup.select(".alert, #msg, #msgDiv, #message, #errMsg, #errorMessage"):
        text = el.get_text(strip=True)
        if text and not any(notice in text.lower() for notice in _FORM_NOTICES):
            return text

    # 5. Check script tags for alert('...') or swal('...')
    for script in soup.find_all("script"):
        stext = script.string or script.get_text()
        if stext:
            m = re.search(r"(?:alert|swal|toastr\.\w+)\s*\(\s*['\"]([^'\"]+)['\"]", stext)
            if m:
                msg = m.group(1).strip()
                if msg:
                    return msg

    # 6. Fall back to any heading/paragraph that reads like an outcome.
    for heading in soup.find_all(["h2", "h3", "h4", "h5", "b", "strong", "p"]):
        text = heading.get_text(strip=True)
        if text and any(
            word.lower() in text.lower() for word in _OUTCOME_WORDS + _FAILURE_WORDS
        ):
            return text

    # 7. If the response returned the table of requests, it was accepted and redirected!
    if soup.find("table", id="BookingRequests") is not None or "BookingRequests" in html:
        return "Weekend Outing Applied Successfully."

    if "LeaveRequests" in html or "LeaveId" in html:
        return "General Outing Applied Successfully."

    # 8. The form page coming back usually means the submission was rejected.
    if "outingForm" in html and ("Weekend Outing Request" in html or "General Outing Request" in html):
        for span in soup.select(
            "span.col-sm-12[style*='color'], span.col-md-12[style*='color'], span[style*='color']"
        ):
            text = span.get_text(strip=True)
            if text and not any(notice in text.lower() for notice in _FORM_NOTICES):
                return f"Error: {text}"

        return (
            "Submission may have failed - form page was returned. "
            "Please check outing history to verify."
        )

    return (
        "Outing request submitted. Please check outing history to verify."
    )
