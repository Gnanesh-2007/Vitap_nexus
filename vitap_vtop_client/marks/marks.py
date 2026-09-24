from datetime import datetime, timezone
import time

import httpx

from vitap_vtop_client.constants import (
    MARKS_URL,
    VIEW_MARKS_URL,
    HEADERS,
)
from vitap_vtop_client.marks.model.marks_model import MarksModel
from vitap_vtop_client.parsers.marks_parser import parse_marks
from vitap_vtop_client.exceptions.exception import (
    VtopConnectionError,
    VtopAttendanceError,
    VtopParsingError,
)


async def fetch_marks(
    client: httpx.AsyncClient,
    registration_number: str,
    semSubID: str,
    csrf_token: str,
) -> MarksModel:
    """
    Asynchronously retrieves all available marks for a specified semester.

    VTOP requires two requests for marks:
        1. Initialize the marks page.
        2. Request the actual marks data.

    Parameters:
        client:
            The shared authenticated httpx.AsyncClient.

        registration_number:
            The student's registration number.

        semSubID:
            The semester subject ID for which marks are being fetched.

        csrf_token:
            CSRF token used for authentication.

    Returns:
        MarksModel:
            Parsed marks information.

    Raises:
        VtopConnectionError:
            If an HTTP/network error occurs.

        VtopAttendanceError:
            If an unexpected error occurs.

        VtopParsingError:
            If marks parsing fails.
    """

    # ---------------------------------------------------------
    # STEP 1: Initialize the VTOP marks page
    # ---------------------------------------------------------
    try:
        init_data = {
            "verifyMenu": "true",
            "authorizedID": registration_number,
            "_csrf": csrf_token,
            "nocache": int(round(time.time() * 1000)),
        }

        init_response = await client.post(
            MARKS_URL,
            data=init_data,
            headers=HEADERS,
        )

        init_response.raise_for_status()

    except httpx.RequestError as e:
        print(f"Failed to initialize marks page: {e}")

        raise VtopConnectionError(
            f"Failed to initialize marks page: {e}",
            original_exception=e,
            status_code=502,
        ) from e

    except Exception as e:
        print(f"Unexpected error while initializing marks page: {e}")

        raise VtopAttendanceError(
            f"Unexpected error while initializing marks page: {e}"
        ) from e

    # ---------------------------------------------------------
    # STEP 2: Fetch the actual marks
    # ---------------------------------------------------------
    try:
        data = {
            "authorizedID": registration_number,
            "semesterSubId": semSubID,
            "_csrf": csrf_token,
            "x": datetime.now(timezone.utc).strftime(
                "%a, %d %b %Y %H:%M:%S GMT"
            ),
        }

        response = await client.post(
            VIEW_MARKS_URL,
            data=data,
            headers=HEADERS,
        )

        response.raise_for_status()

        return parse_marks(response.text)

    except VtopParsingError:
        raise

    except httpx.RequestError as e:
        print(f"Failed to fetch marks: {e}")

        raise VtopConnectionError(
            f"Failed to fetch marks: {e}",
            original_exception=e,
            status_code=502,
        ) from e

    except Exception as e:
        print(f"Unexpected error while fetching marks: {e}")

        raise VtopAttendanceError(
            f"Unexpected error while fetching marks: {e}"
        ) from e