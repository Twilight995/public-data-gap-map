"""데이터 품질 경고 목록(app/assets/data/quality.json) 생성.

담당자가 "우리 지역 원본 데이터에서 무엇을 확인해야 하는지" 볼 수 있게 한다.
경고 규칙과 문구는 이 파일에만 둔다. 앱은 구역(section)과 항목(item)을 그대로 보여 준다.
실행: python build_quality_data.py
"""
import json
from collections import defaultdict

from build_app_data import OUT as OUT_DIR
from build_app_data import SIDO_UNIFY, build_libraries, explain_region, read_rows
from build_map_data import build_map

OUT = OUT_DIR / "quality.json"
UNCERTAIN_SUSPECT_SHARE = 0.5  # 등록 도서관 중 입력 오류 의심이 이 비율 이상이면 등급을 믿기 어렵다
NOTICE = ("원본 데이터에서 확인이 필요한 곳입니다. 도서관 데이터는 공공데이터포털 전국도서관표준데이터(2026-10) 기준입니다. "
          "오류라고 단정한 것은 아니며, 해당 지역 담당자가 원본을 확인해 주시면 됩니다.")


def is_uncertain(total, suspect, level):
    """입력 오류 의심이 절반 이상이고, 그 도서관이 실제로 거점이면 등급이 달라지는 지역.

    의심 도서관은 거점 수에 들어 있지 않다. 값을 고치면 거점은 늘기만 하므로 이미 양호(green)인 지역은 그대로다.
    """
    return level != "green" and suspect >= total * UNCERTAIN_SUSPECT_SHARE


def region_title(sido, sigungu):
    return f"{sido} {sigungu}"


def uncertain_section(libraries):
    regions = sorted((r for r in libraries if is_uncertain(r["total"], r["suspect"], r["level"])),
                     key=lambda r: (-r["suspect"] / r["total"], r["sido"], r["sigungu"]))
    return {
        "kind": "uncertain",
        "title": "등급 판정이 불확실한 지역",
        "count": f"{len(regions)}개 지역",
        "description": "등급이 '부족' 또는 '주의'인데 등록 도서관의 절반 이상이 입력 오류 의심인 지역입니다. "
                       "의심 도서관이 실제로는 거점 도서관이라면 등급이 달라질 수 있습니다.",
        "items": [{
            "title": region_title(r["sido"], r["sigungu"]),
            "summary": f'등록 도서관 {r["total"]}곳 중 {r["suspect"]}곳이 입력 오류 의심입니다. '
                       f'현재 판정: {r["reason"]} 원본 값을 확인하면 등급이 달라질 수 있습니다.',
            "details": [],
        } for r in regions],
    }


def suspect_section():
    by_region = defaultdict(list)
    for row in read_rows("suspect_libraries.csv"):
        region, _ = explain_region(row["시도명"], row["시군구명"])
        by_region[region].append((int(row["대출가능권수"]), row["도서관명"].strip(), row["도서관유형"]))

    items = []
    for region, libs in sorted(by_region.items(), key=lambda kv: (-len(kv[1]), kv[0])):
        libs.sort(key=lambda lib: (-lib[0], lib[1]))
        low, high = libs[-1][0], libs[0][0]
        limits = f"{high:,}권" if low == high else f"{low:,}권~{high:,}권"
        items.append({
            "title": region_title(*region),
            "summary": f"도서관 {len(libs)}곳의 1인 대출 한도가 {limits}으로 적혀 있습니다. 원본 값을 확인해 주세요.",
            "details": [f"{name} ({kind}) · 1인 대출 한도 {limit:,}권" for limit, name, kind in libs],
        })
    return {
        "kind": "suspect",
        "title": "입력 오류가 의심되는 도서관",
        "count": f"{len(items)}개 지역 · 도서관 {sum(len(i['details']) for i in items)}곳",
        "description": "군집 분석(비슷한 도서관끼리 묶는 분석)에서 따로 묶인 도서관입니다. "
                       "모두 한 사람이 빌릴 수 있는 책 수(대출 한도) 칸에 1,000권 이상이 적혀 있어, "
                       "다른 칸의 값이 잘못 들어갔을 수 있습니다. 지역을 누르면 도서관 이름이 보입니다.",
        "items": items,
    }


def names_section():
    rows_by_region = defaultdict(list)
    for row in read_rows("unsup_gap_by_sigungu.csv"):
        region, fixes = explain_region(row["시도명"], row["시군구명"])
        original = f'{row["시도명"]} {row["시군구명"]}'
        rows_by_region[region].append((original, int(row["전체"]), fixes))

    def renamed_province(region):  # 시도 이름이 바뀐 지역은 수가 많아 뒤로 보낸다
        return region[0] in SIDO_UNIFY.values()

    changed = {region: rows for region, rows in rows_by_region.items()
               if len(rows) > 1 or any(fixes for _, _, fixes in rows)}
    items = []
    for region, rows in sorted(changed.items(), key=lambda kv: (renamed_province(kv[0]), kv[0])):
        if len(rows) > 1:
            summary = f"원본 {len(rows)}행을 한 지역으로 합쳤습니다. 원본의 지역 이름을 하나로 맞춰 주세요."
        else:
            summary = "원본의 지역 이름을 고쳐서 표시합니다. 원본 표기를 확인해 주세요."
        items.append({
            "title": region_title(*region),
            "summary": summary,
            "details": [f"'{original}' 도서관 {total}곳 → {', '.join(fixes) or '그대로 둠'}"
                        for original, total, fixes in sorted(rows)],
        })
    return {
        "kind": "names",
        "title": "지역 이름을 고치거나 합친 지역",
        "count": f"{len(items)}개 지역",
        "description": "원본에 오타, 옛 시도 이름, 일반구 행 등이 섞여 있어 앱이 이름을 맞추고 같은 지역의 행을 더했습니다. "
                       "지역을 누르면 원본 표기와 고친 내용이 보입니다.",
        "items": items,
    }


def single_section(libraries):
    regions = [r for r in libraries if r["total"] == 1]
    return {
        "kind": "single",
        "title": "등록 도서관이 1곳뿐인 지역",
        "count": f"{len(regions)}개 지역",
        "description": "실제로 도서관이 1곳인지, 공공데이터포털 등록이 빠진 것인지 이 데이터만으로는 알 수 없습니다.",
        "items": [{
            "title": region_title(r["sido"], r["sigungu"]),
            "summary": "등록된 도서관이 1곳입니다. 등록되지 않은 도서관이 있는지 확인해 주세요.",
            "details": [],
        } for r in regions],
    }


def map_section(map_data):
    items = [{
        "title": name,
        "summary": "지도에는 있지만 등록된 도서관이 없어 등급 없이 회색으로 표시됩니다. 등록이 빠졌는지 확인해 주세요.",
        "details": [],
    } for name in map_data["shapesWithoutLibraryData"]] + [{
        "title": name,
        "summary": "도서관 데이터는 있지만 지도 경계(2018년 12월 기준)에 없는 지역이라 지도에 표시되지 않습니다. "
                   "목록에서는 볼 수 있습니다.",
        "details": [],
    } for name in map_data["libraryRegionsNotOnMap"]]
    return {
        "kind": "map",
        "title": "지도와 맞지 않는 지역",
        "count": f"{len(items)}개 지역",
        "description": "지도 경계와 도서관 데이터의 지역이 서로 맞지 않는 곳입니다.",
        "items": items,
    }


def sections_with_items(sections):
    """경고가 없는 구역은 뺀다. 전부 빠지면 앱은 '경고 없음' 화면을 보여 준다."""
    return [s for s in sections if s["items"]]


def build_quality():
    libraries = build_libraries()["regions"]
    return {"notice": NOTICE, "sections": sections_with_items([
        uncertain_section(libraries),
        suspect_section(),
        names_section(),
        single_section(libraries),
        map_section(build_map()),
    ])}


def main():
    data = build_quality()
    OUT.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")
    for s in data["sections"]:
        print(f'{s["title"]}: {s["count"]}')


if __name__ == "__main__":
    main()
