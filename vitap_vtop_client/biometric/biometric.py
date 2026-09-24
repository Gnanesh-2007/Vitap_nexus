import time
from datetime import datetime, timezone

import httpx

from .model.biometric_model import BiometricModel
from vitap_vtop_client.constants import (
    HEADERS,
    BIOMETRIC_LOG_URL,
    GET_BIOMETRIC_LOG_URL,
)
from vitap_vtop_client.exceptions.exception import (
    VtopBiometricError,
    VtopConnectionError,
    VtopParsingError,
)
from vitap_vtop_client.parsers import biometric_parser
from vitap_vtop_client.utils import find_csrf


async def fetch_biometric(
    client: httpx.AsyncClient,
    registration_number: str,
    date: str,
    csrf_token: str,
) -> list[BiometricModel]:
    """
    Retrieves biometric log details for a specific student and date.

    VTOP requires two requests for biometric logs:
        1. Initialize the biometric page.
        2. Request the biometric log data for the given date.

    Parameters:
        client:
            The shared authenticated httpx.AsyncClient.

        registration_number:
            The student's registration number.

        date:
            The date for which the biometric log is requested.
            Expected format: dd/mm/yyyy.

        csrf_token:
            CSRF token used for authentication.

    Returns:
        list[BiometricModel]:
            Parsed biometric log entries.

    Raises:
        VtopConnectionError:
            If an HTTP/network request fails.

        VtopBiometricError:
            If an unexpected error occurs.

        VtopParsingError:
            If biometric data parsing fails.
    """

    # ---------------------------------------------------------
    # STEP 1: Initialize the VTOP biometric page
    # ---------------------------------------------------------
    try:
        init_data = {
            "verifyMenu": "true",
            "authorizedID": registration_number,
            "_csrf": csrf_token,
            "nocache": int(round(time.time() * 1000)),
        }

        init_response = await client.post(
            BIOMETRIC_LOG_URL,
            data=init_data,
            headers=HEADERS,
        )

        init_response.raise_for_status()

        # Extract fresh CSRF token from the biometric initialization page
        fresh_csrf = find_csrf(init_response.text)
        if fresh_csrf:
            csrf_token = fresh_csrf

    except httpx.RequestError as e:
        print(f"Biometric initial POST failed: {e}")

        raise VtopConnectionError(
            f"Failed to initialize biometric page: {e}",
            original_exception=e,
            status_code=502,
        ) from e

    except Exception as e:
        print(
            "An unexpected error occurred during "
            f"biometric initial POST: {e}"
        )

        raise VtopBiometricError(
            f"Failed to initialize biometric page: {e}"
        ) from e

    # ---------------------------------------------------------
    # STEP 2: Fetch the actual biometric data
    # ---------------------------------------------------------
    try:
        # Normalize input date to dd/mm/yyyy format expected by VTOP
        query_date = date.strip()
        for fmt in ("%Y-%m-%d", "%d-%m-%Y", "%d-%b-%Y", "%d-%B-%Y", "%d.%m.%Y", "%d/%m/%Y"):
            try:
                dt = datetime.strptime(query_date, fmt)
                query_date = dt.strftime("%d/%m/%Y")
                break
            except ValueError:
                pass

        data = {
            "_csrf": csrf_token,
            "fromDate": query_date,
            "authorizedID": registration_number,
            "x": datetime.now(timezone.utc).strftime(
                "%a, %d %b %Y %H:%M:%S GMT"
            ),
        }

        biometric_response = await client.post(
            GET_BIOMETRIC_LOG_URL,
            data=data,
            headers=HEADERS,
        )

        biometric_response.raise_for_status()

        parsed_data = biometric_parser.parse_biometric(
            biometric_response.text
        )

        # If no records with dd/mm/yyyy, try dd-MMM-yyyy (e.g. 21-Sep-2026)
        if not parsed_data:
            try:
                dt = datetime.strptime(query_date, "%d/%m/%Y")
                alt_date = dt.strftime("%d-%b-%Y")
                data["fromDate"] = alt_date
                alt_resp = await client.post(
                    GET_BIOMETRIC_LOG_URL,
                    data=data,
                    headers=HEADERS,
                )
                if alt_resp.is_success:
                    alt_parsed = biometric_parser.parse_biometric(alt_resp.text)
                    if alt_parsed:
                        return alt_parsed
            except Exception:
                pass

        return parsed_data

    except VtopParsingError:
        raise

    except httpx.RequestError as e:
        print(
            f"Biometric fetch failed for the date {date}: {e}"
        )

        raise VtopConnectionError(
            f"Biometric fetch failed for the date {date}: {e}",
            original_exception=e,
            status_code=502,
        ) from e

    except Exception as e:
        print(
            "An unexpected error occurred while fetching "
            f"or parsing biometric for {date}: {e}"
        )

        raise VtopBiometricError(
            "An unexpected error occurred while fetching "
            f"or parsing biometric for {date}: {e}"
        ) from e