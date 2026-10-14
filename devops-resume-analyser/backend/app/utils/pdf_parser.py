"""PDF text extraction utility using pdfplumber."""

import io
import pdfplumber


def extract_text(file_bytes: bytes) -> str:
    """
    Extract text content from a PDF file.

    Args:
        file_bytes: Raw bytes of the uploaded PDF file.

    Returns:
        Extracted text as a single string.

    Raises:
        ValueError: If the file is not a valid PDF or contains no extractable text.
    """
    try:
        with pdfplumber.open(io.BytesIO(file_bytes)) as pdf:
            pages_text = []
            for page in pdf.pages:
                text = page.extract_text()
                if text:
                    pages_text.append(text)

            if not pages_text:
                raise ValueError(
                    "No extractable text found in the PDF. "
                    "The file may be scanned or image-based."
                )

            return "\n\n".join(pages_text)

    except Exception as e:
        if isinstance(e, ValueError):
            raise
        raise ValueError(f"Failed to parse PDF file: {str(e)}") from e
