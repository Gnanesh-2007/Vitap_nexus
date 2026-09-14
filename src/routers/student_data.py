import asyncio
from fastapi import APIRouter, Depends, HTTPException, status, Response
from typing import List
from src.dependencies import verify_api_key
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
from vitap_vtop_client.outing import GeneralOutingModel, WeekendOutingModel
from vitap_vtop_client.payments import PendingPayment, PaymentReceipt
from vitap_vtop_client.semester import SemesterData
from vitap_vtop_client.course_page import CoursesResponseModel, SlotsResponseModel, CoursePageDetailModel
from vitap_vtop_client.digital_assignment.model.digital_assignment_model import DigitalAssignmentModel, AssignmentRecordModel

from vitap_vtop_client.exceptions import VitapVtopClientError

from src.utils.handle_client_exception import handle_client_exception

router = APIRouter(
    prefix="/student",
    tags=["student"],
    dependencies=[Depends(verify_api_key)],
)

@router.post("/semesters", response_model=SemesterData)
async def get_semesters(request: BaseVtopRequest):
    """
    Fetches the list of available semesters for the student.
    Use the returned sem_sub_id values in all other endpoints.
    """
    try:
        async with VtopClient(
            registration_number=request.registration_number, password=request.password
        ) as client:
            semesters = await client.get_semesters()
            return semesters
    except VitapVtopClientError as e:
        handle_client_exception(e)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An unexpected error occurred: {e}",
        )

@router.post("/all_data", response_model=ComprehensiveDataResponse)
async def get_all_student_data(request: ComprehensiveDataRequest):
    try:
        async with VtopClient(
            registration_number=request.registration_number, password=request.password
        ) as client:
            profile_task = client.get_profile()
            attendance_task = client.get_attendance(sem_sub_id=request.sem_sub_id)
            timetable_task = client.get_timetable(sem_sub_id=request.sem_sub_id)
            exam_schedule_task = client.get_exam_schedule(sem_sub_id=request.sem_sub_id)
            grade_history_task = client.get_grade_history()
            marks_task = client.get_marks(sem_sub_id=request.sem_sub_id)

            (
                profile_data,
                attendance_data,
                timetable_data,
                exam_schedule_data,
                grade_history_data,
                marks_data,
            ) = await asyncio.gather(
                profile_task,
                attendance_task,
                timetable_task,
                exam_schedule_task,
                grade_history_task,
                marks_task,
            )

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

@router.post("/profile", response_model=StudentProfileModel)
async def get_profile(request: BaseVtopRequest):
    try:
        async with VtopClient(
            registration_number=request.registration_number, password=request.password
        ) as client:
            profile_data = await client.get_profile()
            return profile_data
    except VitapVtopClientError as e:
        handle_client_exception(e)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An unexpected error occurred: {e}",
        )

@router.post("/attendance", response_model=List[AttendanceModel])
async def get_attendance(request: AttendanceRequest):
    try:
        async with VtopClient(
            registration_number=request.registration_number, password=request.password
        ) as client:
            attendance_data = await client.get_attendance(sem_sub_id=request.sem_sub_id)
            return attendance_data
    except VitapVtopClientError as e:
        handle_client_exception(e)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An unexpected error occurred: {e}",
        )

@router.post("/biometric", response_model=List[BiometricModel])
async def get_biometric(request: BiometricRequest):
    try:
        async with VtopClient(
            registration_number=request.registration_number, password=request.password
        ) as client:
            biometric_logs = await client.get_biometric(date=request.date)
            return biometric_logs
    except VitapVtopClientError as e:
        handle_client_exception(e)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An unexpected error occurred: {e}",
        )

@router.post("/timetable", response_model=TimetableModel)
async def get_timetable(request: TimetableRequest):
    try:
        async with VtopClient(
            registration_number=request.registration_number, password=request.password
        ) as client:
            timetable_data = await client.get_timetable(sem_sub_id=request.sem_sub_id)
            return timetable_data
    except VitapVtopClientError as e:
        handle_client_exception(e)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An unexpected error occurred: {e}",
        )

@router.post("/grade_history", response_model=GradeHistoryModel)
async def get_grade_history(request: BaseVtopRequest):
    try:
        async with VtopClient(
            registration_number=request.registration_number, password=request.password
        ) as client:
            grade_history_data = await client.get_grade_history()
            return grade_history_data
    except VitapVtopClientError as e:
        handle_client_exception(e)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An unexpected error occurred: {e}",
        )

@router.post("/mentor", response_model=MentorModel)
async def get_mentor(request: BaseVtopRequest):
    try:
        async with VtopClient(
            registration_number=request.registration_number, password=request.password
        ) as client:
            mentor_details = await client.get_mentor()
            return mentor_details
    except VitapVtopClientError as e:
        handle_client_exception(e)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An unexpected error occurred: {e}",
        )

@router.post("/exam_schedule", response_model=ExamScheduleModel)
async def get_exam_schedule(request: ExamScheduleRequest):
    try:
        async with VtopClient(
            registration_number=request.registration_number, password=request.password
        ) as client:
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

@router.post("/marks", response_model=MarksModel)
async def get_marks(request: MarksRequest):
    try:
        async with VtopClient(
            registration_number=request.registration_number, password=request.password
        ) as client:
            exam_schedule = await client.get_marks(sem_sub_id=request.sem_sub_id)
            return exam_schedule
    except VitapVtopClientError as e:
        handle_client_exception(e)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An unexpected error occurred: {e}",
        )

@router.post("/general_outing_requests", response_model=GeneralOutingModel)
async def get_general_outing_responses(request: BaseVtopRequest):
    try:
        async with VtopClient(
            registration_number=request.registration_number, password=request.password
        ) as client:
            exam_schedule = await client.get_general_outing_requests()
            return exam_schedule
    except VitapVtopClientError as e:
        handle_client_exception(e)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An unexpected error occurred: {e}",
        )

@router.post("/submit_general_outing")
async def submit_general_outing_endpoint(request: SubmitGeneralOutingRequest):
    try:
        async with VtopClient(
            registration_number=request.registration_number, password=request.password
        ) as client:
            res = await client.submit_general_outing(
                out_place=request.out_place,
                purpose_of_visit=request.purpose_of_visit,
                outing_date=request.outing_date,
                out_time=request.out_time,
                in_date=request.in_date,
                in_time=request.in_time,
            )
            return {"message": res or "General outing submitted successfully."}
    except VitapVtopClientError as e:
        handle_client_exception(e)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An unexpected error occurred: {e}",
        )

@router.post("/weekend_outing_requests", response_model=WeekendOutingModel)
async def get_weekend_outing_responses(request: BaseVtopRequest):
    try:
        async with VtopClient(
            registration_number=request.registration_number, password=request.password
        ) as client:
            exam_schedule = await client.get_weekend_outing_requests()
            return exam_schedule
    except VitapVtopClientError as e:
        handle_client_exception(e)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An unexpected error occurred: {e}",
        )

@router.post("/submit_weekend_outing")
async def submit_weekend_outing_endpoint(request: SubmitWeekendOutingRequest):
    try:
        async with VtopClient(
            registration_number=request.registration_number, password=request.password
        ) as client:
            res = await client.submit_weekend_outing(
                out_place=request.out_place,
                purpose_of_visit=request.purpose_of_visit,
                outing_date=request.outing_date,
                out_time=request.out_time,
                contact_number=request.contact_number,
            )
            return {"message": res or "Weekend outing submitted successfully."}
    except VitapVtopClientError as e:
        handle_client_exception(e)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An unexpected error occurred: {e}",
        )

@router.post("/delete_general_outing")
async def delete_general_outing_endpoint(request: DeleteOutingRequest):
    try:
        async with VtopClient(
            registration_number=request.registration_number, password=request.password
        ) as client:
            res = await client.delete_general_outing(leave_id=request.appl_id)
            return {"message": res or "Outing deleted successfully."}
    except VitapVtopClientError as e:
        handle_client_exception(e)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An unexpected error occurred: {e}",
        )

@router.post("/delete_weekend_outing")
async def delete_weekend_outing_endpoint(request: DeleteOutingRequest):
    try:
        async with VtopClient(
            registration_number=request.registration_number, password=request.password
        ) as client:
            res = await client.delete_weekend_outing(booking_id=request.appl_id)
            return {"message": res or "Weekend outing deleted successfully."}
    except VitapVtopClientError as e:
        handle_client_exception(e)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An unexpected error occurred: {e}",
        )

@router.post("/pending_payments", response_model=List[PendingPayment])
async def get_pending_payments(request: BaseVtopRequest):
    try:
        async with VtopClient(
            registration_number=request.registration_number, password=request.password
        ) as client:
            pending_payments = await client.get_pending_payments()
            return pending_payments
    except VitapVtopClientError as e:
        handle_client_exception(e)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An unexpected error occurred: {e}",
        )

@router.post("/payment_receipts", response_model=List[PaymentReceipt])
async def get_payment_receipts(request: BaseVtopRequest):
    try:
        async with VtopClient(
            registration_number=request.registration_number, password=request.password
        ) as client:
            payment_receipts = await client.get_payment_receipts()
            return payment_receipts
    except VitapVtopClientError as e:
        handle_client_exception(e)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An unexpected error occurred: {e}",
        )

@router.post("/course_page_courses", response_model=CoursesResponseModel)
async def get_course_page_courses_endpoint(request: CoursePageCoursesRequest):
    try:
        async with VtopClient(
            registration_number=request.registration_number, password=request.password
        ) as client:
            await client.init_course_page()
            courses = await client.get_course_page_courses(sem_sub_id=request.sem_sub_id)
            return courses
    except VitapVtopClientError as e:
        handle_client_exception(e)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An unexpected error occurred: {e}",
        )

@router.post("/course_page_slots", response_model=SlotsResponseModel)
async def get_course_page_slots_endpoint(request: CoursePageSlotsRequest):
    try:
        async with VtopClient(
            registration_number=request.registration_number, password=request.password
        ) as client:
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

@router.post("/course_detail", response_model=CoursePageDetailModel)
async def get_course_detail_endpoint(request: CourseDetailRequest):
    try:
        async with VtopClient(
            registration_number=request.registration_number, password=request.password
        ) as client:
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

@router.post("/download_course_material")
async def download_course_material_endpoint(request: DownloadCourseMaterialRequest):
    try:
        async with VtopClient(
            registration_number=request.registration_number, password=request.password
        ) as client:
            file_bytes = await client.download_course_material(download_path=request.download_path)
            return Response(
                content=file_bytes,
                media_type="application/octet-stream",
                headers={"Content-Disposition": "attachment; filename=material.pdf"},
            )
    except VitapVtopClientError as e:
        handle_client_exception(e)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An unexpected error occurred: {e}",
        )

@router.post("/download_payment_receipt")
async def download_payment_receipt_endpoint(request: DownloadPaymentReceiptRequest):
    try:
        async with VtopClient(
            registration_number=request.registration_number, password=request.password
        ) as client:
            receipt_html = await client.download_payment_receipt(
                receipt_no=request.receipt_no,
                application_number=request.application_number,
            )
            return Response(
                content=receipt_html,
                media_type="text/html",
                headers={"Content-Disposition": f"attachment; filename=receipt_{request.receipt_no}.html"},
            )
    except VitapVtopClientError as e:
        handle_client_exception(e)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An unexpected error occurred: {e}",
        )

@router.post("/session_cookies")
async def get_session_cookies(request: BaseVtopRequest):
    """
    Logs the user into VTOP and returns all session cookies.
    The Flutter WebView can inject these to open VTOP already authenticated.
    """
    try:
        async with VtopClient(
            registration_number=request.registration_number, password=request.password
        ) as client:
            # Trigger login so cookies are set
            await client.login()

            # Extract all cookies from the underlying httpx client
            cookies = []
            for cookie in client._client.cookies.jar:
                cookies.append({
                    "name": cookie.name,
                    "value": cookie.value,
                    "domain": cookie.domain or "vtop.vitap.ac.in",
                    "path": cookie.path or "/",
                    "secure": bool(cookie.secure),
                })
            return {"cookies": cookies, "base_url": "https://vtop.vitap.ac.in"}
    except VitapVtopClientError as e:
        handle_client_exception(e)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"An unexpected error occurred: {e}",
        )



# --- Digital Assignments ---

@router.post("/digital_assignments")
async def get_digital_assignments(request: DigitalAssignmentsRequest):
    try:
        async with VtopClient(
            registration_number=request.registration_number, password=request.password
        ) as client:
            result = await client.get_digital_assignments(request.sem_sub_id)
            return [r.model_dump() for r in result]
    except VitapVtopClientError as e:
        handle_client_exception(e)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Unexpected error: {e}")


@router.post("/course_assignments")
async def get_course_assignments(request: CourseAssignmentsRequest):
    try:
        async with VtopClient(
            registration_number=request.registration_number, password=request.password
        ) as client:
            result = await client.get_course_assignments(request.class_id)
            return [r.model_dump() for r in result]
    except VitapVtopClientError as e:
        handle_client_exception(e)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Unexpected error: {e}")


@router.post("/download_assignment_file")
async def download_assignment_file(request: DownloadAssignmentFileRequest):
    try:
        async with VtopClient(
            registration_number=request.registration_number, password=request.password
        ) as client:
            pdf_bytes = await client.download_assignment_file(request.download_url)
            return Response(
                content=pdf_bytes,
                media_type="application/pdf",
                headers={"Content-Disposition": "attachment; filename=assignment.pdf"},
            )
    except VitapVtopClientError as e:
        handle_client_exception(e)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Unexpected error: {e}")
