"""
F2.2 End-to-End Vernacular Voice Pipeline Service.

Provides:
1. Canonical specification registry for 7 languages (English-IN, Hindi, Telugu,
   Tamil, Kannada, Bengali, Marathi) including STT/TTS BCP-47 locales and
   regional agro-meteorological vocabulary.
2. Unicode script detection + Marathi/Hindi Devanagari lexical disambiguation.
3. Script-aware and voice-mode-aware system prompt directives for Gemini.
4. Multilingual TTS plain-text sanitization (strips markdown, emojis, URLs, and
   expands meteorological units into natural spoken phrases per script).
"""

from __future__ import annotations

from dataclasses import dataclass
import re
from typing import Dict, List, Optional, Tuple


@dataclass(frozen=True)
class IndicLanguageSpec:
    code: str
    english_name: str
    native_name: str
    script_name: str
    stt_locale: str
    tts_locale: str
    glossary_terms: Tuple[str, ...]
    deg_c_phrase: str
    kmh_phrase: str
    percent_phrase: str
    and_word: str
    sample_queries: Tuple[str, ...]


INDIC_LANGUAGE_SPECS: Dict[str, IndicLanguageSpec] = {
    "en_IN": IndicLanguageSpec(
        code="en_IN",
        english_name="English",
        native_name="English",
        script_name="Latin (Indian English)",
        stt_locale="en_IN",
        tts_locale="en-IN",
        glossary_terms=(
            "monsoon showers",
            "heatwave advisory",
            "Kharif sowing window",
            "air quality index",
            "UV exposure",
        ),
        deg_c_phrase=" degrees Celsius",
        kmh_phrase=" kilometers per hour",
        percent_phrase=" percent",
        and_word=" and ",
        sample_queries=(
            "How is the hyperlocal weather and AQI right now?",
            "Is tomorrow auspicious and dry for outdoor travel?",
        ),
    ),
    "hi": IndicLanguageSpec(
        code="hi",
        english_name="Hindi",
        native_name="हिन्दी",
        script_name="Devanagari (हिन्दी)",
        stt_locale="hi_IN",
        tts_locale="hi-IN",
        glossary_terms=(
            "मानसून",
            "लू (हीटवेव)",
            "उमस",
            "बुआई",
            "कोहरा",
            "शीतलहर",
            "एक्यूआई (वायु गुणवत्ता)",
        ),
        deg_c_phrase=" डिग्री सेल्सियस",
        kmh_phrase=" किलोमीटर प्रति घंटा",
        percent_phrase=" प्रतिशत",
        and_word=" और ",
        sample_queries=(
            "आज मेरे इलाके में मौसम और हवा की गुणवत्ता कैसी है?",
            "क्या कल खेती या बुआई के लिए शुभ मुहूर्त और मौसम ठीक है?",
        ),
    ),
    "te": IndicLanguageSpec(
        code="te",
        english_name="Telugu",
        native_name="తెలుగు",
        script_name="Telugu (తెలుగు)",
        stt_locale="te_IN",
        tts_locale="te-IN",
        glossary_terms=(
            "మాగాణి వర్షం",
            "వడగాలులు",
            "తేమ శాతం",
            "గాలి వేగం",
            "పంట నాట్లు",
            "తుఫాను హెచ్చరిక",
            "గాలి నాణ్యత",
        ),
        deg_c_phrase=" డిగ్రీల సెల్సియస్",
        kmh_phrase=" కిలోమీటర్లు ప్రతి గంటకు",
        percent_phrase=" శాతం",
        and_word=" మరియు ",
        sample_queries=(
            "ఈ రోజు మా ప్రాంతంలో వాతావరణం మరియు గాలి నాణ్యత ఎలా ఉంది?",
            "రేపు పంట నాట్లు వేయడానికి తిథి మరియు వర్ష సూచన అనుకూలంగా ఉన్నాయా?",
        ),
    ),
    "ta": IndicLanguageSpec(
        code="ta",
        english_name="Tamil",
        native_name="தமிழ்",
        script_name="Tamil (தமிழ்)",
        stt_locale="ta_IN",
        tts_locale="ta-IN",
        glossary_terms=(
            "வடகிழக்குப் பருவமழை",
            "வெப்ப அலை",
            "ஈரப்பதம்",
            "காற்றின் வேகம்",
            "பயிர் விதைப்பு",
            "காற்றின் தரம்",
        ),
        deg_c_phrase=" டிகிரி செல்சியஸ்",
        kmh_phrase=" கிலோமீட்டர் வேகம்",
        percent_phrase=" சதவீதம்",
        and_word=" மற்றும் ",
        sample_queries=(
            "இன்று எங்கள் பகுதியில் வானிலை மற்றும் காற்றின் தரம் எப்படி உள்ளது?",
            "நாளை பயிர் விதைப்புக்கு நல்ல நேரமும் வானிலையும் உள்ளதா?",
        ),
    ),
    "kn": IndicLanguageSpec(
        code="kn",
        english_name="Kannada",
        native_name="ಕನ್ನಡ",
        script_name="Kannada (ಕನ್ನಡ)",
        stt_locale="kn_IN",
        tts_locale="kn-IN",
        glossary_terms=(
            "ಮುಂಗಾರು ಮಳೆ",
            "ಬಿಸಿ ಗಾಳಿ",
            "ತೇವಾಂಶ",
            "ಗಾಳಿಯ ವೇಗ",
            "ಬಿತ್ತನೆ ಸಮಯ",
            "ಗಾಳಿಯ ಗುಣಮಟ್ಟ",
        ),
        deg_c_phrase=" ಡಿಗ್ರಿ ಸೆಲ್ಸಿಯಸ್",
        kmh_phrase=" ಕಿಲೋಮೀಟರ್ ಪ್ರತಿ ಗಂಟೆಗೆ",
        percent_phrase=" ಪ್ರತಿಶತ",
        and_word=" ಮತ್ತು ",
        sample_queries=(
            "ಇಂದು ನಮ್ಮ ಪ್ರದೇಶದಲ್ಲಿ ಹವಾಮಾನ ಮತ್ತು ಗಾಳಿಯ ಗುಣಮಟ್ಟ ಹೇಗಿದೆ?",
            "ನಾಳೆ ಬಿತ್ತನೆ ಮಾಡಲು ಶುಭ ಮುಹೂರ್ತ ಮತ್ತು ಮಳೆ ಮುನ್ಸೂಚನೆ ಹೇಗಿದೆ?",
        ),
    ),
    "bn": IndicLanguageSpec(
        code="bn",
        english_name="Bengali",
        native_name="বাংলা",
        script_name="Bengali (বাংলা)",
        stt_locale="bn_IN",
        tts_locale="bn-IN",
        glossary_terms=(
            "কালবৈশাখী",
            "ঘূর্ণিঝড়",
            "আর্দ্রতা",
            "তাপপ্রবাহ",
            "বর্ষা",
            "বাতাসের মান",
        ),
        deg_c_phrase=" ডিগ্রি সেলসিয়াস",
        kmh_phrase=" কিলোমিটার প্রতি ঘণ্টা",
        percent_phrase=" শতাংশ",
        and_word=" এবং ",
        sample_queries=(
            "আজ আমার এলাকার আবহাওয়া ও বাতাসের মান কেমন?",
            "আগামীকাল চাষাবাদ বা বাইরের কাজের জন্য শুভ সময় ও আবহাওয়া কেমন থাকবে?",
        ),
    ),
    "mr": IndicLanguageSpec(
        code="mr",
        english_name="Marathi",
        native_name="मराठी",
        script_name="Devanagari (मराठी)",
        stt_locale="mr_IN",
        tts_locale="mr-IN",
        glossary_terms=(
            "मान्सून पाऊस",
            "उष्णतेची लाट",
            "आर्द्रता",
            "पेरणी",
            "गारपीट",
            "हवेची गुणवत्ता",
        ),
        deg_c_phrase=" अंश सेल्सिअस",
        kmh_phrase=" किलोमीटर प्रति तास",
        percent_phrase=" टक्के",
        and_word=" आणि ",
        sample_queries=(
            "आज माझ्या परिसरातील हवामान आणि हवेची गुणवत्ता कशी आहे?",
            "उद्या पेरणीसाठी शुभ मुहूर्त आणि पावसाचा अंदाज अनुकूल आहे का?",
        ),
    ),
}

_LANGUAGE_ALIASES: Dict[str, str] = {
    "en": "en_IN",
    "en_in": "en_IN",
    "en-in": "en_IN",
    "english": "en_IN",
    "hi": "hi",
    "hi_in": "hi",
    "hi-in": "hi",
    "hindi": "hi",
    "हिन्दी": "hi",
    "हिंदी": "hi",
    "te": "te",
    "te_in": "te",
    "te-in": "te",
    "telugu": "te",
    "తెలుగు": "te",
    "ta": "ta",
    "ta_in": "ta",
    "ta-in": "ta",
    "tamil": "ta",
    "தமிழ்": "ta",
    "kn": "kn",
    "kn_in": "kn",
    "kn-in": "kn",
    "kannada": "kn",
    "ಕನ್ನಡ": "kn",
    "bn": "bn",
    "bn_in": "bn",
    "bn-in": "bn",
    "bengali": "bn",
    "bangla": "bn",
    "বাংলা": "bn",
    "mr": "mr",
    "mr_in": "mr",
    "mr-in": "mr",
    "marathi": "mr",
    "मराठी": "mr",
}

# Unicode script ranges mapped to primary language code.
_SCRIPT_RANGES: Tuple[Tuple[int, int, str], ...] = (
    (0x0C00, 0x0C7F, "te"),  # Telugu
    (0x0B80, 0x0BFF, "ta"),  # Tamil
    (0x0C80, 0x0CFF, "kn"),  # Kannada
    (0x0980, 0x09FF, "bn"),  # Bengali
    (0x0900, 0x097F, "hi"),  # Devanagari (disambiguated below for Marathi)
)

_MARATHI_MARKERS = frozenset(
    {
        "पाऊस",
        "पावसाचा",
        "आहे",
        "आहेत",
        "कसे",
        "कशी",
        "कसा",
        "उद्या",
        "आजचे",
        "पेरणी",
        "गारपीट",
        "हवामान",
        "माझ्या",
        "मराठी",
        "सांगा",
        "थंडी",
        "ढगाळ",
        "वारं",
    }
)

_MARKDOWN_LINK_RE = re.compile(r"\[([^\]]+)\]\([^)]+\)")
_CODE_BLOCK_RE = re.compile(r"```[\s\S]*?```")
_INLINE_CODE_RE = re.compile(r"`([^`]*)`")
_URL_RE = re.compile(r"https?://\S+")
_MARKDOWN_DECOR_RE = re.compile(r"[*#>~|]+|(?<!\w)_|_(?!\w)")
_BULLET_PREFIX_RE = re.compile(r"(?m)^\s*(?:[-•*]|\d+\.)\s+")
_EMOJI_RE = re.compile(
    "["
    "\U0001F300-\U0001FAFF"
    "\U00002600-\U000027BF"
    "\U0000FE00-\U0000FE0F"
    "\U0000200D"
    "]+",
    flags=re.UNICODE,
)


def _detect_script_language(text: str, preferred_devanagari: str = "hi") -> Optional[str]:
    """Detect dominant Indic script in text; disambiguate Devanagari between Hindi & Marathi."""
    if not text:
        return None

    counts: Dict[str, int] = {}
    for ch in text:
        cp = ord(ch)
        for low, high, code in _SCRIPT_RANGES:
            if low <= cp <= high:
                counts[code] = counts.get(code, 0) + 1
                break

    if not counts:
        return None

    dominant = max(counts, key=counts.get)
    if dominant == "hi":
        tokens = set(re.findall(r"[\u0900-\u097F]+", text))
        if tokens & _MARATHI_MARKERS:
            return "mr"
        if preferred_devanagari == "mr":
            return "mr"
    return dominant


class IndicVoiceService:
    """Routes Indic language/script rules and creates TTS-safe vernacular responses."""

    def resolve_language(
        self,
        requested_language: Optional[str],
        text: str = "",
    ) -> IndicLanguageSpec:
        """
        Resolve canonical IndicLanguageSpec from explicit UI preference plus query script.

        If the user types or dictates in a distinct Indic script (e.g. Telugu while UI
        is English), follow the spoken/written script automatically. When UI selects
        Marathi vs Hindi, disambiguate Devanagari accordingly.
        """
        req_key = (requested_language or "").strip().lower()
        explicit_code = _LANGUAGE_ALIASES.get(req_key)

        preferred_devanagari = "mr" if explicit_code == "mr" else "hi"
        detected_script_code = _detect_script_language(
            text, preferred_devanagari=preferred_devanagari
        )

        if detected_script_code:
            chosen_code = detected_script_code
        elif explicit_code:
            chosen_code = explicit_code
        else:
            chosen_code = "en_IN"

        return INDIC_LANGUAGE_SPECS[chosen_code]

    def build_prompt_directive(
        self,
        spec: IndicLanguageSpec,
        voice_mode: bool = False,
    ) -> str:
        """Build script-aware + dialect-glossary prompt directive for Gemini."""
        glossary = ", ".join(spec.glossary_terms)
        parts = [
            f"[Vernacular Language Rule: Respond fluently in {spec.english_name} "
            f"({spec.native_name}) using native {spec.script_name} script only — "
            "do NOT use Romanized transliteration unless the user explicitly asks for it. "
            f"Use authentic regional meteorological & agricultural vocabulary where helpful ({glossary}).]"
        ]

        if voice_mode:
            parts.append(
                "[Voice Assistant Mode: Keep the reply concise (3 to 5 crisp, natural spoken sentences) "
                "ideal for text-to-speech playback. Avoid markdown tables, ASCII symbols, and raw URLs. "
                "State current condition/temperature, any microclimate or Panchangam highlight, and brief attire/safety advice.]"
            )

        return " ".join(parts)

    def sanitize_for_tts(
        self,
        text: str,
        spec: IndicLanguageSpec,
    ) -> str:
        """Convert markdown/emoji Gemini output into natural Indic TTS speech text."""
        if not text:
            return ""

        cleaned = _CODE_BLOCK_RE.sub(" ", text)
        cleaned = _MARKDOWN_LINK_RE.sub(r"\1", cleaned)
        cleaned = _URL_RE.sub("", cleaned)
        cleaned = _INLINE_CODE_RE.sub(r"\1", cleaned)
        cleaned = _BULLET_PREFIX_RE.sub("", cleaned)
        cleaned = _EMOJI_RE.sub("", cleaned)
        cleaned = _MARKDOWN_DECOR_RE.sub("", cleaned)

        # Expand common weather units into localized spoken words
        cleaned = re.sub(r"\s*°\s*[Cc]\b", spec.deg_c_phrase, cleaned)
        cleaned = re.sub(r"\s*°\s*[Ff]\b", " degrees Fahrenheit", cleaned)
        cleaned = re.sub(r"\s*km\s*/\s*h\b", spec.kmh_phrase, cleaned, flags=re.IGNORECASE)
        cleaned = re.sub(r"\s*kmph\b", spec.kmh_phrase, cleaned, flags=re.IGNORECASE)
        cleaned = re.sub(r"(\d)\s*%", rf"\1{spec.percent_phrase}", cleaned)
        cleaned = cleaned.replace(" & ", spec.and_word)

        # Preserve sentence pauses across Devanagari danda (।) and line breaks
        lines = [line.strip() for line in cleaned.splitlines() if line.strip()]
        spoken_lines: List[str] = []
        for line in lines:
            if line[-1] not in ".!?।":
                line += "।" if spec.code in {"hi", "mr", "bn"} else "."
            spoken_lines.append(line)

        result = " ".join(spoken_lines)
        result = re.sub(r"\s+([.,!?।])", r"\1", result)
        result = re.sub(r"\s{2,}", " ", result).strip()
        return result

    def get_supported_languages_metadata(self) -> List[Dict[str, object]]:
        """Serialize supported Indic voice languages for API discovery."""
        return [
            {
                "code": spec.code,
                "english_name": spec.english_name,
                "native_name": spec.native_name,
                "script": spec.script_name,
                "stt_locale": spec.stt_locale,
                "tts_locale": spec.tts_locale,
                "glossary_terms": list(spec.glossary_terms),
                "sample_queries": list(spec.sample_queries),
            }
            for spec in INDIC_LANGUAGE_SPECS.values()
        ]


indic_voice_service = IndicVoiceService()
