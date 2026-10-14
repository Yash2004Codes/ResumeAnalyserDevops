"""Groq API service for resume analysis."""

import json
import os
from groq import Groq


# System prompt for the ATS analyzer
SYSTEM_PROMPT = """You are an ATS resume analyzer.

Analyze the following resume text and return:

1. Extracted skills (list)
2. ATS score (0–100)
3. Suggestions for improvement

Return JSON only:
{
  "skills": [],
  "ats_score": number,
  "suggestions": []
}

Important rules:
- Return ONLY valid JSON, no markdown, no code fences, no extra text.
- skills should be a list of strings.
- ats_score should be an integer between 0 and 100.
- suggestions should be a list of actionable improvement strings.
"""


def analyze_resume(resume_text: str) -> dict:
    """
    Send resume text to Groq API for analysis.

    Args:
        resume_text: Extracted text content from the resume PDF.

    Returns:
        Dictionary with keys: skills, ats_score, suggestions.

    Raises:
        RuntimeError: If the Groq API call fails or returns invalid data.
        ValueError: If GROQ_API_KEY is not configured.
    """
    api_key = os.getenv("GROQ_API_KEY")
    if not api_key:
        raise ValueError(
            "GROQ_API_KEY environment variable is not set. "
            "Get your API key at https://console.groq.com"
        )

    try:
        client = Groq(api_key=api_key)

        chat_completion = client.chat.completions.create(
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": resume_text},
            ],
            model="llama-3.3-70b-versatile",
            temperature=0.3,
            max_tokens=2048,
            response_format={"type": "json_object"},
        )

        response_text = chat_completion.choices[0].message.content

        # Parse and validate the JSON response
        result = json.loads(response_text)

        # Validate expected fields exist
        if "skills" not in result or "ats_score" not in result or "suggestions" not in result:
            raise RuntimeError(
                "Groq API returned an incomplete response. "
                "Missing one or more required fields: skills, ats_score, suggestions."
            )

        # Ensure correct types
        result["skills"] = list(result["skills"])
        result["ats_score"] = int(result["ats_score"])
        result["suggestions"] = list(result["suggestions"])

        # Clamp ATS score to valid range
        result["ats_score"] = max(0, min(100, result["ats_score"]))

        return result

    except json.JSONDecodeError as e:
        raise RuntimeError(
            f"Failed to parse Groq API response as JSON: {str(e)}"
        ) from e
    except ValueError:
        raise
    except Exception as e:
        raise RuntimeError(
            f"Groq API call failed: {str(e)}"
        ) from e
