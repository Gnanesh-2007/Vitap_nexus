from typing import List
import httpx
import asyncio

from .constants import VTOP_BASE_URL
from .ssl_config import create_vtop_ssl_context

from .exceptions import (
    VtopLoginError,
    VtopLoginOtpRequiredError,
    VtopCaptchaError,
    VtopCaptchaSolvingError,
    VtopConnectionError,
    VtopSessionError,
    VitapVtopClientError,
)

from .login import (
    fetch_csrf_token,
    pre_login,
    fetch_captcha,
    student_login,
    verify_login_otp,
    resend_login_otp,
    LoggedInStudent,
)

from .utils import solve_captcha

from .attendance import (
    fetch_attendance,
    fetch_attendance_detail,
    AttendanceModel,
    AttendanceDetailModel,
)

from .biometric import fetch_biometric, BiometricModel
from .timetable import fetch_timetable, TimetableModel
from .grade_history import fetch_grade_history, GradeHistoryModel
from .mentor import fetch_mentor_info, MentorModel
from .profile import fetch_profile, StudentProfileModel
from .exam_schedule import fetch_exam_schedule, ExamScheduleModel
from .marks import fetch_marks, MarksModel

from .outing import (
    fetch_general_outing_requests,
    fetch_weekend_outing_requests,
    submit_general_outing_request,
    submit_weekend_outing_request,
    delete_general_outing_request,
    delete_weekend_outing_request,
    fetch_general_outing_pdf,
    fetch_weekend_outing_pdf,
    WeekendOutingModel,
    GeneralOutingModel,
)

from .payments import (
    fetch_pending_payments,
    fetch_payment_receipts,
    fetch_payment_receipt_document,
    PendingPayment,
    PaymentReceipt,
)

from .semester import fetch_semesters, SemesterData

from .faculty import (
    fetch_faculty_search,
    fetch_all_faculty,
    fetch_faculty_details,
    FacultyModel,
    FacultyDetailsModel,
)

from .course_page import (
    init_course_page,
    fetch_courses_for_course_page,
    fetch_slots_for_course_page,
    fetch_course_detail,
    download_course_material,
    download_course_plan_excel,
    CoursesResponseModel,
    SlotsResponseModel,
    CoursePageDetailModel,
)

from .digital_assignment import (
    fetch_all_digital_assignments,
    fetch_per_course_dassignments,
    fetch_da_or_qp_pdf,
    upload_course_dassignment,
    verify_assignment_upload_otp,
    DigitalAssignmentModel,
    AssignmentRecordModel,
)

from .academic_calendar import (
    fetch_academic_calendar,
    fetch_calendar_months,
    fetch_calendar_month,
    fetch_calendar_class_groups,
    init_calendar_page,
    AcademicCalendarModel,
    CalendarDayModel,
    CalendarMonthRefModel,
    ClassGroupModel,
)


class VtopClient:
    """
    An asynchronous client for interacting with the VIT-AP VTOP portal.

    A single VtopClient owns one httpx.AsyncClient and therefore one VTOP
    cookie/session state. Once authenticated, all subsequent requests reuse
    that same session.
    """

    def __init__(
        self,
        registration_number: str,
        password: str,
        max_login_retries: int = 3,
        captcha_retries: int = 5,
    ):
        if not registration_number or not password:
            raise VtopLoginError(
                "Registration number and password are required for VtopClient.",
                status_code=400,
            )

        self.username = registration_number.upper()
        self.password = password

        self._client = httpx.AsyncClient(
            timeout=30.0,
            follow_redirects=True,
            base_url=VTOP_BASE_URL,
            verify=create_vtop_ssl_context(),
            limits=httpx.Limits(
                max_keepalive_connections=20,
                max_connections=40,
                keepalive_expiry=60.0,
            ),
        )

        self._logged_in_student: LoggedInStudent | None = None

        self.max_login_retries = max_login_retries
        self.captcha_retries = captcha_retries

        # Prevents multiple concurrent login attempts.
        self._login_lock = asyncio.Lock()

        # CSRF token from the OTP challenge page.
        self._pending_otp_csrf: str | None = None

    @property
    def otp_pending(self) -> bool:
        """Return True when VTOP is waiting for login OTP verification."""
        return self._pending_otp_csrf is not None

    async def login(self) -> LoggedInStudent:
        """
        Explicitly establishes a VTOP login session.

        If this VtopClient is already authenticated, the existing session is
        returned immediately. No second login or OTP request is performed.
        """

        async with self._login_lock:
            if self._logged_in_student is not None:
                return self._logged_in_student

            return await self._perform_login_sequence()

    async def verify_login_otp(self, otp: str) -> LoggedInStudent:
        """
        Completes a pending VTOP login using the OTP entered by the user.
        """

        if self._pending_otp_csrf is None:
            raise VtopSessionError(
                "No login OTP is pending. Call login() first.",
                status_code=409,
            )

        async with self._login_lock:
            logged_in_student = await verify_login_otp(
                self._client,
                self._pending_otp_csrf,
                otp,
            )

            self._logged_in_student = logged_in_student
            self._pending_otp_csrf = None

            return logged_in_student

    async def resend_login_otp(self) -> None:
        """
        Asks VTOP to send a fresh login OTP using the existing session.
        """

        if self._pending_otp_csrf is None:
            raise VtopSessionError(
                "No login OTP is pending. Call login() first.",
                status_code=409,
            )

        await resend_login_otp(
            self._client,
            self._pending_otp_csrf,
        )

    async def _perform_login_sequence(self) -> LoggedInStudent:
        """
        Performs the VTOP login sequence when no authenticated session exists.

        This method should only be called through login() or
        _ensure_logged_in().

        Once authentication succeeds, the resulting LoggedInStudent is stored
        in this VtopClient. Future calls reuse the existing authenticated
        session instead of starting another login/OTP flow.
        """

        for attempt in range(self.max_login_retries):
            print(
                f"VtopClient: Login attempt "
                f"{attempt + 1}/{self.max_login_retries} "
                f"for user {self.username[:5]}****"
            )

            try:
                # ---------------------------------------------------------
                # Step 1: Fetch initial CSRF token
                # ---------------------------------------------------------
                csrf_token = await fetch_csrf_token(self._client)

                print(
                    f"VtopClient: CSRF TOKEN: "
                    f"{csrf_token[:8]} - **** - **** - ************"
                )

                # ---------------------------------------------------------
                # Step 2: Pre-login setup
                # ---------------------------------------------------------
                await pre_login(
                    self._client,
                    csrf_token,
                )

                # ---------------------------------------------------------
                # Step 3: Fetch and solve CAPTCHA
                # ---------------------------------------------------------
                captcha_base64 = await fetch_captcha(
                    self._client,
                    retries=self.captcha_retries,
                )

                captcha_value = await asyncio.to_thread(
                    solve_captcha,
                    captcha_base64,
                )

                print(
                    f"VtopClient: Solved captcha: {captcha_value}"
                )

                # ---------------------------------------------------------
                # Step 4: Attempt login
                # ---------------------------------------------------------
                logged_in_student = await student_login(
                    self._client,
                    csrf_token,
                    self.username,
                    self.password,
                    captcha_value,
                )

                self._logged_in_student = logged_in_student

                print(
                    f"VtopClient: Login successful "
                    f"for {self.username[:5]}****"
                )

                return logged_in_student

            except VtopCaptchaError as e:
                print(
                    f"VtopClient: Captcha error during login: {e}"
                )

                if attempt == self.max_login_retries - 1:
                    raise

                await asyncio.sleep(1)

            except VtopCaptchaSolvingError as e:
                print(
                    f"VtopClient: Captcha solving failed during login: {e}"
                )

                if attempt == self.captcha_retries - 1:
                    raise

                await asyncio.sleep(1)

            except VtopLoginOtpRequiredError as e:
                print(
                    "VtopClient: VTOP requires an OTP "
                    "to complete the login."
                )

                # Preserve the OTP challenge on the SAME VtopClient.
                self._pending_otp_csrf = e.csrf_token

                raise

            except VtopLoginError as e:
                print(
                    "VtopClient: Login failed due to invalid "
                    f"credentials or format: {e}"
                )

                raise

            except VtopConnectionError:
                raise

            except VtopSessionError as e:
                print(
                    f"VtopClient: Session error "
                    f"(e.g., CSRF/session expired): {e}"
                )

                raise

            except Exception as e:
                print(
                    f"VtopClient: Unexpected error during login: {e}"
                )

                if attempt == self.max_login_retries - 1:
                    raise VitapVtopClientError(
                        f"Login failed after "
                        f"{self.max_login_retries} attempts "
                        f"due to unexpected error: {e}"
                    ) from e

                await asyncio.sleep(attempt + 1)

        raise VitapVtopClientError(
            f"Login failed for user {self.username} "
            f"after {self.max_login_retries} attempts."
        )

    async def _ensure_logged_in(self) -> LoggedInStudent:
        """
        Ensures that this VtopClient has an authenticated VTOP session.

        If already authenticated, returns immediately.

        If an OTP is pending, does NOT start another login because doing so
        could invalidate the OTP challenge already sent to the user.
        """

        # Fast path:
        # Already authenticated -> return immediately.
        if self._logged_in_student is not None:
            return self._logged_in_student

        # OTP is waiting for the user.
        if self._pending_otp_csrf is not None:
            raise VtopSessionError(
                "Login is awaiting OTP verification. "
                "Call verify_login_otp() with the OTP sent by VTOP "
                "before requesting data.",
                status_code=409,
            )

        async with self._login_lock:
            # Double-check after acquiring the lock.
            if self._logged_in_student is None:
                print(
                    f"VtopClient: Not logged in or session expired "
                    f"for {self.username[:5]}****. "
                    "Initiating login."
                )

                await self._perform_login_sequence()

            if self._logged_in_student is None:
                raise VitapVtopClientError(
                    "VtopClient: Failed to establish a login session."
                )

            return self._logged_in_student

    async def get_semesters(self) -> SemesterData:
        """Fetches the semesters available to the student."""

        student = await self._ensure_logged_in()

        return await fetch_semesters(
            client=self._client,
            username=student.registration_number,
            csrf_token=student.post_login_csrf_token,
        )

    async def get_attendance(
        self,
        sem_sub_id: str,
    ) -> list[AttendanceModel]:
        """Fetches attendance data for the given semester."""

        logged_in_info = await self._ensure_logged_in()

        return await fetch_attendance(
            client=self._client,
            registration_number=logged_in_info.registration_number,
            semSubID=sem_sub_id,
            csrf_token=logged_in_info.post_login_csrf_token,
        )

    async def get_attendance_detail(
        self,
        sem_sub_id: str,
        course_id: str,
        course_type: str,
    ) -> list[AttendanceDetailModel]:
        """Fetches detailed attendance for one course."""

        logged_in_info = await self._ensure_logged_in()

        return await fetch_attendance_detail(
            client=self._client,
            registration_number=logged_in_info.registration_number,
            semSubID=sem_sub_id,
            course_id=course_id,
            course_type=course_type,
            csrf_token=logged_in_info.post_login_csrf_token,
        )

    async def get_biometric(
        self,
        date: str,
    ) -> list[BiometricModel]:
        """Fetches biometric data for a given date."""

        logged_in_info = await self._ensure_logged_in()

        return await fetch_biometric(
            client=self._client,
            registration_number=logged_in_info.registration_number,
            date=date,
            csrf_token=logged_in_info.post_login_csrf_token,
        )

    async def get_timetable(
        self,
        sem_sub_id: str,
    ) -> TimetableModel:
        """Fetches timetable data for the given semester."""

        logged_in_info = await self._ensure_logged_in()

        return await fetch_timetable(
            client=self._client,
            username=logged_in_info.registration_number,
            semSubID=sem_sub_id,
            csrf_token=logged_in_info.post_login_csrf_token,
        )

    async def get_grade_history(self) -> GradeHistoryModel:
        """Fetches grade history."""

        logged_in_info = await self._ensure_logged_in()

        return await fetch_grade_history(
            client=self._client,
            registration_number=logged_in_info.registration_number,
            csrf_token=logged_in_info.post_login_csrf_token,
        )

    async def get_mentor(self) -> MentorModel:
        """Fetches mentor data."""

        logged_in_info = await self._ensure_logged_in()

        return await fetch_mentor_info(
            client=self._client,
            registration_number=logged_in_info.registration_number,
            csrf_token=logged_in_info.post_login_csrf_token,
        )

    async def get_profile(self) -> StudentProfileModel:
        """Fetches profile data."""

        logged_in_info = await self._ensure_logged_in()

        return await fetch_profile(
            client=self._client,
            registration_number=logged_in_info.registration_number,
            csrf_token=logged_in_info.post_login_csrf_token,
        )

    async def get_exam_schedule(
        self,
        sem_sub_id: str,
    ) -> ExamScheduleModel:
        """Fetches exam schedule."""

        logged_in_info = await self._ensure_logged_in()

        return await fetch_exam_schedule(
            client=self._client,
            registration_number=logged_in_info.registration_number,
            csrf_token=logged_in_info.post_login_csrf_token,
            semSubID=sem_sub_id,
        )

    async def get_marks(
        self,
        sem_sub_id: str,
    ) -> MarksModel:
        """Fetches marks."""

        logged_in_info = await self._ensure_logged_in()

        return await fetch_marks(
            client=self._client,
            registration_number=logged_in_info.registration_number,
            csrf_token=logged_in_info.post_login_csrf_token,
            semSubID=sem_sub_id,
        )

    async def get_weekend_outing_requests(
        self,
    ) -> WeekendOutingModel:
        """Fetches previously submitted weekend outing requests."""

        logged_in_info = await self._ensure_logged_in()

        return await fetch_weekend_outing_requests(
            client=self._client,
            registration_number=logged_in_info.registration_number,
            csrf_token=logged_in_info.post_login_csrf_token,
        )

    async def get_general_outing_requests(
        self,
    ) -> GeneralOutingModel:
        """Fetches previously submitted general outing requests."""

        logged_in_info = await self._ensure_logged_in()

        return await fetch_general_outing_requests(
            client=self._client,
            registration_number=logged_in_info.registration_number,
            csrf_token=logged_in_info.post_login_csrf_token,
        )

    async def get_pending_payments(
        self,
    ) -> List[PendingPayment]:
        """Fetches pending payments."""

        logged_in_info = await self._ensure_logged_in()

        return await fetch_pending_payments(
            client=self._client,
            registration_number=logged_in_info.registration_number,
            csrf_token=logged_in_info.post_login_csrf_token,
        )

    async def get_payment_receipts(
        self,
    ) -> List[PaymentReceipt]:
        """Fetches payment receipts."""

        logged_in_info = await self._ensure_logged_in()

        return await fetch_payment_receipts(
            client=self._client,
            registration_number=logged_in_info.registration_number,
            csrf_token=logged_in_info.post_login_csrf_token,
        )

    async def init_course_page(self) -> str:
        """
        Initializes the VTOP course page.

        VTOP requires this before course list and slot requests.
        """

        logged_in_info = await self._ensure_logged_in()

        return await init_course_page(
            client=self._client,
            username=logged_in_info.registration_number,
            csrf_token=logged_in_info.post_login_csrf_token,
        )

    async def get_course_page_courses(
        self,
        sem_sub_id: str,
    ) -> CoursesResponseModel:
        """Fetches courses available on the course page."""

        logged_in_info = await self._ensure_logged_in()

        return await fetch_courses_for_course_page(
            client=self._client,
            username=logged_in_info.registration_number,
            csrf_token=logged_in_info.post_login_csrf_token,
            semSubID=sem_sub_id,
        )

    async def get_course_page_slots(
        self,
        sem_sub_id: str,
        class_id: str,
    ) -> SlotsResponseModel:
        """Fetches course slots and class rows."""

        logged_in_info = await self._ensure_logged_in()

        return await fetch_slots_for_course_page(
            client=self._client,
            username=logged_in_info.registration_number,
            csrf_token=logged_in_info.post_login_csrf_token,
            semSubID=sem_sub_id,
            class_id=class_id,
        )

    async def get_course_detail(
        self,
        sem_sub_id: str,
        erp_id: str,
        class_id: str,
    ) -> CoursePageDetailModel:
        """Fetches course details."""

        logged_in_info = await self._ensure_logged_in()

        return await fetch_course_detail(
            client=self._client,
            username=logged_in_info.registration_number,
            csrf_token=logged_in_info.post_login_csrf_token,
            semSubID=sem_sub_id,
            erp_id=erp_id,
            class_id=class_id,
        )

    async def download_course_material(
        self,
        download_path: str,
    ) -> bytes:
        """Downloads course material."""

        logged_in_info = await self._ensure_logged_in()

        return await download_course_material(
            client=self._client,
            username=logged_in_info.registration_number,
            csrf_token=logged_in_info.post_login_csrf_token,
            download_path=download_path,
        )

    async def download_course_plan(
        self,
        sem_sub_id: str,
        class_id: str,
    ) -> bytes:
        """Downloads a course plan Excel workbook."""

        logged_in_info = await self._ensure_logged_in()

        return await download_course_plan_excel(
            client=self._client,
            username=logged_in_info.registration_number,
            csrf_token=logged_in_info.post_login_csrf_token,
            semSubID=sem_sub_id,
            class_id=class_id,
        )

    async def submit_general_outing(
        self,
        out_place: str,
        purpose_of_visit: str,
        outing_date: str,
        out_time: str,
        in_date: str,
        in_time: str,
    ) -> str:
        """Submits a general outing request."""

        logged_in_info = await self._ensure_logged_in()

        return await submit_general_outing_request(
            client=self._client,
            registration_number=logged_in_info.registration_number,
            csrf_token=logged_in_info.post_login_csrf_token,
            outPlace=out_place,
            purposeOfVisit=purpose_of_visit,
            outingDate=outing_date,
            outTime=out_time,
            inDate=in_date,
            inTime=in_time,
        )

    async def submit_weekend_outing(
        self,
        out_place: str,
        purpose_of_visit: str,
        outing_date: str,
        out_time: str,
        contact_number: str,
    ) -> str:
        """Submits a weekend outing request."""

        logged_in_info = await self._ensure_logged_in()

        return await submit_weekend_outing_request(
            client=self._client,
            registration_number=logged_in_info.registration_number,
            csrf_token=logged_in_info.post_login_csrf_token,
            outPlace=out_place,
            purposeOfVisit=purpose_of_visit,
            outingDate=outing_date,
            outTime=out_time,
            contactNumber=contact_number,
        )

    async def delete_general_outing(
        self,
        leave_id: str,
    ) -> str:
        """Deletes a general outing request."""

        logged_in_info = await self._ensure_logged_in()

        return await delete_general_outing_request(
            client=self._client,
            registration_number=logged_in_info.registration_number,
            csrf_token=logged_in_info.post_login_csrf_token,
            leave_id=leave_id,
        )

    async def delete_weekend_outing(
        self,
        booking_id: str,
    ) -> str:
        """Deletes a weekend outing request."""

        logged_in_info = await self._ensure_logged_in()

        return await delete_weekend_outing_request(
            client=self._client,
            registration_number=logged_in_info.registration_number,
            csrf_token=logged_in_info.post_login_csrf_token,
            booking_id=booking_id,
        )

    async def download_general_outing_pass(
        self,
        leave_id: str,
    ) -> bytes:
        """Downloads the general outing leave pass."""

        logged_in_info = await self._ensure_logged_in()

        return await fetch_general_outing_pdf(
            client=self._client,
            registration_number=logged_in_info.registration_number,
            csrf_token=logged_in_info.post_login_csrf_token,
            leave_id=leave_id,
        )

    async def download_weekend_outing_form(
        self,
        booking_id: str,
    ) -> bytes:
        """Downloads the weekend outing form."""

        logged_in_info = await self._ensure_logged_in()

        return await fetch_weekend_outing_pdf(
            client=self._client,
            registration_number=logged_in_info.registration_number,
            csrf_token=logged_in_info.post_login_csrf_token,
            booking_id=booking_id,
        )

    async def download_payment_receipt(
        self,
        receipt_no: str,
        application_number: str,
    ) -> str:
        """Downloads the printable payment receipt."""

        logged_in_info = await self._ensure_logged_in()

        return await fetch_payment_receipt_document(
            client=self._client,
            registration_number=logged_in_info.registration_number,
            csrf_token=logged_in_info.post_login_csrf_token,
            receipt_no=receipt_no,
            application_number=application_number,
        )

    async def get_digital_assignments(
        self,
        sem_sub_id: str,
    ) -> List[DigitalAssignmentModel]:
        """
        Fetches all digital assignments for the given semester.

        The underlying module performs the per-course requests concurrently.
        """

        logged_in_info = await self._ensure_logged_in()

        return await fetch_all_digital_assignments(
            client=self._client,
            username=logged_in_info.registration_number,
            csrf_token=logged_in_info.post_login_csrf_token,
            semSubID=sem_sub_id,
        )

    async def get_course_assignments(
        self,
        class_id: str,
    ) -> List[AssignmentRecordModel]:
        """Fetches assignments for one course."""

        logged_in_info = await self._ensure_logged_in()

        return await fetch_per_course_dassignments(
            client=self._client,
            username=logged_in_info.registration_number,
            csrf_token=logged_in_info.post_login_csrf_token,
            class_id=class_id,
        )

    async def download_assignment_file(
        self,
        download_url: str,
    ) -> bytes:
        """Downloads an assignment question paper or submission."""

        logged_in_info = await self._ensure_logged_in()

        return await fetch_da_or_qp_pdf(
            client=self._client,
            username=logged_in_info.registration_number,
            csrf_token=logged_in_info.post_login_csrf_token,
            download_url=download_url,
        )

    async def upload_assignment(
        self,
        class_id: str,
        mcode: str,
        file_name: str,
        file_bytes: bytes,
    ) -> str:
        """Uploads an assignment submission."""

        logged_in_info = await self._ensure_logged_in()

        return await upload_course_dassignment(
            client=self._client,
            username=logged_in_info.registration_number,
            csrf_token=logged_in_info.post_login_csrf_token,
            class_id=class_id,
            mcode=mcode,
            file_name=file_name,
            file_bytes=file_bytes,
        )

    async def verify_assignment_upload_otp(
        self,
        otp: str,
    ) -> str:
        """Verifies an OTP for a pending assignment upload."""

        logged_in_info = await self._ensure_logged_in()

        return await verify_assignment_upload_otp(
            client=self._client,
            username=logged_in_info.registration_number,
            csrf_token=logged_in_info.post_login_csrf_token,
            otp=otp,
        )

    async def search_faculty(
        self,
        search_term: str,
    ) -> FacultyModel:
        """Searches for a faculty member."""

        logged_in_info = await self._ensure_logged_in()

        return await fetch_faculty_search(
            client=self._client,
            username=logged_in_info.registration_number,
            csrf_token=logged_in_info.post_login_csrf_token,
            search_term=search_term,
        )

    async def get_all_faculty(self) -> List[FacultyModel]:
        """Fetches the complete faculty directory."""

        logged_in_info = await self._ensure_logged_in()

        return await fetch_all_faculty(
            client=self._client,
            username=logged_in_info.registration_number,
            csrf_token=logged_in_info.post_login_csrf_token,
        )

    async def get_faculty_details(
        self,
        emp_id: str,
    ) -> FacultyDetailsModel:
        """Fetches details for one faculty member."""

        logged_in_info = await self._ensure_logged_in()

        return await fetch_faculty_details(
            client=self._client,
            username=logged_in_info.registration_number,
            csrf_token=logged_in_info.post_login_csrf_token,
            emp_id=emp_id,
        )

    async def get_academic_calendar(
        self,
        sem_sub_id: str,
        class_group_id: str = "COMB",
    ) -> AcademicCalendarModel:
        """Fetches the complete academic calendar for a semester."""
        logged_in_info = await self._ensure_logged_in()
        return await fetch_academic_calendar(
            client=self._client,
            username=logged_in_info.registration_number,
            csrf_token=logged_in_info.post_login_csrf_token,
            semSubID=sem_sub_id,
            classGroupID=class_group_id,
        )

    async def get_calendar_months(
        self,
        sem_sub_id: str,
        class_group_id: str = "COMB",
    ) -> List[CalendarMonthRefModel]:
        """Fetches the months covered by the academic calendar."""
        logged_in_info = await self._ensure_logged_in()
        return await fetch_calendar_months(
            client=self._client,
            username=logged_in_info.registration_number,
            csrf_token=logged_in_info.post_login_csrf_token,
            semSubID=sem_sub_id,
            classGroupID=class_group_id,
        )

    async def get_calendar_month(
        self,
        sem_sub_id: str,
        cal_date: str,
        class_group_id: str = "COMB",
    ) -> List[CalendarDayModel]:
        """Fetches days and events for a single month in the academic calendar."""
        logged_in_info = await self._ensure_logged_in()
        return await fetch_calendar_month(
            client=self._client,
            username=logged_in_info.registration_number,
            csrf_token=logged_in_info.post_login_csrf_token,
            semSubID=sem_sub_id,
            cal_date=cal_date,
            classGroupID=class_group_id,
        )

    async def get_calendar_class_groups(
        self,
        sem_sub_id: str,
    ) -> List[ClassGroupModel]:
        """Fetches selectable class groups for the calendar."""
        logged_in_info = await self._ensure_logged_in()
        return await fetch_calendar_class_groups(
            client=self._client,
            username=logged_in_info.registration_number,
            csrf_token=logged_in_info.post_login_csrf_token,
            semSubID=sem_sub_id,
        )

    async def close(self):
        """Closes the underlying HTTP client."""

        await self._client.aclose()

    async def __aenter__(self):
        """Allows using VtopClient with async with."""

        return self

    async def __aexit__(
        self,
        exc_type,
        exc_val,
        exc_tb,
    ):
        """Closes the client when leaving the async context."""

        await self.close()