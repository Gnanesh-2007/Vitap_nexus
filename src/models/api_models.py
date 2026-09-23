from pydantic import BaseModel
from typing import List, Optional

# Import models from your client library for responses
from vitap_vtop_client.attendance import AttendanceModel
from vitap_vtop_client.attendance.model.attendance_model import AttendanceDetailModel
from vitap_vtop_client.profile import StudentProfileModel
from vitap_vtop_client.timetable import TimetableModel
from vitap_vtop_client.grade_history import GradeHistoryModel
from vitap_vtop_client.marks import MarksModel
from vitap_vtop_client.exam_schedule import ExamScheduleModel

# --- Request Models ---
class BaseVtopRequest(BaseModel):
    """Base model for requests that require VTOP credentials."""
    registration_number: str
    password: str

class AttendanceRequest(BaseVtopRequest):
    """Request model for fetching attendance."""
    sem_sub_id: str

class AttendanceDetailRequest(BaseVtopRequest):
    """Request model for fetching per-course attendance detail."""
    sem_sub_id: str
    course_id: str
    course_type: str

class BiometricRequest(BaseVtopRequest):
    """Request model for fetching biometric data."""
    date: str

class TimetableRequest(BaseVtopRequest):
    """Request model for fetching timetable."""
    sem_sub_id: str

class ExamScheduleRequest(BaseVtopRequest):
    """Request model for fetching exam schedules."""
    sem_sub_id: str

class MarksRequest(BaseVtopRequest):
    """Request model for fetching all marks."""
    sem_sub_id: str

class ComprehensiveDataRequest(BaseVtopRequest):
    """Request model for fetching all comprehensive student data."""
    sem_sub_id: str

class ComprehensiveDataResponse(BaseModel):
    """Response model for the comprehensive student data endpoint."""
    profile: Optional[StudentProfileModel] = None
    attendance: Optional[List[AttendanceModel]] = None
    timetable: Optional[TimetableModel] = None
    exam_schedule: Optional[ExamScheduleModel] = None
    grade_history: Optional[GradeHistoryModel] = None
    marks: Optional[MarksModel] = None

class SubmitGeneralOutingRequest(BaseVtopRequest):
    out_place: str
    purpose_of_visit: str
    outing_date: str
    out_time: str
    in_date: str
    in_time: str

class SubmitWeekendOutingRequest(BaseVtopRequest):
    out_place: str
    purpose_of_visit: str
    outing_date: str
    out_time: str
    contact_number: str

class DeleteOutingRequest(BaseVtopRequest):
    appl_id: str

class CoursePageCoursesRequest(BaseVtopRequest):
    sem_sub_id: str

class CoursePageSlotsRequest(BaseVtopRequest):
    sem_sub_id: str
    class_id: str

class CourseDetailRequest(BaseVtopRequest):
    sem_sub_id: str
    erp_id: str
    class_id: str

class DownloadCourseMaterialRequest(BaseVtopRequest):
    download_path: str

class DownloadPaymentReceiptRequest(BaseVtopRequest):
    receipt_no: str
    application_number: str

class DigitalAssignmentsRequest(BaseVtopRequest):
    sem_sub_id: str

class CourseAssignmentsRequest(BaseVtopRequest):
    class_id: str

class DownloadAssignmentFileRequest(BaseVtopRequest):
    download_url: str


class DownloadGeneralOutingPassRequest(BaseVtopRequest):
    leave_id: str


class DownloadWeekendOutingFormRequest(BaseVtopRequest):
    booking_id: str


class FacultySearchRequest(BaseVtopRequest):
    search_term: Optional[str] = ""


class FacultyDetailsRequest(BaseVtopRequest):
    emp_id: str


class AcademicCalendarRequest(BaseVtopRequest):
    sem_sub_id: Optional[str] = ""
    class_group_id: Optional[str] = "COMB"


class CalendarMonthRequest(BaseVtopRequest):
    sem_sub_id: Optional[str] = ""
    cal_date: str
    class_group_id: Optional[str] = "COMB"


class CalendarClassGroupsRequest(BaseVtopRequest):
    sem_sub_id: Optional[str] = ""

