"""
Hybrid RAG Pipeline: Vedic Panchangam + Meteorological Fusion (F2.1)

Computes high-precision astronomical Drik Panchangam (Lahiri/Chitrapaksha Ayanamsa)
using PyEphem ephemerides, retrieves domain-relevant Indian agro-meteorological,
Muhurtham, and lunisolar festival knowledge, and fuses cultural timing windows with
live 1km spatially downscaled weather forecasts.
"""

import logging
import math
import re
from datetime import date, datetime, time as dt_time, timedelta, timezone
from typing import Any, Dict, List, Optional, Tuple

import ephem

logger = logging.getLogger(__name__)

# --- Astronomical Reference Constants (Lahiri / Chitrapaksha Ayanamsa) ---
_J2000_UTC = datetime(2000, 1, 1, 12, 0, tzinfo=timezone.utc)
_LAHIRI_J2000_DEG = 23.857092
_PRECESSION_DEG_PER_YEAR = 0.013969713

# --- Canonical Panchangam Reference Tables ---
VARAS = [
    ("Ravivara (Sunday)", "Surya (Sun)"),
    ("Somavara (Monday)", "Chandra (Moon)"),
    ("Mangalavara (Tuesday)", "Mangala (Mars)"),
    ("Budhavara (Wednesday)", "Budha (Mercury)"),
    ("Guruvara (Thursday)", "Brihaspati (Jupiter)"),
    ("Shukravara (Friday)", "Shukra (Venus)"),
    ("Shanivara (Saturday)", "Shani (Saturn)"),
]

TITHI_NAMES = [
    "Pratipada", "Dwitiya", "Tritiya", "Chaturthi", "Panchami",
    "Shashthi", "Saptami", "Ashtami", "Navami", "Dashami",
    "Ekadashi", "Dwadashi", "Trayodashi", "Chaturdashi", "Purnima",
    "Pratipada", "Dwitiya", "Tritiya", "Chaturthi", "Panchami",
    "Shashthi", "Saptami", "Ashtami", "Navami", "Dashami",
    "Ekadashi", "Dwadashi", "Trayodashi", "Chaturdashi", "Amavasya",
]

# Rikta Tithis (4, 9, 14 in each paksha) and Amavasya are generally avoided for weddings/major launches
_RIKTA_TITHI_MOD = {4, 9, 14}
_AUSPICIOUS_TITHIS = {2, 3, 5, 7, 10, 11, 13, 15, 17, 18, 20, 22, 25, 26}

# (Name, Nature/Class, Traditional Agro-Weather Resonance)
NAKSHATRAS = [
    ("Ashwini", "Kshipra (Swift)", "Favorable for quick field prep, transplanting, and short journeys"),
    ("Bharani", "Ugra (Fierce)", "Best suited for soil tilling, weeding, and storage rather than new ceremonies"),
    ("Krittika", "Mishra (Mixed)", "Warm/dry solar energy; good for harvesting, grain drying, and controlled clearing"),
    ("Rohini", "Dhruva (Fixed)", "Highly auspicious for sowing seeds, orchards, weddings, and monsoon onset tracking"),
    ("Mrigashira", "Mridu (Mild)", "Auspicious for planting, garden work, travel, and smooth ceremonies"),
    ("Ardra", "Tikshna (Sharp)", "Associated with convective storms/rain (Ardra Karthe); good for rain-fed crops"),
    ("Punarvasu", "Chara (Movable)", "Renewal & moisture balance; auspicious for sowing, horticulture, and travel"),
    ("Pushya", "Kshipra (Swift)", "Most nourishing Nakshatra for agriculture, harvests, and new beginnings"),
    ("Ashlesha", "Tikshna (Sharp)", "Watch humidity & pest vigilance; prefer maintenance over major ceremonies"),
    ("Magha", "Ugra (Fierce)", "Traditional ancestor/heritage focus; moderate for heavy farm infrastructure"),
    ("Purva Phalguni", "Ugra (Fierce)", "Warm creative energy; suitable for outdoor cultural gatherings in clear weather"),
    ("Uttara Phalguni", "Dhruva (Fixed)", "Highly auspicious Dhruva star for weddings, agreements, and perennial planting"),
    ("Hasta", "Kshipra (Swift)", "Classic post-monsoon harvest star (Hasta Karthe); great for sowing & crafts"),
    ("Chitra", "Mridu (Mild)", "Balanced brightness; auspicious for outdoor events, horticulture, and land work"),
    ("Swati", "Chara (Movable)", "Wind-linked star; auspicious for sowing, rain-drop absorption, and commerce"),
    ("Vishakha", "Mishra (Mixed)", "Strong seasonal winds/shift; good for storage, harvesting, and irrigation prep"),
    ("Anuradha", "Mridu (Mild)", "Highly harmonious for weddings, group travel, and irrigated sowing"),
    ("Jyeshtha", "Tikshna (Sharp)", "Better for protective field checks and drainage maintenance than ceremonies"),
    ("Mula", "Tikshna (Sharp)", "Favors root crops, soil digging, and herbal/medicinal plantation"),
    ("Purva Ashadha", "Ugra (Fierce)", "Water-deity star (Apas); strongly tied to coastal/monsoon moisture"),
    ("Uttara Ashadha", "Dhruva (Fixed)", "Enduring & auspicious for foundation work, permanent crops, and marriages"),
    ("Shravana", "Chara (Movable)", "Favorable for learning, travel, water conservation, and community events"),
    ("Dhanishta", "Chara (Movable)", "Good for rhythmic teamwork, harvests, travel, and grain storage"),
    ("Shatabhisha", "Chara (Movable)", "Favors herbal cultivation, irrigation repair, and healing/wellness"),
    ("Purva Bhadrapada", "Ugra (Fierce)", "Caution for severe weather bursts; avoid major outdoor launches if clouds build"),
    ("Uttara Bhadrapada", "Dhruva (Fixed)", "Cool & grounding moisture star; auspicious for trees, reservoirs, and vows"),
    ("Revati", "Mridu (Mild)", "Gentle & auspicious closing star for weddings, sowing, and safe journeys"),
]

_AUSPICIOUS_NAKSHATRAS = {
    "Ashwini", "Rohini", "Mrigashira", "Punarvasu", "Pushya",
    "Uttara Phalguni", "Hasta", "Chitra", "Swati", "Anuradha",
    "Uttara Ashadha", "Shravana", "Dhanishta", "Uttara Bhadrapada", "Revati",
}

YOGAS = [
    ("Vishkambha", "Neutral"), ("Priti", "Auspicious"), ("Ayushman", "Auspicious"),
    ("Saubhagya", "Auspicious"), ("Shobhana", "Auspicious"), ("Atiganda", "Caution"),
    ("Sukarma", "Auspicious"), ("Dhriti", "Auspicious"), ("Shula", "Caution"),
    ("Ganda", "Caution"), ("Vriddhi", "Auspicious"), ("Dhruva", "Auspicious"),
    ("Vyaghata", "Caution"), ("Harshana", "Auspicious"), ("Vajra", "Caution"),
    ("Siddhi", "Auspicious"), ("Vyatipata", "Caution"), ("Variyana", "Auspicious"),
    ("Parigha", "Caution"), ("Shiva", "Auspicious"), ("Siddha", "Auspicious"),
    ("Sadhya", "Auspicious"), ("Shubha", "Auspicious"), ("Shukla", "Auspicious"),
    ("Brahma", "Auspicious"), ("Indra", "Auspicious"), ("Vaidhriti", "Caution"),
]

MOVABLE_KARANAS = ["Bava", "Balava", "Kaulava", "Taitila", "Gara", "Vanija", "Vishti (Bhadra)"]

# Mapped by Solar Rashi index (0=Mesha .. 11=Meena) -> (Amanta Masa, Ritu Season)
SOLAR_MASA_RITU = [
    ("Chaitra / Vaishakha", "Vasanta (Spring)", "Mesha (Aries)"),
    ("Vaishakha / Jyeshtha", "Grishma (Summer)", "Vrishabha (Taurus)"),
    ("Jyeshtha / Ashadha", "Grishma (Peak Summer)", "Mithuna (Gemini)"),
    ("Ashadha / Shravana", "Varsha (Early Monsoon)", "Karka (Cancer)"),
    ("Shravana / Bhadrapada", "Varsha (Peak Monsoon)", "Simha (Leo)"),
    ("Bhadrapada / Ashwin", "Sharad (Late Monsoon / Early Autumn)", "Kanya (Virgo)"),
    ("Ashwin / Kartika", "Sharad (Autumn)", "Tula (Libra)"),
    ("Kartika / Margashirsha", "Hemanta (Pre-Winter)", "Vrishchika (Scorpio)"),
    ("Margashirsha / Pausha", "Hemanta (Early Winter)", "Dhanu (Sagittarius)"),
    ("Pausha / Magha", "Shishira (Winter)", "Makara (Capricorn)"),
    ("Magha / Phalguna", "Shishira (Late Winter)", "Kumbha (Aquarius)"),
    ("Phalguna / Chaitra", "Vasanta (Early Spring)", "Meena (Pisces)"),
]

AMANTA_MASA_NAMES = [
    "Chaitra", "Vaishakha", "Jyeshtha", "Ashadha", "Shravana", "Bhadrapada",
    "Ashwin", "Kartika", "Margashirsha", "Pausha", "Magha", "Phalguna",
]

# Weekday index (0=Sun..6=Sat) -> 1-based eighth-of-daytime segment (1..8)
_RAHU_KAAL_SEGMENT = {0: 8, 1: 2, 2: 7, 3: 5, 4: 6, 5: 4, 6: 3}
_YAMAGANDA_SEGMENT = {0: 5, 1: 4, 2: 3, 3: 2, 4: 1, 5: 7, 6: 6}

# Curated Hybrid RAG Knowledge Base (Agro-Meteorology + Cultural Calendar + Weather Signals)
_HYBRID_RAG_DOCS: List[Dict[str, Any]] = [
    {
        "id": "agro_waxing_sowing",
        "topics": ["farming", "sowing", "crop", "seed", "agriculture", "plant", "garden", "kheti"],
        "title": "Lunar Phase & Moisture Window for Sowing (Shukla vs Krishna Paksha)",
        "content": (
            "Traditional Indian agronomy aligns Shukla Paksha (waxing moon, Tithis 2–13) "
            "and Fixed/Swift Nakshatras (Rohini, Pushya, Hasta, Uttara) with sowing "
            "above-ground, leafy, and fruiting crops when topsoil moisture is sufficient "
            "and heavy downpour risk is low (<40%). Krishna Paksha supports root crops, "
            "pruning, weeding, and dry-weather harvesting."
        ),
    },
    {
        "id": "agro_surya_nakshatra_karthe",
        "topics": ["farming", "rain", "monsoon", "karthe", "nakshatra", "harvest", "irrigation"],
        "title": "Surya Nakshatra (Karthe) & Rainfall Alignment",
        "content": (
            "Indian agricultural calendars track the Sun's transit through 27 Nakshatras "
            "(each ~13.3 days). Rohini, Mrigashira, Ardra, Punarvasu, Pushya, Hasta, and "
            "Swati transitions historically anchor monsoon onset, mid-season breaks, and "
            "post-monsoon showers. Fusing Surya Nakshatra stage with live rain probability "
            "prevents waterlogging during germination and helps schedule grain drying."
        ),
    },
    {
        "id": "muhurtham_wedding_outdoor",
        "topics": ["wedding", "marriage", "muhurtham", "muhurat", "ceremony", "event", "outdoor", "auspicious"],
        "title": "Outdoor Wedding & Ceremony Muhurtham + Microclimate Check",
        "content": (
            "Optimal outdoor ceremonies pair auspicious Tithis (Dwitiya, Tritiya, Panchami, "
            "Saptami, Dashami, Ekadashi, Trayodashi) and Dhruva/Mridu/Kshipra Nakshatras "
            "(Rohini, Mrigashira, Uttara Phalguni, Hasta, Anuradha, Revati) with Rahu Kaal "
            "avoidance and weather validation (rain probability <25%, mild winds <22 km/h, "
            "comfortable apparent temperature 18–32°C, and healthy AQI)."
        ),
    },
    {
        "id": "festival_lunisolar_weather",
        "topics": ["ugadi", "diwali", "deepavali", "holi", "pongal", "sankranti", "ekadashi", "purnima", "amavasya", "festival", "kartik"],
        "title": "Indic Lunisolar Festivals & Seasonal Weather Regimes",
        "content": (
            "Hindu festivals follow lunisolar Tithi-Masa coordinates (e.g. Chaitra Shukla "
            "Pratipada for Ugadi/Gudi Padwa in Vasanta; Kartika Amavasya for Deepavali "
            "during cool Sharad-Hemanta evenings; Makara Sankranti at winter solstice shift). "
            "Because lunar dates drift 10–11 days yearly across solar weeks, evaluating exact "
            "astronomical ephemeris alongside seasonal weather provides reliable outlook."
        ),
    },
    {
        "id": "health_ritu_seasonal",
        "topics": ["health", "ritu", "winter", "summer", "monsoon", "aqi", "diurnal", "fasting"],
        "title": "Ritu-Charya (Seasonal Regimen) & Microclimate Comfort",
        "content": (
            "Each Vedic Ritu brings characteristic atmospheric shifts: Sharad and Hemanta "
            "(Oct–Dec) exhibit sharp day-night temperature inversions that trap urban AQI; "
            "Grishma calls for hydration and peak-UV avoidance during Abhijit noon; Varsha "
            "requires drainage and thunderstorm monitoring."
        ),
    },
]

_PANCHANGAM_QUERY_PATTERN = re.compile(
    r"\b("
    r"panchang\w*|tithi\w*|nakshatra\w*|muhurth?\w*|muhurat\w*|rahu\s*ka+l|yamaganda|"
    r"abhijit|ekadashi|purnima|amavasya|pradosh|chaturthi|sankashti|navaratri|"
    r"ugadi|diwali|deepavali|pongal|sankranti|holi|shivaratri|janmashtami|ganesh|"
    r"dussehra|vijayadashami|akshaya|kartik\w*|chaitra|vaishakha|shravana|margashirsha|"
    r"lunisolar|hindu\s+calendar|vedic|ritu|sowing|harvest\w*|farm\w*|crop\w*|kheti|"
    r"wedding|marriage|auspicious"
    r")\b",
    re.IGNORECASE,
)


def is_panchangam_query(message: str) -> bool:
    """Detect whether a user prompt touches Indic calendar, Panchangam, agro, or Muhurtham."""
    if not message:
        return False
    if _PANCHANGAM_QUERY_PATTERN.search(message):
        return True
    # Check common Devanagari / Telugu / Tamil terms for Panchangam/Tithi/Farming
    indic_keywords = ("पंचांग", "तिथि", "मुहूर्त", "नक्षत्र", "फसल", "పంచాంగం", "తిథి", "ముహూర్తం", "పంట")
    return any(tok in message for tok in indic_keywords)


def _infer_tz_offset_hours(lat: float, lon: float) -> Tuple[float, str]:
    """Infer civil/solar timezone offset cleanly without heavy boundary lookups."""
    if 68.0 <= lon <= 98.0 and 6.0 <= lat <= 38.0:
        return 5.5, "IST"
    offset = round((lon / 15.0) * 2.0) / 2.0
    sign = "+" if offset >= 0 else "-"
    abs_h = int(abs(offset))
    abs_m = int(round((abs(offset) - abs_h) * 60))
    label = "UTC" if offset == 0 else f"UTC{sign}{abs_h:02d}:{abs_m:02d}"
    return offset, label


def _lahiri_ayanamsa_deg(dt_utc: datetime) -> float:
    years_since_j2000 = (dt_utc - _J2000_UTC).total_seconds() / (365.25 * 86400.0)
    return _LAHIRI_J2000_DEG + (years_since_j2000 * _PRECESSION_DEG_PER_YEAR)


def _sun_moon_sidereal_deg(dt_utc: datetime) -> Tuple[float, float, float]:
    """Return (sun_sidereal_deg, moon_sidereal_deg, moon_illumination_pct) at UTC datetime."""
    dt_naive = dt_utc.astimezone(timezone.utc).replace(tzinfo=None)
    sun = ephem.Sun(dt_naive)
    moon = ephem.Moon(dt_naive)
    sun_trop = math.degrees(float(ephem.Ecliptic(sun).lon)) % 360.0
    moon_trop = math.degrees(float(ephem.Ecliptic(moon).lon)) % 360.0
    ayanamsa = _lahiri_ayanamsa_deg(dt_utc)
    sun_sid = (sun_trop - ayanamsa) % 360.0
    moon_sid = (moon_trop - ayanamsa) % 360.0
    return sun_sid, moon_sid, round(float(moon.phase), 1)


def _find_boundary_crossing_utc(
    start_utc: datetime, target_idx: int, step_deg: float, mode: str
) -> Optional[datetime]:
    """
    Bisection root finder (~15 iterations) to compute exact end UTC timestamp
    when Tithi (12 deg step) or Nakshatra (13.333 deg step) transitions to next index.
    """
    target_angle = ((target_idx + 1) * step_deg) % 360.0

    def metric_fn(dt: datetime) -> float:
        sun_sid, moon_sid, _ = _sun_moon_sidereal_deg(dt)
        return ((moon_sid - sun_sid) % 360.0) if mode == "tithi" else moon_sid

    def signed_diff(dt: datetime) -> float:
        diff = (metric_fn(dt) - target_angle + 180.0) % 360.0 - 180.0
        return diff

    lo = start_utc
    # Tithi max duration ~27h, Nakshatra max duration ~27h -> bracket +32h safely
    hi = start_utc + timedelta(hours=32)
    f_lo = signed_diff(lo)
    # Walk forward in 2h increments until crossing detected
    probe = lo
    for _ in range(17):
        nxt = probe + timedelta(hours=2)
        f_nxt = signed_diff(nxt)
        if f_lo <= 0.0 <= f_nxt:
            lo, hi = probe, nxt
            break
        probe = nxt
        f_lo = f_nxt
    else:
        return None

    for _ in range(14):
        mid = lo + (hi - lo) / 2
        if signed_diff(mid) >= 0.0:
            hi = mid
        else:
            lo = mid
    return hi


def _fmt_local_hhmm(dt_utc: Optional[datetime], tz_offset_h: float) -> str:
    if dt_utc is None:
        return "--:--"
    local_dt = dt_utc + timedelta(hours=tz_offset_h)
    return local_dt.strftime("%H:%M")


def _detect_special_tithi_event(
    amanta_masa: str, paksha: str, tithi_in_paksha: int, tithi_num: int, solar_rashi_idx: int
) -> Optional[str]:
    """Identify prominent Vedic/Indian lunisolar festival or vrata dates."""
    if tithi_num == 15:
        if amanta_masa == "Kartika":
            return "Kartik Purnima / Dev Deepawali"
        if amanta_masa == "Phalguna":
            return "Holika Dahan / Phalguna Purnima"
        if amanta_masa == "Ashadha":
            return "Guru Purnima"
        if amanta_masa == "Shravana":
            return "Raksha Bandhan / Shravana Purnima"
        return "Purnima (Full Moon Day)"
    if tithi_num == 30:
        if amanta_masa == "Ashwin":
            return "Deepavali / Lakshmi Puja Amavasya"
        if amanta_masa == "Kartika":
            return "Kartika Amavasya"
        return "Amavasya (New Moon Day)"
    if tithi_in_paksha == 11:
        return f"{paksha} Ekadashi (Fasting & Mindfulness Day)"
    if tithi_in_paksha == 13:
        return f"{paksha} Pradosh Vrat"
    if amanta_masa == "Chaitra" and paksha == "Shukla" and tithi_in_paksha == 1:
        return "Ugadi / Gudi Padwa (Lunisolar New Year)"
    if amanta_masa == "Vaishakha" and paksha == "Shukla" and tithi_in_paksha == 3:
        return "Akshaya Tritiya"
    if amanta_masa == "Bhadrapada" and paksha == "Shukla" and tithi_in_paksha == 4:
        return "Ganesh Chaturthi"
    if amanta_masa == "Ashwin" and paksha == "Shukla" and tithi_in_paksha == 10:
        return "Vijayadashami / Dussehra"
    if amanta_masa == "Magha" and paksha == "Shukla" and tithi_in_paksha == 5:
        return "Vasant Panchami"
    if amanta_masa == "Magha" and paksha == "Krishna" and tithi_in_paksha == 14:
        return "Maha Shivaratri"
    if solar_rashi_idx == 9 and tithi_in_paksha <= 2:
        # Early Makara solar ingress (~Jan 14-15)
        return "Makara Sankranti / Pongal Season"
    return None


class PanchangamService:
    """
    Astronomical Drik Panchangam + Hybrid Agro-Meteorological & Muhurtham RAG Engine.
    """

    def resolve_target_date(self, date_str: Optional[str], lat: float, lon: float) -> date:
        """Resolve 'today', 'tomorrow', 'YYYY-MM-DD', or natural offset into a date."""
        tz_offset_h, _ = _infer_tz_offset_hours(lat, lon)
        local_today = (datetime.now(timezone.utc) + timedelta(hours=tz_offset_h)).date()
        if not date_str:
            return local_today
        cleaned = date_str.strip().lower()
        if cleaned in ("", "today", "now"):
            return local_today
        if cleaned == "tomorrow":
            return local_today + timedelta(days=1)
        if cleaned == "yesterday":
            return local_today - timedelta(days=1)
        try:
            return datetime.strptime(cleaned[:10], "%Y-%m-%d").date()
        except ValueError:
            return local_today

    def compute_panchangam(
        self,
        lat: float,
        lon: float,
        target_date: Optional[date] = None,
    ) -> Dict[str, Any]:
        """Compute full astronomical Drik Panchangam for a geographic coordinate and date."""
        tz_offset_h, tz_label = _infer_tz_offset_hours(lat, lon)
        if target_date is None:
            target_date = (datetime.now(timezone.utc) + timedelta(hours=tz_offset_h)).date()

        local_midnight_utc = datetime.combine(
            target_date, dt_time(0, 0), tzinfo=timezone.utc
        ) - timedelta(hours=tz_offset_h)

        obs = ephem.Observer()
        obs.lat = str(lat)
        obs.lon = str(lon)
        obs.elevation = 0
        obs.horizon = "-0:34"

        sunrise_utc: Optional[datetime] = None
        sunset_utc: Optional[datetime] = None
        try:
            obs.date = local_midnight_utc.replace(tzinfo=None)
            sunrise_utc = obs.next_rising(ephem.Sun()).datetime().replace(tzinfo=timezone.utc)
            sunset_utc = obs.next_setting(ephem.Sun(), start=sunrise_utc.replace(tzinfo=None)).datetime().replace(tzinfo=timezone.utc)
        except (ephem.AlwaysUpError, ephem.NeverUpError):
            sunrise_utc = local_midnight_utc + timedelta(hours=6)
            sunset_utc = local_midnight_utc + timedelta(hours=18)

        # Evaluate Udaya (sunrise) state per Drik Panchangam convention
        eval_utc = sunrise_utc or (local_midnight_utc + timedelta(hours=6))
        sun_sid, moon_sid, moon_illum_pct = _sun_moon_sidereal_deg(eval_utc)

        # 1. Tithi (12 deg elongation per tithi)
        elongation = (moon_sid - sun_sid) % 360.0
        tithi_idx = int(elongation // 12.0)  # 0..29
        tithi_num = tithi_idx + 1
        tithi_progress_pct = round(((elongation % 12.0) / 12.0) * 100.0, 1)
        paksha = "Shukla" if tithi_num <= 15 else "Krishna"
        tithi_in_paksha = tithi_num if tithi_num <= 15 else tithi_num - 15
        tithi_name = f"{paksha} {TITHI_NAMES[tithi_idx]}"
        tithi_end_utc = _find_boundary_crossing_utc(eval_utc, tithi_idx, 12.0, mode="tithi")

        # 2. Nakshatra (13.3333 deg arc per nakshatra)
        nak_arc = 360.0 / 27.0
        nak_idx = int(moon_sid // nak_arc) % 27
        pada = int(((moon_sid % nak_arc) // (nak_arc / 4.0))) + 1
        nak_name, nak_nature, nak_agro_note = NAKSHATRAS[nak_idx]
        nak_end_utc = _find_boundary_crossing_utc(eval_utc, nak_idx, nak_arc, mode="nakshatra")

        # 3. Yoga ((Sun + Moon sidereal) / 13.3333 deg)
        yoga_sum = (sun_sid + moon_sid) % 360.0
        yoga_idx = int(yoga_sum // nak_arc) % 27
        yoga_name, yoga_auspiciousness = YOGAS[yoga_idx]

        # 4. Karana (half-tithi: 6 deg elongation increments)
        karana_idx = int(elongation // 6.0)  # 0..59
        if karana_idx == 0:
            karana_name = "Kimstughna"
        elif karana_idx == 57:
            karana_name = "Shakuni"
        elif karana_idx == 58:
            karana_name = "Chatushpada"
        elif karana_idx == 59:
            karana_name = "Naga"
        else:
            karana_name = MOVABLE_KARANAS[(karana_idx - 1) % 7]

        # 5. Vara (Weekday: Python weekday 0=Mon..6=Sun -> 0=Sun..6=Sat)
        sun_based_wd = (target_date.weekday() + 1) % 7
        vara_name, vara_lord = VARAS[sun_based_wd]

        # Solar Rashi, Surya Nakshatra (Karthe), Vedic Masa & Ritu
        solar_rashi_idx = int(sun_sid // 30.0) % 12
        _, ritu_name, surya_rashi = SOLAR_MASA_RITU[solar_rashi_idx]
        surya_nak_idx = int(sun_sid // nak_arc) % 27
        surya_nak_name = NAKSHATRAS[surya_nak_idx][0]

        # Amanta lunar month begins after the New Moon in the preceding zodiac sign:
        # New Moon in Meena (11) initiates Chaitra (0); New Moon in Tula (6) initiates Kartika (7).
        days_since_new_moon = (tithi_idx * 29.53059) / 30.0
        new_moon_sun_sid = (sun_sid - (days_since_new_moon * 0.9856)) % 360.0
        new_moon_rashi = int(new_moon_sun_sid // 30.0) % 12
        amanta_masa = AMANTA_MASA_NAMES[(new_moon_rashi + 1) % 12]

        # Daytime Muhurtham Windows (Sunrise to Sunset divided into 8 parts)
        day_duration = sunset_utc - sunrise_utc
        segment = day_duration / 8.0
        solar_noon_utc = sunrise_utc + (day_duration / 2.0)

        abhijit_start = solar_noon_utc - timedelta(minutes=24)
        abhijit_end = solar_noon_utc + timedelta(minutes=24)

        rahu_seg = _RAHU_KAAL_SEGMENT[sun_based_wd]
        rahu_start = sunrise_utc + segment * (rahu_seg - 1)
        rahu_end = sunrise_utc + segment * rahu_seg

        yama_seg = _YAMAGANDA_SEGMENT[sun_based_wd]
        yama_start = sunrise_utc + segment * (yama_seg - 1)
        yama_end = sunrise_utc + segment * yama_seg

        brahma_start = sunrise_utc - timedelta(minutes=96)
        brahma_end = sunrise_utc - timedelta(minutes=48)

        special_event = _detect_special_tithi_event(
            amanta_masa, paksha, tithi_in_paksha, tithi_num, solar_rashi_idx
        )

        # Cultural Panchangam Favorability Score (0-100)
        cultural_score = 62
        if tithi_num in _AUSPICIOUS_TITHIS:
            cultural_score += 14
        elif tithi_in_paksha in _RIKTA_TITHI_MOD or tithi_num == 30:
            cultural_score -= 16

        if nak_name in _AUSPICIOUS_NAKSHATRAS:
            cultural_score += 14
        else:
            cultural_score -= 4

        if yoga_auspiciousness == "Auspicious":
            cultural_score += 10
        elif yoga_auspiciousness == "Caution":
            cultural_score -= 10

        if karana_name == "Vishti (Bhadra)":
            cultural_score -= 10

        cultural_score = max(15, min(98, cultural_score))

        return {
            "date": target_date.isoformat(),
            "timezone_label": tz_label,
            "ayanamsa_deg": round(_lahiri_ayanamsa_deg(eval_utc), 3),
            "vara": vara_name,
            "vara_lord": vara_lord,
            "tithi": {
                "name": tithi_name,
                "number": tithi_num,
                "paksha": f"{paksha} Paksha",
                "progress_pct": tithi_progress_pct,
                "ends_at": _fmt_local_hhmm(tithi_end_utc, tz_offset_h),
            },
            "nakshatra": {
                "name": nak_name,
                "pada": pada,
                "nature": nak_nature,
                "agro_tradition": nak_agro_note,
                "ends_at": _fmt_local_hhmm(nak_end_utc, tz_offset_h),
            },
            "yoga": {"name": yoga_name, "rating": yoga_auspiciousness},
            "karana": karana_name,
            "masa": amanta_masa,
            "ritu": ritu_name,
            "surya_rashi": surya_rashi,
            "surya_nakshatra": surya_nak_name,
            "moon_illumination_pct": moon_illum_pct,
            "sunrise": _fmt_local_hhmm(sunrise_utc, tz_offset_h),
            "sunset": _fmt_local_hhmm(sunset_utc, tz_offset_h),
            "daylight_hours": round(day_duration.total_seconds() / 3600.0, 2),
            "muhurtham_windows": {
                "abhijit_muhurtham": f"{_fmt_local_hhmm(abhijit_start, tz_offset_h)}-{_fmt_local_hhmm(abhijit_end, tz_offset_h)} {tz_label}",
                "brahma_muhurtham": f"{_fmt_local_hhmm(brahma_start, tz_offset_h)}-{_fmt_local_hhmm(brahma_end, tz_offset_h)} {tz_label}",
                "rahu_kaal": f"{_fmt_local_hhmm(rahu_start, tz_offset_h)}-{_fmt_local_hhmm(rahu_end, tz_offset_h)} {tz_label}",
                "yamaganda": f"{_fmt_local_hhmm(yama_start, tz_offset_h)}-{_fmt_local_hhmm(yama_end, tz_offset_h)} {tz_label}",
            },
            "special_event": special_event,
            "cultural_score": cultural_score,
        }

    def retrieve_rag_context(self, query: str, activity: str = "general") -> List[Dict[str, str]]:
        """Retrieve the most relevant agro-meteorological & cultural knowledge entries."""
        tokens = set(re.findall(r"[a-z]+", f"{query} {activity}".lower()))
        scored: List[Tuple[int, Dict[str, Any]]] = []
        for doc in _HYBRID_RAG_DOCS:
            overlap = sum(
                1 for kw in doc["topics"] if any(kw in tok or tok in kw for tok in tokens)
            )
            scored.append((overlap, doc))
        scored.sort(key=lambda item: item[0], reverse=True)
        selected = [d for s, d in scored if s > 0][:2]
        if not selected:
            selected = [d for _, d in scored[:2]]
        return [{"title": d["title"], "insight": d["content"]} for d in selected]

    @staticmethod
    def _compute_weather_suitability(
        temp_c: float,
        rain_chance: float,
        wind_kmh: float,
        aqi: float,
        weather_code: int,
        activity: str = "general",
    ) -> Tuple[int, str]:
        """Compute physical meteorological suitability score (0-100) and concise tag."""
        score = 90
        if weather_code >= 95:
            score -= 55  # Thunderstorm hazard
        elif weather_code in (61, 63, 65, 80, 81, 82):
            score -= 28 if activity != "farming" else 8

        if rain_chance >= 70:
            score -= 35 if activity != "farming" else 15
        elif rain_chance >= 40:
            score -= 18 if activity != "farming" else 4
        elif rain_chance >= 20:
            score -= 6

        if temp_c > 38.0 or temp_c < 8.0:
            score -= 24
        elif temp_c > 34.0 or temp_c < 13.0:
            score -= 10

        if wind_kmh > 32.0:
            score -= 22
        elif wind_kmh > 22.0:
            score -= 10

        if aqi > 200:
            score -= 22
        elif aqi > 150:
            score -= 12

        score = max(10, min(98, score))
        if score >= 80:
            label = "Ideal Atmospheric Conditions"
        elif score >= 60:
            label = "Favorable Weather Window"
        elif score >= 40:
            label = "Mixed / Caution Advised"
        else:
            label = "Challenging Weather Risk"
        return score, label

    def fuse_panchangam_and_weather(
        self,
        lat: float,
        lon: float,
        weather_data: Optional[Dict[str, Any]] = None,
        query: str = "",
        date_str: Optional[str] = None,
        activity: str = "general",
    ) -> Dict[str, Any]:
        """
        Execute full Hybrid RAG Fusion: combine Drik Panchangam, retrieved agro/ceremony
        knowledge, and live (or 1km downscaled) meteorological telemetry.
        """
        target_date = self.resolve_target_date(date_str, lat, lon)
        panch = self.compute_panchangam(lat, lon, target_date)

        q_lower = f"{query} {activity}".lower()
        inferred_activity = activity
        if inferred_activity == "general":
            if any(w in q_lower for w in ("farm", "sow", "crop", "harvest", "kheti", "plant")):
                inferred_activity = "farming"
            elif any(w in q_lower for w in ("wedding", "marriage", "muhurth", "muhurat", "ceremony")):
                inferred_activity = "wedding"
            elif any(w in q_lower for w in ("travel", "yatra", "trip")):
                inferred_activity = "travel"

        wd = weather_data or {}
        temp_c = float(wd.get("temperature") or 26.0)
        rain_chance = float(wd.get("rain_chance") or 10.0)
        wind_kmh = float(wd.get("wind_speed") or 10.0)
        aqi = float(wd.get("aqi") or 75.0)
        wcode = int(wd.get("weather_code") or 1)

        weather_score, weather_label = self._compute_weather_suitability(
            temp_c, rain_chance, wind_kmh, aqi, wcode, activity=inferred_activity
        )
        cultural_score = int(panch["cultural_score"])
        composite_score = round((0.45 * cultural_score) + (0.55 * weather_score))

        if composite_score >= 78:
            verdict = "Highly Auspicious & Weather-Clear"
        elif composite_score >= 60:
            verdict = "Favorable Combined Window"
        elif composite_score >= 42:
            verdict = "Moderate — Check Timing & Skies"
        else:
            verdict = "Suboptimal — Reschedule if Flexible"

        # Generate concise domain-specific fused advisory
        paksha = panch["tithi"]["paksha"]
        nak_name = panch["nakshatra"]["name"]
        abhijit = panch["muhurtham_windows"]["abhijit_muhurtham"]
        rahu = panch["muhurtham_windows"]["rahu_kaal"]

        if inferred_activity == "farming":
            lunar_agro = (
                "Shukla Paksha favors sowing/above-ground crops"
                if "Shukla" in paksha
                else "Krishna Paksha favors weeding, root crops & harvesting"
            )
            rain_note = (
                f"mild moisture ({rain_chance:.0f}% rain chance) supports field germination"
                if 15 <= rain_chance <= 55
                else (
                    f"heavy rain risk ({rain_chance:.0f}%) — ensure field drainage"
                    if rain_chance > 55
                    else f"dry skies ({temp_c:.1f}°C, {rain_chance:.0f}% rain) — ideal for harvesting & grain drying"
                )
            )
            advisory = (
                f"{lunar_agro} under {nak_name} Nakshatra (Surya in {panch['surya_nakshatra']}); "
                f"{rain_note}."
            )
        else:
            advisory = (
                f"Best window: Abhijit Muhurtham ({abhijit}) with {temp_c:.1f}°C & "
                f"{rain_chance:.0f}% rain chance ({weather_label}). "
                f"Avoid Rahu Kaal ({rahu})."
            )

        rag_insights = self.retrieve_rag_context(query, inferred_activity)

        return {
            **panch,
            "activity_focus": inferred_activity,
            "weather_alignment": {
                "temperature_c": round(temp_c, 1),
                "rain_chance_pct": round(rain_chance),
                "wind_speed_kmh": round(wind_kmh, 1),
                "aqi": round(aqi),
                "weather_score": weather_score,
                "weather_label": weather_label,
            },
            "composite_score": composite_score,
            "fusion_verdict": verdict,
            "fused_advisory": advisory,
            "rag_knowledge": rag_insights,
        }

    def scan_upcoming_windows(
        self,
        lat: float,
        lon: float,
        daily_forecast: List[Dict[str, Any]],
        activity: str = "wedding",
    ) -> List[Dict[str, Any]]:
        """Rank upcoming forecast days by combined Cultural Panchangam + Weather Score."""
        ranked: List[Dict[str, Any]] = []
        for day_item in daily_forecast:
            d_str = day_item.get("date")
            fused = self.fuse_panchangam_and_weather(
                lat=lat,
                lon=lon,
                weather_data={
                    "temperature": day_item.get("temp_max", 28.0),
                    "rain_chance": day_item.get("rain_chance", 10),
                    "wind_speed": day_item.get("wind_speed_max", 12.0),
                    "aqi": 80,
                    "weather_code": day_item.get("weather_code", 1),
                },
                date_str=d_str,
                activity=activity,
            )
            ranked.append({
                "date": fused["date"],
                "vara": fused["vara"],
                "tithi": fused["tithi"]["name"],
                "nakshatra": fused["nakshatra"]["name"],
                "yoga": fused["yoga"]["name"],
                "abhijit_muhurtham": fused["muhurtham_windows"]["abhijit_muhurtham"],
                "temp_max_c": day_item.get("temp_max"),
                "rain_chance_pct": day_item.get("rain_chance"),
                "cultural_score": fused["cultural_score"],
                "weather_score": fused["weather_alignment"]["weather_score"],
                "composite_score": fused["composite_score"],
                "verdict": fused["fusion_verdict"],
            })
        ranked.sort(key=lambda x: x["composite_score"], reverse=True)
        return ranked

    def format_for_ai(
        self,
        fused: Dict[str, Any],
        upcoming_windows: Optional[List[Dict[str, Any]]] = None,
    ) -> str:
        """Format Hybrid Panchangam + Weather RAG payload cleanly for Gemini tool output."""
        t = fused["tithi"]
        n = fused["nakshatra"]
        y = fused["yoga"]
        m = fused["muhurtham_windows"]
        wa = fused["weather_alignment"]

        lines = [
            f"Panchangam + Weather Hybrid RAG [{fused['date']}, Masa: {fused['masa']}, Ritu: {fused['ritu']}]:",
            f"Vara: {fused['vara']} | Tithi: {t['name']} ({t['progress_pct']}% elapsed, ends {t['ends_at']} {fused['timezone_label']})",
            f"Nakshatra: {n['name']} (Pada {n['pada']}, {n['nature']}, ends {n['ends_at']}) | Surya Nakshatra: {fused['surya_nakshatra']}",
            f"Yoga: {y['name']} ({y['rating']}) | Karana: {fused['karana']} | Moon Illum: {fused['moon_illumination_pct']}%",
            f"Sunrise/Sunset: {fused['sunrise']} / {fused['sunset']} | Abhijit Muhurtham: {m['abhijit_muhurtham']} | Rahu Kaal (Avoid): {m['rahu_kaal']}",
            f"Weather Alignment: Temp={wa['temperature_c']}°C, RainChance={wa['rain_chance_pct']}%, Wind={wa['wind_speed_kmh']}km/h -> WeatherScore={wa['weather_score']}/100, CulturalScore={fused['cultural_score']}/100, Composite={fused['composite_score']}/100 ({fused['fusion_verdict']})",
            f"Fused Advisory: {fused['fused_advisory']}",
        ]
        if fused.get("special_event"):
            lines.append(f"Notable Lunisolar Event: {fused['special_event']}")
        for doc in fused.get("rag_knowledge", []):
            lines.append(f"RAG Context [{doc['title']}]: {doc['insight']}")
        if upcoming_windows:
            top3 = "; ".join(
                f"{w['date']} ({w['tithi']}, {w['nakshatra']}, Rain {w['rain_chance_pct']}%, Score {w['composite_score']}/100)"
                for w in upcoming_windows[:3]
            )
            lines.append(f"Top Upcoming Windows: {top3}")
        return " | ".join(lines)


panchangam_service = PanchangamService()
