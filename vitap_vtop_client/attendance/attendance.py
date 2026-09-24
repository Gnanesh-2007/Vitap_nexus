import time
from datetime import datetime, timezone

import httpx

from vitap_vtop_client.attendance.model.attendance_model import (
    AttendanceDetailModel,
    AttendanceModel,
)
from vitap_vtop_client.constants import (
    ATTENDANCE_URL,
    HEADERS,
    VIEW_ATTENDANCE_URL,
    VIEW_ATTENDANCE_DETAIL_URL,
)
from vitap_vtop_client.exceptions.exception import (
    VtopAttendanceError,
    VtopConnectionError,
    VtopParsingError,
)
from vitap_vtop_client.parsers import attendance_parser


async def fetch_attendance(
    client: httpx.AsyncClient,
    registration_number: str,
    semSubID: str,
    csrf_token: str,
) -> list[AttendanceModel]:
    """
    Retrieves attendance details for a specific student and semester.

    VTOP requires two requests for attendance:
        1. Initialize the attendance page.
        2. Request the actual attendance data.

    Parameters:
        client:
            The shared authenticated httpx.AsyncClient.

        registration_number:
            The student's registration number.

        semSubID:
            The semester subject ID.

        csrf_token:
            CSRF token used for authentication.

    Returns:
        list[AttendanceModel]:
            Parsed attendance data.

    Raises:
        VtopConnectionError:
            If an HTTP/network request fails.

        VtopAttendanceError:
            If an unexpected error occurs.

        VtopParsingError:
            If attendance parsing fails.
    """

    # ---------------------------------------------------------
    # STEP 1: Initialize the VTOP attendance page
    # ---------------------------------------------------------
    try:
        data_initial = {
            "verifyMenu": "true",
            "authorizedID": registration_number,
            "_csrf": csrf_token,
            "nocache": int(round(time.time() * 1000)),
        }

        initial_response = await client.post(
            ATTENDANCE_URL,
            data=data_initial,
            headers=HEADERS,
        )

        initial_response.raise_for_status()

    except httpx.RequestError as e:
        print(f"Attendance initial POST failed: {e}")

        raise VtopConnectionError(
            f"Failed to initialize attendance page: {e}",
            original_exception=e,
            status_code=502,
        ) from e

    except Exception as e:
        print(
            "An unexpected error occurred during "
            f"attendance initial POST: {e}"
        )

        raise VtopAttendanceError(
            f"Failed to initialize attendance page: {e}"
        ) from e

    # ---------------------------------------------------------
    # STEP 2: Fetch the actual attendance data
    # ---------------------------------------------------------
    try:
        data_fetch = {
            "_csrf": csrf_token,
            "semesterSubId": semSubID,
            "authorizedID": registration_number,
            "x": datetime.now(timezone.utc).strftime(
                "%a, %d %b %Y %H:%M:%S GMT"
            ),
        }

        attendance_response = await client.post(
            VIEW_ATTENDANCE_URL,
            data=data_fetch,
            headers=HEADERS,
        )

        attendance_response.raise_for_status()

        return attendance_parser.parse_attendance(
            attendance_response.text
        )

    except VtopParsingError:
        raise

    except httpx.RequestError as e:
        print(f"Attendance data fetch failed: {e}")

        raise VtopConnectionError(
            f"Failed to fetch attendance data: {e}",
            original_exception=e,
            status_code=502,
        ) from e

    except Exception as e:
        print(
            "An unexpected error occurred while fetching "
            f"or parsing attendance: {e}"
        )

        raise VtopAttendanceError(
            "An unexpected error occurred while fetching "
            f"attendance for semester {semSubID}: {e}"
        ) from e


async def fetch_attendance_detail(
    client: httpx.AsyncClient,
    registration_number: str,
    semSubID: str,
    course_id: str,
    course_type: str,
    csrf_token: str,
) -> list[AttendanceDetailModel]:
    """
    Retrieves per-class attendance details for a single course.

    This is a separate on-demand request and should only be called
    when detailed attendance for a particular course is required.

    Parameters:
        client:
            The shared authenticated httpx.AsyncClient.

        registration_number:
            The student's registration number.

        semSubID:
            The semester subject ID.

        course_id:
            The course ID.

        course_type:
            The short course type code.

        csrf_token:
            CSRF token used for authentication.

    Returns:
        list[AttendanceDetailModel]:
            One entry per class held.

    Raises:
        VtopConnectionError:
            If an HTTP/network request fails.

        VtopAttendanceError:
            If an unexpected error occurs.

        VtopParsingError:
            If attendance parsing fails.
    """

    try:
        data = {
            "_csrf": csrf_token,
            "semesterSubId": semSubID,
            "registerNumber": registration_number,
            "courseId": course_id,
            "courseType": course_type,
            "authorizedID": registration_number,
            "x": datetime.now(timezone.utc).strftime(
                "%a, %d %b %Y %H:%M:%S GMT"
            ),
        }

        response = await client.post(
            VIEW_ATTENDANCE_DETAIL_URL,
            data=data,
            headers=HEADERS,
        )

        response.raise_for_status()

        return attendance_parser.parse_full_attendance(
            response.text
        )

    except VtopParsingError:
        raise

    except httpx.RequestError as e:
        print(f"Attendance detail fetch failed: {e}")

        raise VtopConnectionError(
            f"Failed to fetch attendance detail: {e}",
            original_exception=e,
            status_code=502,
        ) from e

    except Exception as e:
        print(
            "An unexpected error occurred while fetching "
            f"attendance detail: {e}"
        )

        raise VtopAttendanceError(
            "An unexpected error occurred while fetching "
            f"attendance detail for course {course_id}: {e}"
        ) from e