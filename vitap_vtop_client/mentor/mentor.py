import time

import httpx

from vitap_vtop_client.constants import (
    HEADERS,
    MENTOR_DETAILS_URL,
)
from vitap_vtop_client.exceptions import (
    VtopConnectionError,
    VtopMentorError,
    VtopParsingError,
)
from vitap_vtop_client.parsers.mentor_parser import parse_mentor_details

from .model import MentorModel


async def fetch_mentor_info(
    client: httpx.AsyncClient,
    registration_number: str,
    csrf_token: str,
) -> MentorModel:
    """
    Retrieves mentor details for a student from the VTOP system.

    This function performs one VTOP request and parses the returned
    mentor information.

    Parameters:
        client:
            The shared authenticated httpx.AsyncClient.

        registration_number:
            The student's registration number.

        csrf_token:
            CSRF token used for authentication.

    Returns:
        MentorModel:
            Parsed mentor details.

    Raises:
        VtopConnectionError:
            If an HTTP/network request fails.

        VtopMentorError:
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
            MENTOR_DETAILS_URL,
            data=data,
            headers=HEADERS,
        )

        response.raise_for_status()

        return parse_mentor_details(response.text)

    except VtopParsingError:
        raise

    except httpx.RequestError as e:
        print(f"Mentor details fetch failed: {e}")

        raise VtopConnectionError(
            f"Failed to fetch mentor details: {e}",
            original_exception=e,
            status_code=502,
        ) from e

    except Exception as e:
        print(f"Unexpected error while fetching mentor details: {e}")

        raise VtopMentorError(
            f"Unexpected error while fetching mentor details: {e}"
        ) from e