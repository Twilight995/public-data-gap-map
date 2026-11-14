"""행정구역 경계(TopoJSON) → 앱이 바로 그릴 수 있는 좌표 JSON(app/assets/data/map.json).

원자료: 통계청 통계지리정보서비스(SGIS), 공공누리 제1유형, 2018년 12월 기준.
        (https://github.com/southkorea/southkorea-maps 의 kostat/2018 가공본)
실행: python build_map_data.py
"""
import json
import math
from pathlib import Path

from build_app_data import SIDO_UNIFY, build_libraries

HERE = Path(__file__).parent
TOPO = HERE / "source" / "geo" / "skorea-municipalities-2018-topo-simple.json"
OUT = HERE.parent / "app" / "assets" / "data" / "map.json"

# 통계청 시도 코드(앞 두 자리) → 금연 데이터가 쓰는 시도 이름
SIDO_BY_CODE = {
    "11": "서울특별시", "21": "부산광역시", "22": "대구광역시", "23": "인천광역시", "24": "광주광역시",
    "25": "대전광역시", "26": "울산광역시", "29": "세종특별자치시", "31": "경기도", "32": "강원특별자치도",
    "33": "충청북도", "34": "충청남도", "35": "전북특별자치도", "36": "전라남도", "37": "경상북도",
    "38": "경상남도", "39": "제주특별자치도",
}
# 2018년 이후 바뀐 구역: (2018년 시도, 이름) → 지금의 (시도, 이름)
MOVED = {
    ("경상북도", "군위군"): ("대구광역시", "군위군"),            # 2023년 대구 편입
    ("인천광역시", "남구"): ("인천광역시", "미추홀구"),          # 2018년 7월 이름 변경
    ("세종특별자치시", "세종시"): ("세종특별자치시", "세종특별자치시"),
}
CANVAS_HEIGHT = 1000
MIN_RING_AREA = 0.5  # 화면에서 점보다 작은 섬은 뺀다 (단위: 캔버스 칸²)


def decode_arcs(topo):
    """TopoJSON의 호(arc)를 실제 (경도, 위도) 목록으로 푼다. 좌표는 앞 점과의 차이로 저장돼 있다."""
    (sx, sy), (tx, ty) = topo["transform"]["scale"], topo["transform"]["translate"]
    arcs = []
    for arc in topo["arcs"]:
        x = y = 0
        points = []
        for dx, dy in arc:
            x, y = x + dx, y + dy
            points.append((x * sx + tx, y * sy + ty))
        arcs.append(points)
    return arcs


def ring_points(arc_indexes, arcs):
    """호 번호 목록 → 닫힌 테두리 한 개. 음수 번호(~i)는 i번 호를 거꾸로 쓴다는 뜻."""
    points = []
    for index in arc_indexes:
        arc = arcs[index] if index >= 0 else arcs[~index][::-1]
        points.extend(arc if not points else arc[1:])  # 이어지는 호의 첫 점은 앞 호의 끝점과 같다
    return points


def match_region(sido, name, known):
    """경계 파일의 이름을 도서관 데이터의 (시도, 시군구)에 맞춘다. 없으면 None.

    경계 파일은 일반구를 '창원시마산회원구'처럼 붙여 쓴다. 도서관 데이터는 시 단위이므로 '창원시'로 찾는다.
    """
    city, sep, district = name.partition("시")
    candidates = [name, f"{city}시"] if sep and district else [name]
    return next(((sido, c) for c in candidates if (sido, c) in known), None)


def _area(ring):
    return abs(sum(x1 * y2 - x2 * y1 for (x1, y1), (x2, y2) in zip(ring, ring[1:]))) / 2


def build_map():
    topo = json.loads(TOPO.read_text(encoding="utf-8"))
    arcs = decode_arcs(topo)
    geometries = next(iter(topo["objects"].values()))["geometries"]

    lons = [p[0] for arc in arcs for p in arc]
    lats = [p[1] for arc in arcs for p in arc]
    west, south, north = min(lons), min(lats), max(lats)
    unit = CANVAS_HEIGHT / (north - south)
    squeeze = math.cos(math.radians((north + south) / 2))  # 경도 1도는 위도 1도보다 짧다

    def to_canvas(point):
        lon, lat = point
        return round((lon - west) * squeeze * unit), round((north - lat) * unit)  # 북쪽이 위

    known = {(r["sido"], r["sigungu"]) for r in build_libraries()["regions"]}
    shapes, used = [], set()
    for g in geometries:
        name = g["properties"]["name"]
        old_sido = SIDO_BY_CODE[g["properties"]["code"][:2]]
        sido, current_name = MOVED.get((old_sido, name), (old_sido, name))
        region = match_region(SIDO_UNIFY.get(sido, sido), current_name, known)
        used.add(region)

        rings = []
        polygons = g["arcs"] if g["type"] == "MultiPolygon" else [g["arcs"]]
        for polygon in polygons:
            outer = [to_canvas(p) for p in ring_points(polygon[0], arcs)]  # 바깥 테두리만 (구멍은 그리지 않는다)
            outer = [p for i, p in enumerate(outer) if i == 0 or p != outer[i - 1]]
            if len(outer) >= 4 and _area(outer) >= MIN_RING_AREA:
                rings.append([v for p in outer[:-1] for v in p])
        shapes.append({
            "name": name,
            "library": " ".join(region) if region else None,
            "smoking": old_sido if (old_sido, name) not in MOVED else sido,
            "rings": rings,
        })

    return {
        "source": "통계청 통계지리정보서비스(SGIS), 공공누리 제1유형, 2018년 12월 기준 경계",
        "width": max(x for s in shapes for r in s["rings"] for x in r[0::2]),
        "height": CANVAS_HEIGHT,
        "shapesWithoutLibraryData": sorted(f'{s["smoking"]} {s["name"]}' for s in shapes if s["library"] is None),
        "libraryRegionsNotOnMap": sorted(" ".join(k) for k in known - used),
        "shapes": shapes,
    }


def main():
    data = build_map()
    OUT.write_text(json.dumps(data, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"map.json: {len(data['shapes'])} shapes, {OUT.stat().st_size // 1024} KB")
    print("도서관 데이터가 없는 구역:", data["shapesWithoutLibraryData"])
    print("지도에 없는 도서관 지역:", data["libraryRegionsNotOnMap"])


if __name__ == "__main__":
    main()
