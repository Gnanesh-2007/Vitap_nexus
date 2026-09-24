import time

import httpx

from vitap_vtop_client.constants import (
    HEADERS,
    GRADE_HISTORY_URL,
)
from vitap_vtop_client.exceptions import (
    VtopConnectionError,
    VtopGradeHistoryError,
    VtopParsingError,
)
from vitap_vtop_client.parsers import grade_history_parser

from .model import GradeHistoryModel


async def fetch_grade_history(
    client: httpx.AsyncClient,
    registration_number: str,
    csrf_token: str,
) -> GradeHistoryModel:
    """
    Asynchronously fetches the grade history of a student from VTOP.

    This function performs one VTOP request and parses the returned
    grade history.

    Parameters:
        client:
            The shared authenticated httpx.AsyncClient.

        registration_number:
            The student's registration number.

        csrf_token:
            CSRF token used for authentication.

    Returns:
        GradeHistoryModel:
            Parsed grade history data.

    Raises:
        VtopConnectionError:
            If an HTTP/network request fails.

        VtopGradeHistoryError:
            If an unexpected error occurs.

        VtopParsingError:
            If parsing fails.
    """
    try:
        data = {
            "verifyMenu": "true",
            "authorizedID": registration_number,
            "_csrf": csrf_token,
            "nocache": int(round(time.time() * 1000)),
        }

        response = await client.post(
            GRADE_HISTORY_URL,
            data=data,
            headers=HEADERS,
        )

        response.raise_for_status()

        return grade_history_parser.parse_grade_history(
            response.text
        )

    except VtopParsingError:
        raise

    except httpx.RequestError as e:
        print(f"Grade history fetch failed: {e}")

        raise VtopConnectionError(
            f"Failed to fetch grade history: {e}",
            original_exception=e,
            status_code=502,
        ) from e

    except Exception as e:
        print(f"Unexpected error while fetching grade history: {e}")

        raise VtopGradeHistoryError(
            f"Unexpected error while fetching grade history: {e}"
        ) from e