import time

import httpx

from vitap_vtop_client.constants import PROFILE_URL, HEADERS
from vitap_vtop_client.parsers.profile_parser import parse_student_profile
from .model import StudentProfileModel

from vitap_vtop_client.exceptions import (
    VtopConnectionError,
    VtopProfileError,
    VtopParsingError,
)


async def fetch_profile(
    client: httpx.AsyncClient,
    registration_number: str,
    csrf_token: str,
) -> StudentProfileModel:
    """
    Retrieves the student profile information from the VTOP Portal.

    This function intentionally fetches ONLY profile data.

    Grade history and mentor information are fetched separately by their
    respective client methods. Keeping them separate prevents duplicate
    VTOP requests when /student/all_data fetches multiple features in
    parallel.

    Parameters:
        client:
            The shared authenticated httpx.AsyncClient.

        registration_number:
            The student's registration number.

        csrf_token:
            CSRF token used for authentication.

    Returns:
        StudentProfileModel:
            Parsed student profile information.

    Raises:
        VtopConnectionError:
            If the HTTP request fails.

        VtopProfileError:
            If an unexpected error occurs.

        VtopParsingError:
            If profile parsing fails.
    """
    try:
        data = {
            "verifyMenu": "true",
            "authorizedID": registration_number,
            "_csrf": csrf_token,
            "nocache": int(round(time.time() * 1000)),
        }

        response = await client.post(
            PROFILE_URL,
            data=data,
            headers=HEADERS,
        )

        response.raise_for_status()

        return parse_student_profile(response.text)

    except VtopParsingError:
        raise

    except httpx.RequestError as e:
        print(f"Student profile fetch failed: {e}")

        raise VtopConnectionError(
            f"Failed to fetch student profile: {e}",
            original_exception=e,
            status_code=502,
        ) from e

    except Exception as e:
        print(f"An unexpected error occurred while fetching student profile: {e}")

        raise VtopProfileError(
            f"Unexpected error while fetching student profile: {e}"
        ) from e