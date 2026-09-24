import time
from datetime import datetime, timezone

import httpx

from vitap_vtop_client.constants import (
    HEADERS,
    TIME_TABLE_URL,
    GET_TIME_TABLE_URL,
)
from vitap_vtop_client.exceptions.exception import (
    VtopConnectionError,
    VtopParsingError,
    VtopTimetableError,
)
from vitap_vtop_client.parsers import timetable_parser
from vitap_vtop_client.timetable.model.timetable_model import TimetableModel


async def fetch_timetable(
    client: httpx.AsyncClient,
    username: str,
    semSubID: str,
    csrf_token: str,
) -> TimetableModel:
    """
    Retrieves the timetable for a specified semester and user.

    VTOP requires two requests for the timetable:
        1. Initialize the timetable page.
        2. Request the actual timetable data.

    Parameters:
        client:
            The shared authenticated httpx.AsyncClient.

        username:
            The student's registration number.

        semSubID:
            The semester subject ID.

        csrf_token:
            CSRF token used for authentication.

    Returns:
        TimetableModel:
            Parsed timetable information.

    Raises:
        VtopConnectionError:
            If an HTTP/network request fails.

        VtopTimetableError:
            If an unexpected error occurs.

        VtopParsingError:
            If timetable parsing fails.
    """

    # ---------------------------------------------------------
    # STEP 1: Initialize the VTOP timetable page
    # ---------------------------------------------------------
    try:
        data_initial = {
            "verifyMenu": "true",
            "authorizedID": username,
            "_csrf": csrf_token,
            "nocache": int(round(time.time() * 1000)),
        }

        initial_response = await client.post(
            TIME_TABLE_URL,
            data=data_initial,
            headers=HEADERS,
        )

        initial_response.raise_for_status()

    except httpx.RequestError as e:
        print(f"Timetable initial POST failed: {e}")

        raise VtopConnectionError(
            f"Failed to initialize timetable page: {e}",
            original_exception=e,
            status_code=502,
        ) from e

    except Exception as e:
        print(
            "An unexpected error occurred during "
            f"timetable initial POST: {e}"
        )

        raise VtopTimetableError(
            f"Failed to initialize timetable page: {e}"
        ) from e

    # ---------------------------------------------------------
    # STEP 2: Fetch the actual timetable
    # ---------------------------------------------------------
    try:
        data_fetch = {
            "_csrf": csrf_token,
            "semesterSubId": semSubID,
            "authorizedID": username,
            "x": datetime.now(timezone.utc).strftime(
                "%a, %d %b %Y %H:%M:%S GMT"
            ),
        }

        timetable_response = await client.post(
            GET_TIME_TABLE_URL,
            data=data_fetch,
            headers=HEADERS,
        )

        timetable_response.raise_for_status()

        return timetable_parser.parse_time_table(
            timetable_response.text
        )

    except VtopParsingError:
        raise

    except httpx.RequestError as e:
        print(f"Timetable data fetch failed: {e}")

        raise VtopConnectionError(
            f"Failed to fetch timetable data: {e}",
            original_exception=e,
            status_code=502,
        ) from e

    except Exception as e:
        print(
            "An unexpected error occurred while fetching "
            f"or parsing timetable: {e}"
        )

        raise VtopTimetableError(
            "An unexpected error occurred while fetching "
            f"timetable for semester {semSubID}: {e}"
        ) from e