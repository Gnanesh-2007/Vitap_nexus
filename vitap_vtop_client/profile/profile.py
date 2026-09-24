import asyncio
import httpx
import time
from vitap_vtop_client.constants import PROFILE_URL, HEADERS
from vitap_vtop_client.mentor import fetch_mentor_info
from vitap_vtop_client.grade_history import fetch_grade_history
from vitap_vtop_client.parsers.profile_parser import parse_student_profile
from vitap_vtop_client.utils.extract_student_pfp import (
    extract_student_photo_url,
    fetch_student_pfp,
)
from .model import StudentProfileModel

from vitap_vtop_client.exceptions import (
    VitapVtopClientError,
    VtopConnectionError,
    VtopProfileError,
    VtopParsingError,
    VtopMenuUnavailableError,
    VtopSessionError,
)

async def fetch_profile(
    client: httpx.AsyncClient,
    registration_number: str,
    csrf_token: str,
    include_grade_history: bool = True,
    include_mentor: bool = True,
) -> StudentProfileModel:
    """
    Retrieves and compiles the student profile information from the VTOP Portal.

    Concurrently fetches:
    1. Student details from StudentProfileAllView
    2. Student ID photo from STUDENT_IMAGE_UPLOAD_URL (/vtop/others/photo/getStudentIdPhotoAndSign1)
    3. Faculty mentor details from viewProctorDetails
    4. Grade history

    Parameters:
        client (httpx.AsyncClient): The async HTTP client.
        registration_number (str): The student's username.
        csrf_token (str): CSRF token for authentication.
        include_grade_history (bool): Fetch the nested grade history.
        include_mentor (bool): Fetch the nested mentor details.

    Returns:
        StudentProfileModel: The student's profile information.
    """
    try:
        data = {
            'verifyMenu': 'true',
            'authorizedID': registration_number,
            '_csrf': csrf_token,
            'nocache': int(round(time.time() * 1000))
        }

        response = await client.post(PROFILE_URL, data=data, headers=HEADERS)
        response.raise_for_status()
        profile = parse_student_profile(response.text)

        photo_url = extract_student_photo_url(response.text)

        # Run concurrent sub-tasks
        nested = {
            "student photo": fetch_student_pfp(
                client, registration_number, csrf_token, photo_url=photo_url
            )
        }
        if include_grade_history:
            nested["grade history"] = fetch_grade_history(
                client, registration_number, csrf_token
            )
        if include_mentor:
            nested["mentor details"] = fetch_mentor_info(
                client, registration_number, csrf_token
            )

        labels = list(nested)
        results = await asyncio.gather(*nested.values(), return_exceptions=True)
        for label, result in zip(labels, results):
            if isinstance(result, BaseException):
                # Don't fail the entire profile if secondary photo/mentor fetch encounters an issue
                if label == "student photo":
                    print(f"Student ID photo fetch encountered note: {result}")
                    continue
                raise VtopProfileError(
                    f"Fetched the profile, but its {label} failed: {result}"
                ) from result
            if label == "student photo":
                if result:
                    profile.base64_pfp = result
            elif label == "grade history":
                profile.grade_history = result
            elif label == "mentor details":
                profile.mentor_details = result

        return profile

    except (
        VtopParsingError,
        VtopMenuUnavailableError,
        VtopSessionError,
        VtopProfileError,
        VtopConnectionError,
    ) as e:
        raise e

    except httpx.RequestError as e:
        print(f"Student profile fetch failed: {e}")
        raise VtopConnectionError(
            f"Failed to fetch student profile: {e}",
            original_exception=e,
            status_code=502
        )
    except Exception as e:
        print(f"An unexpected error occurred while fetching student profile: {e}")
        raise VtopProfileError(f"Unexpected error while fetching student profile: {e}") from e