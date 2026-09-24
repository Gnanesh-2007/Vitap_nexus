import time

import httpx

from vitap_vtop_client.constants import (
    EXAM_SCHEDULE_URL,
    GET_EXAM_SCHEDULE_URL,
    HEADERS,
)
from vitap_vtop_client.exam_schedule.model.exam_schedule_model import (
    ExamScheduleModel,
)
from vitap_vtop_client.parsers.exam_schedule_parser import parse_exam_schedule
from vitap_vtop_client.exceptions.exception import (
    VtopConnectionError,
    VtopExamScheduleError,
    VtopParsingError,
)


async def fetch_exam_schedule(
    client: httpx.AsyncClient,
    registration_number: str,
    semSubID: str,
    csrf_token: str,
) -> ExamScheduleModel:
    """
    Asynchronously retrieves the exam schedule for a specific user
    and semester.

    VTOP requires two requests for the exam schedule:
        1. Initialize the exam schedule page.
        2. Request the actual exam schedule data.

    Parameters:
        client:
            The shared authenticated httpx.AsyncClient.

        registration_number:
            The student's registration number.

        semSubID:
            The semester identifier for the exam schedule.

        csrf_token:
            CSRF token used for authentication.

    Returns:
        ExamScheduleModel:
            Parsed exam schedule information.

    Raises:
        VtopConnectionError:
            If network or HTTP issues occur.

        VtopExamScheduleError:
            If an unexpected error occurs.

        VtopParsingError:
            If exam schedule parsing fails.
    """

    # ---------------------------------------------------------
    # STEP 1: Initialize the VTOP exam schedule page
    # ---------------------------------------------------------
    try:
        verify_data = {
            "verifyMenu": "true",
            "authorizedID": registration_number,
            "_csrf": csrf_token,
            "nocache": int(round(time.time() * 1000)),
        }

        init_response = await client.post(
            EXAM_SCHEDULE_URL,
            data=verify_data,
            headers=HEADERS,
        )

        init_response.raise_for_status()

    except httpx.RequestError as e:
        print(f"Exam schedule initial POST failed: {e}")

        raise VtopConnectionError(
            f"Failed to initialize exam schedule page: {e}",
            original_exception=e,
            status_code=502,
        ) from e

    except Exception as e:
        print(
            f"An unexpected error occurred during "
            f"exam schedule initial POST: {e}"
        )

        raise VtopExamScheduleError(
            f"Failed to initialize exam schedule page: {e}"
        ) from e

    # ---------------------------------------------------------
    # STEP 2: Fetch the actual exam schedule
    # ---------------------------------------------------------
    try:
        data = {
            "authorizedID": registration_number,
            "semesterSubId": semSubID,
            "_csrf": csrf_token,
        }

        response = await client.post(
            GET_EXAM_SCHEDULE_URL,
            data=data,
            headers=HEADERS,
        )

        response.raise_for_status()

        return parse_exam_schedule(response.text)

    except VtopParsingError:
        raise

    except httpx.RequestError as e:
        print(f"Exam schedule fetch failed: {e}")

        raise VtopConnectionError(
            f"Failed to fetch exam schedule: {e}",
            original_exception=e,
            status_code=502,
        ) from e

    except Exception as e:
        print(f"Unexpected error while fetching exam schedule: {e}")

        raise VtopExamScheduleError(
            f"Unexpected error while fetching exam schedule: {e}"
        ) from e