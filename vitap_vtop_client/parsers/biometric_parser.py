from bs4 import BeautifulSoup

from vitap_vtop_client.biometric.model.biometric_model import BiometricModel
from vitap_vtop_client.exceptions.exception import VtopParsingError


def _cell_text(cell) -> str:
    return cell.get_text(strip=True).replace("\t", "").replace("\n", "")


def parse_biometric(html: str) -> list[BiometricModel]:
    """
    Parses the biometric log table into one record per punch.

    Args:
        html (str): The raw HTML string containing the biometric log table.

    Returns:
        list[BiometricModel]: One entry per biometric punch.
    """
    if not html or "no record" in html.lower() or "not found" in html.lower():
        return []

    try:
        soup = BeautifulSoup(html, "lxml")
        biometric_logs: list[BiometricModel] = []

        rows = soup.find_all("tr")
        if not rows:
            return []

        for row in rows:
            cells = row.find_all("td")
            if len(cells) < 4:
                continue

            c0 = _cell_text(cells[0]).lower()
            c1 = _cell_text(cells[1]).lower()
            # Skip header row if it contains 'sl', 's.no', 'serial', or 'date' in headers
            if "sl" in c0 or "s.no" in c0 or "serial" in c0 or "date" in c1:
                continue

            biometric_logs.append(
                BiometricModel(
                    serial=_cell_text(cells[0]),
                    date=_cell_text(cells[1]),
                    in_time=_cell_text(cells[2]),
                    location=_cell_text(cells[3]),
                )
            )

        return biometric_logs

    except Exception:
        return []

