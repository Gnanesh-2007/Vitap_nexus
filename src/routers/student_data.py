import asyncio

from fastapi import APIRouter, Depends, HTTPException, status, Response
from typing import List

from src.dependencies import verify_api_key
from src.routers.auth import get_vtop_client_from_header

from src.models.api_models import (
    BaseVtopRequest,
    AttendanceRequest,
    BiometricRequest,
    TimetableRequest,
    ExamScheduleRequest,
    MarksRequest,
    ComprehensiveDataRequest,
    ComprehensiveDataResponse,
    SubmitGeneralOutingRequest,
    SubmitWeekendOutingRequest,
    DeleteOutingRequest,
    CoursePageCoursesRequest,
    CoursePageSlotsRequest,
    CourseDetailRequest,
    DownloadCourseMaterialRequest,
    DownloadPaymentReceiptRequest,
    DigitalAssignmentsRequest,
    CourseAssignmentsRequest,
    DownloadAssignmentFileRequest,
)

from vitap_vtop_client.client import VtopClient

from vitap_vtop_client.attendance import AttendanceModel
from vitap_vtop_client.profile import StudentProfileModel
from vitap_vtop_client.timetable import TimetableModel
from vitap_vtop_client.biometric import BiometricModel
from vitap_vtop_client.grade_history import GradeHistoryModel
from vitap_vtop_client.mentor import MentorModel
from vitap_vtop_client.exam_schedule import ExamScheduleModel
from vitap_vtop_client.marks import MarksModel
from vitap_vtop_client.outing import (
    GeneralOutingModel,
    WeekendOutingModel,
)
from vitap_vtop_client.payments import (
    PendingPayment,
    PaymentReceipt,
)
from vitap_vtop_client.semester import SemesterData
from vitap_vtop_client.course_page import (
    CoursesResponseModel,
    SlotsResponseModel,
    CoursePageDetailModel,
)
from vitap_vtop_client.digital_assignment.model.digital_assignment_model import (
    DigitalAssignmentModel,
    AssignmentRecordModel,
)

from vitap_vtop_client.exceptions import VitapVtopClientError

from src.utils.handle_client_exception import handle_client_exception


router = APIRouter(
    prefix="/student",
    tags=["student"],
    dependencies=[Depends(verify_api_key)],
)


async def _ensure_sem_sub_id(client: VtopClient, sem_sub_id: str | None) -> str:
    if sem_sub_id and sem_sub_id.strip():
        return sem_sub_id.strip()
    try:
        sem_data = await client.get_semesters()
        if sem_data and sem_data.semesters:
            return sem_data.semesters[0].id
    except Exception:
        pass
    return sem_sub_id or ""


# ============================================================
# SEMESTERS
# ============================================================

@router.post("/semesters", response_model=SemesterData)
async def get_semesters(
    request: BaseVtopRequest,
    client: VtopClient = Depends(get_vtop_client_from_header),
):
    """
    Fetch available semesters using the already authenticated
    VTOP session.

    IMPORTANT:
    This does NOT create a new VtopClient and does NOT login again.
    """

    try:
        semesters = await client.get_semesters()
        return semesters

    except VitapVtopClientError as e:
        handle_client_exception(e)

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An unexpected error occurred: {e}",
        )


# ============================================================
# ALL STUDENT DATA
# ============================================================

@router.post(
    "/all_data",
    response_model=ComprehensiveDataResponse,
)
async def get_all_student_data(
    request: ComprehensiveDataRequest,
    client: VtopClient = Depends(get_vtop_client_from_header),
):
    """
    Fetch all dashboard data using the SAME authenticated
    VTOP client/session.
    """

    try:
        request.sem_sub_id = await _ensure_sem_sub_id(client, request.sem_sub_id)

        profile_task = client.get_profile()

        attendance_task = client.get_attendance(
            sem_sub_id=request.sem_sub_id
        )

        timetable_task = client.get_timetable(
            sem_sub_id=request.sem_sub_id
        )

        exam_schedule_task = client.get_exam_schedule(
            sem_sub_id=request.sem_sub_id
        )

        grade_history_task = client.get_grade_history()

        marks_task = client.get_marks(
            sem_sub_id=request.sem_sub_id
        )

        results = await asyncio.gather(
            profile_task,
            attendance_task,
            timetable_task,
            exam_schedule_task,
            grade_history_task,
            marks_task,
            return_exceptions=True,
        )

        profile_data = results[0] if not isinstance(results[0], Exception) else None
        attendance_data = results[1] if not isinstance(results[1], Exception) else None
        timetable_data = results[2] if not isinstance(results[2], Exception) else None
        exam_schedule_data = results[3] if not isinstance(results[3], Exception) else None
        grade_history_data = results[4] if not isinstance(results[4], Exception) else None
        marks_data = results[5] if not isinstance(results[5], Exception) else None

        comprehensive_data = ComprehensiveDataResponse(
            profile=profile_data,
            attendance=attendance_data,
            timetable=timetable_data,
            grade_history=grade_history_data,
            exam_schedule=exam_schedule_data,
            marks=marks_data,
        )

        return comprehensive_data

    except VitapVtopClientError as e:
        handle_client_exception(e)

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An unexpected error occurred: {e}",
        )


# ============================================================
# PROFILE
# ============================================================

@router.post(
    "/profile",
    response_model=StudentProfileModel,
)
async def get_profile(
    request: BaseVtopRequest,
    client: VtopClient = Depends(get_vtop_client_from_header),
):
    try:
        profile_data = await client.get_profile()
        return profile_data

    except VitapVtopClientError as e:
        handle_client_exception(e)

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An unexpected error occurred: {e}",
        )


# ============================================================
# ATTENDANCE
# ============================================================

@router.post(
    "/attendance",
    response_model=List[AttendanceModel],
)
async def get_attendance(
    request: AttendanceRequest,
    client: VtopClient = Depends(get_vtop_client_from_header),
):
    try:
        request.sem_sub_id = await _ensure_sem_sub_id(client, request.sem_sub_id)
        attendance_data = await client.get_attendance(
            sem_sub_id=request.sem_sub_id
        )

        return attendance_data

    except VitapVtopClientError as e:
        handle_client_exception(e)

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An unexpected error occurred: {e}",
        )


# ============================================================
# BIOMETRIC
# ============================================================

@router.post(
    "/biometric",
    response_model=List[BiometricModel],
)
async def get_biometric(
    request: BiometricRequest,
    client: VtopClient = Depends(get_vtop_client_from_header),
):
    try:
        biometric_logs = await client.get_biometric(
            date=request.date
        )

        return biometric_logs

    except VitapVtopClientError as e:
        handle_client_exception(e)

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An unexpected error occurred: {e}",
        )


# ============================================================
# TIMETABLE
# ============================================================

@router.post(
    "/timetable",
    response_model=TimetableModel,
)
async def get_timetable(
    request: TimetableRequest,
    client: VtopClient = Depends(get_vtop_client_from_header),
):
    try:
        request.sem_sub_id = await _ensure_sem_sub_id(client, request.sem_sub_id)
        timetable_data = await client.get_timetable(
            sem_sub_id=request.sem_sub_id
        )

        return timetable_data

    except VitapVtopClientError as e:
        handle_client_exception(e)

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An unexpected error occurred: {e}",
        )


# ============================================================
# GRADE HISTORY
# ============================================================

@router.post(
    "/grade_history",
    response_model=GradeHistoryModel,
)
async def get_grade_history(
    request: BaseVtopRequest,
    client: VtopClient = Depends(get_vtop_client_from_header),
):
    try:
        grade_history_data = await client.get_grade_history()

        return grade_history_data

    except VitapVtopClientError as e:
        handle_client_exception(e)

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An unexpected error occurred: {e}",
        )


# ============================================================
# MENTOR
# ============================================================

@router.post(
    "/mentor",
    response_model=MentorModel,
)
async def get_mentor(
    request: BaseVtopRequest,
    client: VtopClient = Depends(get_vtop_client_from_header),
):
    try:
        mentor_details = await client.get_mentor()

        return mentor_details

    except VitapVtopClientError as e:
        handle_client_exception(e)

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An unexpected error occurred: {e}",
        )


# ============================================================
# EXAM SCHEDULE
# ============================================================

@router.post(
    "/exam_schedule",
    response_model=ExamScheduleModel,
)
async def get_exam_schedule(
    request: ExamScheduleRequest,
    client: VtopClient = Depends(get_vtop_client_from_header),
):
    try:
        request.sem_sub_id = await _ensure_sem_sub_id(client, request.sem_sub_id)
        exam_schedule = await client.get_exam_schedule(
            sem_sub_id=request.sem_sub_id
        )

        return exam_schedule

    except VitapVtopClientError as e:
        handle_client_exception(e)

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An unexpected error occurred: {e}",
        )


# ============================================================
# MARKS
# ============================================================

@router.post(
    "/marks",
    response_model=MarksModel,
)
async def get_marks(
    request: MarksRequest,
    client: VtopClient = Depends(get_vtop_client_from_header),
):
    try:
        request.sem_sub_id = await _ensure_sem_sub_id(client, request.sem_sub_id)
        marks_data = await client.get_marks(
            sem_sub_id=request.sem_sub_id
        )

        return marks_data

    except VitapVtopClientError as e:
        handle_client_exception(e)

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An unexpected error occurred: {e}",
        )


# ============================================================
# GENERAL OUTING REQUESTS
# ============================================================

@router.post(
    "/general_outing_requests",
    response_model=GeneralOutingModel,
)
async def get_general_outing_responses(
    request: BaseVtopRequest,
    client: VtopClient = Depends(get_vtop_client_from_header),
):
    try:
        outing_data = await client.get_general_outing_requests()

        return outing_data

    except VitapVtopClientError as e:
        handle_client_exception(e)

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An unexpected error occurred: {e}",
        )


# ============================================================
# SUBMIT GENERAL OUTING
# ============================================================

@router.post("/submit_general_outing")
async def submit_general_outing_endpoint(
    request: SubmitGeneralOutingRequest,
    client: VtopClient = Depends(get_vtop_client_from_header),
):
    try:
        res = await client.submit_general_outing(
            out_place=request.out_place,
            purpose_of_visit=request.purpose_of_visit,
            outing_date=request.outing_date,
            out_time=request.out_time,
            in_date=request.in_date,
            in_time=request.in_time,
        )

        return {
            "message": res or "General outing submitted successfully."
        }

    except VitapVtopClientError as e:
        handle_client_exception(e)

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An unexpected error occurred: {e}",
        )


# ============================================================
# WEEKEND OUTING REQUESTS
# ============================================================

@router.post(
    "/weekend_outing_requests",
    response_model=WeekendOutingModel,
)
async def get_weekend_outing_responses(
    request: BaseVtopRequest,
    client: VtopClient = Depends(get_vtop_client_from_header),
):
    try:
        outing_data = await client.get_weekend_outing_requests()

        return outing_data

    except VitapVtopClientError as e:
        handle_client_exception(e)

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An unexpected error occurred: {e}",
        )


# ============================================================
# SUBMIT WEEKEND OUTING
# ============================================================

@router.post("/submit_weekend_outing")
async def submit_weekend_outing_endpoint(
    request: SubmitWeekendOutingRequest,
    client: VtopClient = Depends(get_vtop_client_from_header),
):
    try:
        res = await client.submit_weekend_outing(
            out_place=request.out_place,
            purpose_of_visit=request.purpose_of_visit,
            outing_date=request.outing_date,
            out_time=request.out_time,
            contact_number=request.contact_number,
        )

        return {
            "message": res or "Weekend outing submitted successfully."
        }

    except VitapVtopClientError as e:
        handle_client_exception(e)

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An unexpected error occurred: {e}",
        )


# ============================================================
# DELETE GENERAL OUTING
# ============================================================

@router.post("/delete_general_outing")
async def delete_general_outing_endpoint(
    request: DeleteOutingRequest,
    client: VtopClient = Depends(get_vtop_client_from_header),
):
    try:
        res = await client.delete_general_outing(
            leave_id=request.appl_id
        )

        return {
            "message": res or "Outing deleted successfully."
        }

    except VitapVtopClientError as e:
        handle_client_exception(e)

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An unexpected error occurred: {e}",
        )


# ============================================================
# DELETE WEEKEND OUTING
# ============================================================

@router.post("/delete_weekend_outing")
async def delete_weekend_outing_endpoint(
    request: DeleteOutingRequest,
    client: VtopClient = Depends(get_vtop_client_from_header),
):
    try:
        res = await client.delete_weekend_outing(
            booking_id=request.appl_id
        )

        return {
            "message": res or "Weekend outing deleted successfully."
        }

    except VitapVtopClientError as e:
        handle_client_exception(e)

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An unexpected error occurred: {e}",
        )


# ============================================================
# PENDING PAYMENTS
# ============================================================

@router.post(
    "/pending_payments",
    response_model=List[PendingPayment],
)
async def get_pending_payments(
    request: BaseVtopRequest,
    client: VtopClient = Depends(get_vtop_client_from_header),
):
    try:
        pending_payments = await client.get_pending_payments()

        return pending_payments

    except VitapVtopClientError as e:
        handle_client_exception(e)

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An unexpected error occurred: {e}",
        )


# ============================================================
# PAYMENT RECEIPTS
# ============================================================

@router.post(
    "/payment_receipts",
    response_model=List[PaymentReceipt],
)
async def get_payment_receipts(
    request: BaseVtopRequest,
    client: VtopClient = Depends(get_vtop_client_from_header),
):
    try:
        payment_receipts = await client.get_payment_receipts()

        return payment_receipts

    except VitapVtopClientError as e:
        handle_client_exception(e)

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An unexpected error occurred: {e}",
        )


# ============================================================
# COURSE PAGE COURSES
# ============================================================

@router.post(
    "/course_page_courses",
    response_model=CoursesResponseModel,
)
async def get_course_page_courses_endpoint(
    request: CoursePageCoursesRequest,
    client: VtopClient = Depends(get_vtop_client_from_header),
):
    try:
        request.sem_sub_id = await _ensure_sem_sub_id(client, request.sem_sub_id)
        await client.init_course_page()

        courses = await client.get_course_page_courses(
            sem_sub_id=request.sem_sub_id
        )

        return courses

    except VitapVtopClientError as e:
        handle_client_exception(e)

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An unexpected error occurred: {e}",
        )


# ============================================================
# COURSE PAGE SLOTS
# ============================================================

@router.post(
    "/course_page_slots",
    response_model=SlotsResponseModel,
)
async def get_course_page_slots_endpoint(
    request: CoursePageSlotsRequest,
    client: VtopClient = Depends(get_vtop_client_from_header),
):
    try:
        request.sem_sub_id = await _ensure_sem_sub_id(client, request.sem_sub_id)
        await client.init_course_page()

        slots = await client.get_course_page_slots(
            sem_sub_id=request.sem_sub_id,
            class_id=request.class_id,
        )

        return slots

    except VitapVtopClientError as e:
        handle_client_exception(e)

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An unexpected error occurred: {e}",
        )


# ============================================================
# COURSE DETAIL
# ============================================================

@router.post(
    "/course_detail",
    response_model=CoursePageDetailModel,
)
async def get_course_detail_endpoint(
    request: CourseDetailRequest,
    client: VtopClient = Depends(get_vtop_client_from_header),
):
    try:
        request.sem_sub_id = await _ensure_sem_sub_id(client, request.sem_sub_id)
        detail = await client.get_course_detail(
            sem_sub_id=request.sem_sub_id,
            erp_id=request.erp_id,
            class_id=request.class_id,
        )

        return detail

    except VitapVtopClientError as e:
        handle_client_exception(e)

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An unexpected error occurred: {e}",
        )


# ============================================================
# DOWNLOAD COURSE MATERIAL
# ============================================================

@router.post("/download_course_material")
async def download_course_material_endpoint(
    request: DownloadCourseMaterialRequest,
    client: VtopClient = Depends(get_vtop_client_from_header),
):
    try:
        file_bytes = await client.download_course_material(
            download_path=request.download_path
        )

        return Response(
            content=file_bytes,
            media_type="application/octet-stream",
            headers={
                "Content-Disposition": "attachment; filename=material.pdf"
            },
        )

    except VitapVtopClientError as e:
        handle_client_exception(e)

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An unexpected error occurred: {e}",
        )


# ============================================================
# DOWNLOAD PAYMENT RECEIPT
# ============================================================

@router.post("/download_payment_receipt")
async def download_payment_receipt_endpoint(
    request: DownloadPaymentReceiptRequest,
    client: VtopClient = Depends(get_vtop_client_from_header),
):
    try:
        receipt_html = await client.download_payment_receipt(
            receipt_no=request.receipt_no,
            application_number=request.application_number,
        )

        return Response(
            content=receipt_html,
            media_type="text/html",
            headers={
                "Content-Disposition":
                    f"attachment; filename=receipt_{request.receipt_no}.html"
            },
        )

    except VitapVtopClientError as e:
        handle_client_exception(e)

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An unexpected error occurred: {e}",
        )


# ============================================================
# SESSION COOKIES
# ============================================================

@router.post("/session_cookies")
async def get_session_cookies(
    request: BaseVtopRequest,
    client: VtopClient = Depends(get_vtop_client_from_header),
):
    """
    Return cookies from the EXISTING authenticated VTOP session.

    IMPORTANT:
    Do NOT call client.login() here.

    Calling client.login() would create another VTOP login flow
    and can trigger another OTP.
    """

    try:
        cookies = []

        for cookie in client._client.cookies.jar:
            cookies.append(
                {
                    "name": cookie.name,
                    "value": cookie.value,
                    "domain": cookie.domain or "vtop.vitap.ac.in",
                    "path": cookie.path or "/",
                    "secure": bool(cookie.secure),
                }
            )

        return {
            "cookies": cookies,
            "base_url": "https://vtop.vitap.ac.in",
        }

    except VitapVtopClientError as e:
        handle_client_exception(e)

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An unexpected error occurred: {e}",
        )


# ============================================================
# DIGITAL ASSIGNMENTS
# ============================================================

@router.post("/digital_assignments")
async def get_digital_assignments(
    request: DigitalAssignmentsRequest,
    client: VtopClient = Depends(get_vtop_client_from_header),
):
    try:
        request.sem_sub_id = await _ensure_sem_sub_id(client, request.sem_sub_id)
        result = await client.get_digital_assignments(
            request.sem_sub_id
        )

        return [
            r.model_dump()
            for r in result
        ]

    except VitapVtopClientError as e:
        handle_client_exception(e)

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Unexpected error: {e}",
        )


# ============================================================
# COURSE ASSIGNMENTS
# ============================================================

@router.post("/course_assignments")
async def get_course_assignments(
    request: CourseAssignmentsRequest,
    client: VtopClient = Depends(get_vtop_client_from_header),
):
    try:
        result = await client.get_course_assignments(
            request.class_id
        )

        return [
            r.model_dump()
            for r in result
        ]

    except VitapVtopClientError as e:
        handle_client_exception(e)

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Unexpected error: {e}",
        )


# ============================================================
# DOWNLOAD ASSIGNMENT FILE
# ============================================================

@router.post("/download_assignment_file")
async def download_assignment_file(
    request: DownloadAssignmentFileRequest,
    client: VtopClient = Depends(get_vtop_client_from_header),
):
    try:
        pdf_bytes = await client.download_assignment_file(
            request.download_url
        )

        return Response(
            content=pdf_bytes,
            media_type="application/pdf",
            headers={
                "Content-Disposition":
                    "attachment; filename=assignment.pdf"
            },
        )

    except VitapVtopClientError as e:
        handle_client_exception(e)

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Unexpected error: {e}",
        )