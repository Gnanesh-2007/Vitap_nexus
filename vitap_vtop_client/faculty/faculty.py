from datetime import datetime, timezone

import httpx

from vitap_vtop_client.constants import (
    FACULTY_DETAIL_URL,
    FACULTY_SEARCH_URL,
    HEADERS,
)
from vitap_vtop_client.exceptions import (
    VitapVtopClientError,
    VtopConnectionError,
    VtopParsingError,
)
from vitap_vtop_client.faculty.model.faculty_model import (
    FacultyDetailsModel,
    FacultyModel,
)
from vitap_vtop_client.parsers import faculty_parser


def _timestamp() -> str:
    """Return the current UTC timestamp in the format expected by VTOP."""
    return datetime.now(timezone.utc).strftime(
        "%a, %d %b %Y %H:%M:%S GMT"
    )


async def fetch_faculty_search(
    client: httpx.AsyncClient,
    username: str,
    csrf_token: str,
    search_term: str,
) -> FacultyModel:
    """
    Searches for a faculty member and returns the first match.

    Parameters:
        client:
            The shared authenticated httpx.AsyncClient.

        username:
            The student's registration number.

        csrf_token:
            CSRF token used for authentication.

        search_term:
            Faculty name or employee ID to search for.

    Returns:
        FacultyModel:
            The first matching faculty member, or an empty model
            when there are no matches.
    """
    html = await _post_faculty_search(
        client,
        username,
        csrf_token,
        search_term,
    )

    return faculty_parser.parse_faculty_search(html)


async def fetch_all_faculty(
    client: httpx.AsyncClient,
    username: str,
    csrf_token: str,
) -> list[FacultyModel]:
    """
    Fetches the complete faculty directory.

    This performs one request and parses all faculty members returned
    by VTOP.
    """
    html = await _post_faculty_search(
        client,
        username,
        csrf_token,
        "",
    )

    return faculty_parser.parse_all_faculty_search(html)


async def _post_faculty_search(
    client: httpx.AsyncClient,
    username: str,
    csrf_token: str,
    search_term: str,
) -> str:
    """
    Posts to the VTOP faculty search endpoint.

    An empty search term requests the complete faculty directory.
    """
    try:
        data = {
            "_csrf": csrf_token,
            "empId": search_term,
            "authorizedID": username,
            "x": _timestamp(),
        }

        response = await client.post(
            FACULTY_SEARCH_URL,
            data=data,
            headers=HEADERS,
        )

        response.raise_for_status()

        return response.text

    except httpx.RequestError as e:
        print(f"Faculty search failed: {e}")

        raise VtopConnectionError(
            f"Failed to search faculty: {e}",
            original_exception=e,
            status_code=502,
        ) from e

    except Exception as e:
        print(
            "An unexpected error occurred during "
            f"faculty search: {e}"
        )

        raise VitapVtopClientError(
            f"Failed to search faculty: {e}"
        ) from e


async def fetch_faculty_details(
    client: httpx.AsyncClient,
    username: str,
    csrf_token: str,
    emp_id: str,
) -> FacultyDetailsModel:
    """
    Fetches a faculty member's profile and office hours.

    This is a single on-demand VTOP request.
    """
    try:
        data = {
            "_csrf": csrf_token,
            "empId": emp_id,
            "authorizedID": username,
            "x": _timestamp(),
        }

        response = await client.post(
            FACULTY_DETAIL_URL,
            data=data,
            headers=HEADERS,
        )

        response.raise_for_status()

        return faculty_parser.parse_faculty_data(
            response.text
        )

    except VtopParsingError:
        raise

    except httpx.RequestError as e:
        print(f"Faculty detail fetch failed: {e}")

        raise VtopConnectionError(
            f"Failed to fetch faculty details: {e}",
            original_exception=e,
            status_code=502,
        ) from e

    except Exception as e:
        print(
            "An unexpected error occurred while fetching "
            f"faculty details: {e}"
        )

        raise VitapVtopClientError(
            f"Failed to fetch faculty details for {emp_id}: {e}"
        ) from e