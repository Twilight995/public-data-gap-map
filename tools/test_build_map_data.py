"""build_map_data.py 테스트. 실행: python -m unittest (tools 폴더에서)"""
import json
import unittest

import build_app_data
import build_map_data as m

# 한 칸짜리 정사각형을 호(arc) 두 개로 나눈 아주 작은 TopoJSON
TINY_TOPO = {
    "transform": {"scale": [1, 1], "translate": [10, 20]},
    "arcs": [
        [[0, 0], [1, 0], [0, 1]],    # (10,20) → (11,20) → (11,21)  좌표는 앞 점과의 차이로 적혀 있다
        [[0, 0], [0, 1], [1, 0]],    # (10,20) → (10,21) → (11,21)
    ],
}


class TopoDecodeTest(unittest.TestCase):
    def test_arcs_are_delta_decoded_and_transformed(self):
        arcs = m.decode_arcs(TINY_TOPO)
        self.assertEqual(arcs[0], [(10, 20), (11, 20), (11, 21)])

    def test_negative_index_means_reversed_arc(self):
        arcs = m.decode_arcs(TINY_TOPO)
        ring = m.ring_points([0, ~1], arcs)  # 0번 정방향 + 1번 역방향 = 닫힌 사각형
        self.assertEqual(ring, [(10, 20), (11, 20), (11, 21), (10, 21), (10, 20)])


class MatchNameTest(unittest.TestCase):
    KNOWN = {("경기도", "수원시"), ("경상남도", "창원시"), ("서울특별시", "중구")}

    def test_exact_name(self):
        self.assertEqual(m.match_region("서울특별시", "중구", self.KNOWN), ("서울특별시", "중구"))

    def test_city_district_belongs_to_its_city(self):
        self.assertEqual(m.match_region("경기도", "수원시장안구", self.KNOWN), ("경기도", "수원시"))
        self.assertEqual(m.match_region("경상남도", "창원시마산회원구", self.KNOWN), ("경상남도", "창원시"))

    def test_same_name_in_another_province_does_not_match(self):
        self.assertIsNone(m.match_region("부산광역시", "중구", self.KNOWN))


class BuildTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = m.build_map()
        cls.libraries = {f'{r["sido"]} {r["sigungu"]}' for r in build_app_data.build_libraries()["regions"]}
        cls.smoking = {r["sido"] for r in build_app_data.build_smoking()["regions"]}

    def test_all_250_areas_are_drawn(self):
        self.assertEqual(len(self.data["shapes"]), 250)

    def test_every_shape_belongs_to_a_smoking_province(self):
        self.assertEqual({s["smoking"] for s in self.data["shapes"]}, self.smoking)

    def test_library_keys_point_to_real_regions(self):
        keys = {s["library"] for s in self.data["shapes"]} - {None}
        self.assertLessEqual(keys, self.libraries)

    def test_only_known_gaps_remain(self):
        # 동대문구: 포털에 등록된 도서관이 없다 / 제물포구: 2026년에 새로 생겨 2018년 경계에 없다
        self.assertEqual(self.data["shapesWithoutLibraryData"], ["서울특별시 동대문구"])
        self.assertEqual(self.data["libraryRegionsNotOnMap"], ["인천광역시 제물포구"])

    def test_renamed_areas_are_matched(self):
        by_name = {(s["smoking"], s["name"]): s["library"] for s in self.data["shapes"]}
        self.assertEqual(by_name[("인천광역시", "남구")], "인천광역시 미추홀구")
        self.assertEqual(by_name[("세종특별자치시", "세종시")], "세종특별자치시 세종특별자치시")
        self.assertEqual(by_name[("대구광역시", "군위군")], "대구광역시 군위군")

    def test_app_asset_is_up_to_date(self):
        on_disk = json.loads(m.OUT.read_text(encoding="utf-8"))
        self.assertEqual(on_disk, self.data, "python build_map_data.py 를 다시 실행해야 한다")

    def test_coordinates_fit_inside_the_canvas(self):
        for s in self.data["shapes"]:
            self.assertTrue(s["rings"], f'{s["name"]}: 그릴 테두리가 없다')
            for ring in s["rings"]:
                self.assertEqual(len(ring) % 2, 0)
                self.assertGreaterEqual(len(ring), 6)               # 점 3개 이상
                self.assertTrue(all(0 <= x <= self.data["width"] for x in ring[0::2]))
                self.assertTrue(all(0 <= y <= self.data["height"] for y in ring[1::2]))

    def test_north_is_up(self):
        def top(name):  # 가장 위쪽 y (작을수록 북쪽)
            return min(min(r[1::2]) for s in self.data["shapes"] if s["name"] == name for r in s["rings"])
        self.assertLess(top("철원군"), top("서귀포시"))


if __name__ == "__main__":
    unittest.main()
