"""
WeatherGPT — Phase 4.3: LLM Security Guardrails Middleware
Defends against prompt injection, system prompt exfiltration, role hijacking,
and adversarial jailbreak attempts before user prompts reach Gemini or Edge SLMs.
"""

import re
from typing import Optional, Tuple


class PromptGuardrailViolation(Exception):
    def __init__(self, message: str, threat_category: str):
        super().__init__(message)
        self.threat_category = threat_category


class LLMGuardrails:
    """
    Multi-layered deterministic and heuristic security guardrail engine.
    Scans incoming prompts for prompt injection, jailbreaks, and prompt exfiltration.
    """

    # 1. System Prompt Exfiltration Patterns
    EXFILTRATION_PATTERNS = [
        r"(?i)\b(repeat|print|show|output|reveal|display|echo|tell)\b.*(system prompt|instructions|initial prompt|hidden prompt|full prompt|rules above|preceding text)",
        r"(?i)\bwhat\s+(are|were)\s+your\s+(initial|original|underlying|system)\s+(instructions|prompts|rules)",
        r"(?i)\b(verbatim|word for word)\b.*(system|prompt|instruction)",
    ]

    # 2. Instruction Override & Hijacking Patterns
    OVERRIDE_PATTERNS = [
        r"(?i)\b(ignore|disregard|forget|bypass|override)\b.*(previous|prior|above|all)\b.*(instructions|rules|directives|constraints|guardrails)",
        r"(?i)\bstop being (a |an )?(weather|meteorological|panchangam)\b",
        r"(?i)\bfrom now on\b.*(act as|you are|pretend to be|roleplay as)\b",
        r"(?i)\b(you are now|assume the role of)\s+(dan|evil|unfiltered|jailbreak|chaos|hacker)",
        r"(?i)\bdeveloper mode (enabled|on|activate)\b",
        r"(?i)\bdo anything now\b",
        r"(?i)\bsimulate a virtual machine\b",
    ]

    # 3. Code, Shell & SQL Injection Signatures
    CODE_INJECTION_PATTERNS = [
        r"(?i)<\s*script[^>]*>",
        r"(?i)\b(drop\s+table|insert\s+into|union\s+select|delete\s+from)\b",
        r"(?i)\b(eval|exec|os\.system|subprocess\.Popen|__import__|shutil\.rmtree)\b",
    ]

    # Safe Refusal Messages
    REFUSAL_MESSAGES = {
        "EXFILTRATION": (
            "I am WeatherGPT, an AI meteorological and Panchangam assistant. "
            "My core instructions and system configuration are confidential and cannot be revealed. "
            "How can I assist you with current weather conditions, farming calendars, or rain forecasts?"
        ),
        "OVERRIDE": (
            "I cannot disregard my meteorological directives or adopt an unrestricted persona. "
            "WeatherGPT remains dedicated strictly to weather, environmental safety, and Indic agricultural guidance."
        ),
        "CODE_INJECTION": (
            "Your query contains executable script or database tokens that violate WeatherGPT security guardrails. "
            "Please ask a weather, climate, or farming-related question."
        ),
    }

    @classmethod
    def evaluate_prompt(cls, prompt: str) -> Tuple[bool, Optional[str], Optional[str]]:
        """
        Evaluates a prompt.
        Returns:
            (is_safe, threat_category, refusal_message)
        """
        if not prompt or not prompt.strip():
            return True, None, None

        normalized = prompt.strip()

        # Check for system prompt exfiltration
        for pattern in cls.EXFILTRATION_PATTERNS:
            if re.search(pattern, normalized):
                return False, "EXFILTRATION", cls.REFUSAL_MESSAGES["EXFILTRATION"]

        # Check for instruction override / jailbreaks
        for pattern in cls.OVERRIDE_PATTERNS:
            if re.search(pattern, normalized):
                return False, "OVERRIDE", cls.REFUSAL_MESSAGES["OVERRIDE"]

        # Check for dangerous code or SQL injection strings
        for pattern in cls.CODE_INJECTION_PATTERNS:
            if re.search(pattern, normalized):
                return False, "CODE_INJECTION", cls.REFUSAL_MESSAGES["CODE_INJECTION"]

        return True, None, None

    @classmethod
    def sanitize_user_input(cls, prompt: str) -> str:
        """
        Lightly sanitizes prompt by stripping control characters and excessive delimiters
        while preserving Indic scripts and standard punctuation.
        """
        if not prompt:
            return ""
        # Strip zero-width joiners / non-printable control characters (except newline/tab)
        cleaned = re.sub(r"[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]", "", prompt)
        # Limit repeated delimiter attacks like "=====" or "-----"
        cleaned = re.sub(r"([=\-~`*#]){5,}", r"\1\1\1", cleaned)
        return cleaned.strip()
