"""집계 CSV(tools/source) → 앱용 JSON(app/assets/data) 변환.

격차 등급 규칙은 이 파일에만 둔다. 앱은 결과(level, reason)만 읽는다.
실행: python build_app_data.py
"""
import csv
import json
from pathlib import Path

HERE = Path(__file__).parent
SOURCE = HERE / "source"
OUT = HERE.parent / "app" / "assets" / "data"

# 원본 데이터의 지명 문제. 고치지 않으면 같은 지역이 두 번 나오고 등급이 서로 어긋난다.
NAME_FIXES = {"깅화군": "강화군", "하양읍": "경산시"}  # 오타 / 읍은 소속 시로
SIDO_UNIFY = {"전라남도": "전남광주통합특별시", "광주광역시": "전남광주통합특별시"}  # 옛 이름과 새 이름이 섞여 있음

WEEKEND_CLOSED_WARN_PCT = 50
LIBRARY_COUNTS = {"total": "전체", "hub": "거점", "local": "동네", "readOnly": "열람전용",
                  "suspect": "오류의심", "weekendClosed": "주말휴관"}


def read_rows(name):
    with open(SOURCE / name, encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def clean_region(sido, sigungu):
    """(시도, 시군구) 이름을 하나로 맞춘다: 공백, 반복된 시도 이름, 오타, 옛 시도 이름."""
    sido = sido.strip()
    name = sigungu.replace("　", " ").strip().removeprefix(sido).strip()
    if name in ("", "없음"):  # 세종처럼 시군구가 없는 곳은 시도 이름을 그대로 쓴다
        name = sido
    city, _, district = name.partition(" ")
    if district and city.endswith("시"):  # '창원시 성산구' 같은 일반구는 소속 시로 합친다
        name = city
    return SIDO_UNIFY.get(sido, sido), NAME_FIXES.get(name, name)


def library_level(hub, weekend_closed_pct):
    """(등급, 이유). 빨강: 거점 0곳 / 주황: 거점 1곳 + 주말 휴관 50% 이상 / 초록: 그 외"""
    if hub == 0:
        return "red", "대형 거점 도서관이 없습니다."
    if hub == 1 and weekend_closed_pct >= WEEKEND_CLOSED_WARN_PCT:
        return "orange", "거점 도서관이 1곳뿐이고 주말에 닫는 도서관이 절반 이상입니다."
    if hub == 1:
        return "green", "거점 도서관이 1곳 있고 주말에 닫는 도서관이 절반 미만입니다."
    return "green", f"대형 거점 도서관이 {hub}곳 있습니다."


def smoking_level(high_pct, camp_per_1000, national):
    """(등급, 이유). 고의존 비율이 전국보다 높음 / 캠프 이용이 전국보다 적음 — 둘 다면 빨강, 하나면 주황"""
    high_need = high_pct > national["highPct"]
    low_camp = camp_per_1000 < national["campPer1000"]
    if high_need and low_camp:
        return "red", "고의존자 비율은 전국 평균보다 높은데 금연캠프 이용은 평균보다 적습니다."
    if high_need:
        return "orange", "고의존자 비율이 전국 평균보다 높습니다."
    if low_camp:
        return "orange", "고의존자 대비 금연캠프 이용이 전국 평균보다 적습니다."
    return "green", "고의존자 비율과 금연캠프 이용이 모두 평균보다 양호합니다."


def build_libraries():
    merged = {}  # 이름을 맞춘 뒤 같은 지역의 행을 더한다
    for row in read_rows("unsup_gap_by_sigungu.csv"):
        counts = merged.setdefault(clean_region(row["시도명"], row["시군구명"]), dict.fromkeys(LIBRARY_COUNTS, 0))
        for key, column in LIBRARY_COUNTS.items():
            counts[key] += int(row[column])

    regions = []
    for (sido, sigungu), c in merged.items():
        closed_pct = c["weekendClosed"] / c["total"] * 100  # 반올림 전 값으로 판정
        level, reason = library_level(c["hub"], closed_pct)
        regions.append({
            "sido": sido, "sigungu": sigungu,
            "total": c["total"], "hub": c["hub"], "local": c["local"],
            "readOnly": c["readOnly"], "suspect": c["suspect"],
            "weekendClosedPct": round(closed_pct, 1),
            "level": level, "reason": reason,
        })
    return {"regions": regions}


def build_smoking():
    rows = [{"sido": r["지역"], "registered": int(r["등록자"]), "high": int(r["고의존수"]),
             "camp": int(r["캠프이용"]), "orgs": int(r["제공기관수"])} for r in read_rows("sup_region_resource.csv")]

    def rates(registered, high, camp):
        return {"highPct": high / registered * 100, "campPer1000": camp / high * 1000}

    national = rates(*(sum(r[k] for r in rows) for k in ("registered", "high", "camp")))

    regions = []
    for r in rows:
        rate = rates(r["registered"], r["high"], r["camp"])  # 반올림 전 값으로 판정
        level, reason = smoking_level(rate["highPct"], rate["campPer1000"], national)
        regions.append({
            **r,
            "highPct": round(rate["highPct"], 1),
            "campPer1000": round(rate["campPer1000"]),
            "perOrg": round(r["registered"] / r["orgs"]),
            "level": level, "reason": reason,
        })
    return {"national": {"highPct": round(national["highPct"], 1), "campPer1000": round(national["campPer1000"])},
            "regions": regions}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, data in (("libraries.json", build_libraries()), ("smoking.json", build_smoking())):
        (OUT / name).write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")
        print(f"{name}: {len(data['regions'])} regions")


if __name__ == "__main__":
    main()
