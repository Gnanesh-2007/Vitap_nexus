import re
from bs4 import BeautifulSoup
from vitap_vtop_client.exceptions import VtopParsingError
from vitap_vtop_client.profile.model import StudentProfileModel
from vitap_vtop_client.utils import extract_pfp_base64


def _match_field(label: str, val: str, profile_data: dict):
    if not val or val == ":" or val.lower() == "null" or val.lower() == "none":
        return

    clean_val = val.strip()

    if "APPLICATION" in label and ("NO" in label or "NUM" in label or "ID" in label):
        if not profile_data.get("application_number"):
            profile_data["application_number"] = clean_val
    elif "STUDENT NAME" in label or ("NAME" in label and "FATHER" not in label and "MOTHER" not in label and "HOSTEL" not in label and "FACULTY" not in label and "PROCTOR" not in label and "GUARDIAN" not in label):
        if not profile_data.get("student_name"):
            profile_data["student_name"] = clean_val
    elif "BIRTH" in label or "DOB" in label:
        if not profile_data.get("dob"):
            profile_data["dob"] = clean_val
    elif "GENDER" in label or "SEX" in label:
        if not profile_data.get("gender"):
            profile_data["gender"] = clean_val
    elif "BLOOD" in label:
        if not profile_data.get("blood_group"):
            profile_data["blood_group"] = clean_val
    elif "EMAIL" in label or "MAIL" in label:
        if not profile_data.get("email"):
            profile_data["email"] = clean_val


def parse_student_profile(html: str) -> StudentProfileModel:
    """
    Parses the HTML content of the student profile data with multi-column table,
    th/td, input tag, and raw cell fallback support.
    """
    try:
        soup = BeautifulSoup(html, "html.parser")
        profile_data = {
            "base64_pfp": extract_pfp_base64(html),
        }

        # 1. Parse table rows (handles 2-column, 3-column, label-value pairs)
        rows = soup.find_all("tr")
        for row in rows:
            cells = row.find_all(["td", "th"])
            if len(cells) >= 2:
                for idx in range(0, len(cells) - 1, 2):
                    label_text = cells[idx].get_text(separator=" ").upper().replace(":", "").replace("\xa0", " ").strip()
                    val_cell = None
                    for c in cells[idx + 1:]:
                        raw_val = c.get_text(separator=" ").replace("\xa0", " ").strip()
                        if raw_val and raw_val != ":":
                            val_cell = raw_val
                            break
                    if val_cell:
                        _match_field(label_text, val_cell, profile_data)

        # 2. Sequential search across all td/th cells as fallback
        all_cells = soup.find_all(["td", "th"])
        for i in range(len(all_cells) - 1):
            label = all_cells[i].get_text(separator=" ").upper().replace(":", "").replace("\xa0", " ").strip()
            for j in range(i + 1, min(i + 4, len(all_cells))):
                val = all_cells[j].get_text(separator=" ").replace("\xa0", " ").strip()
                if val and val != ":":
                    _match_field(label, val, profile_data)
                    break

        # 3. Check input tags (if profile uses form inputs)
        for inp in soup.find_all("input"):
            name_attr = (inp.get("name") or inp.get("id") or "").upper()
            val_attr = inp.get("value", "").strip()
            if val_attr:
                _match_field(name_attr, val_attr, profile_data)

        return StudentProfileModel(**profile_data, grade_history=None, mentor_details=None)

    except Exception as e:
        raise VtopParsingError(f"Failed to parse student profile data: {e}")
