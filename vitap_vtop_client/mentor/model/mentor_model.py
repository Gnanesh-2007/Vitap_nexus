from pydantic import BaseModel
from typing import Optional


class MentorModel(BaseModel):
    faculty_id: Optional[str] = None
    faculty_name: Optional[str] = None
    faculty_designation: Optional[str] = None
    school: Optional[str] = None
    cabin: Optional[str] = None
    faculty_department: Optional[str] = None
    faculty_email: Optional[str] = None
    faculty_intercom: Optional[str] = None
    faculty_mobile_number: Optional[str] = None
    base64_pfp: Optional[str] = None
