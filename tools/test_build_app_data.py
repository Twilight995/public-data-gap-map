"""build_app_data.py 테스트. 실행: python -m unittest (tools 폴더에서)"""
import unittest

import build_app_data as b


class CleanRegionTest(unittest.TestCase):
    def test_typo_is_fixed(self):
        self.assertEqual(b.clean_region("인천광역시", "깅화군"), ("인천광역시", "강화군"))

    def test_whitespace_including_full_width_is_stripped(self):
        self.assertEqual(b.clean_region("서울특별시", "노원구　"), ("서울특별시", "노원구"))

    def test_repeated_province_prefix_is_removed(self):
        self.assertEqual(b.clean_region("서울특별시", "서울특별시 도봉구"), ("서울특별시", "도봉구"))

    def test_old_province_names_are_unified(self):
        self.assertEqual(b.clean_region("전라남도", "보성군"), ("전남광주통합특별시", "보성군"))
        self.assertEqual(b.clean_region("광주광역시", "남구"), ("전남광주통합특별시", "남구"))

    def test_province_without_districts_uses_its_own_name(self):
        self.assertEqual(b.clean_region("세종특별자치시", "없음"), ("세종특별자치시", "세종특별자치시"))

    def test_city_district_is_merged_into_its_city(self):
        # 일반구는 독립된 시군구가 아니다. 원본에 '창원시'(79곳)와 '창원시 성산구'(1곳)가 따로 있다.
        self.assertEqual(b.clean_region("경상남도", "창원시 성산구"), ("경상남도", "창원시"))

    def test_town_is_mapped_to_its_city(self):
        self.assertEqual(b.clean_region("경상북도", "하양읍"), ("경상북도", "경산시"))


class LibraryLevelTest(unittest.TestCase):
    def test_no_hub_is_red(self):
        self.assertEqual(b.library_level(hub=0, weekend_closed_pct=0)[0], "red")

    def test_one_hub_and_mostly_closed_weekend_is_orange(self):
        self.assertEqual(b.library_level(hub=1, weekend_closed_pct=50)[0], "orange")

    def test_one_hub_open_weekend_is_green(self):
        self.assertEqual(b.library_level(hub=1, weekend_closed_pct=49.9)[0], "green")

    def test_many_hubs_is_green_even_if_closed(self):
        level, reason = b.library_level(hub=2, weekend_closed_pct=90)
        self.assertEqual(level, "green")
        self.assertNotIn("주말", reason)  # 주말에 많이 닫는데 "주말 이용 가능"이라고 하면 거짓


class SmokingLevelTest(unittest.TestCase):
    NATIONAL = {"highPct": 17.8, "campPer1000": 160}

    def level(self, high_pct, camp):
        return b.smoking_level(high_pct, camp, self.NATIONAL)[0]

    def test_high_need_and_low_camp_is_red(self):
        self.assertEqual(self.level(21.8, 124), "red")

    def test_only_one_condition_is_orange(self):
        self.assertEqual(self.level(21.1, 300), "orange")
        self.assertEqual(self.level(15.0, 114), "orange")

    def test_neither_is_green(self):
        self.assertEqual(self.level(14.2, 511), "green")

    def test_exactly_national_is_green(self):
        self.assertEqual(self.level(17.8, 160), "green")


class BuildTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.libraries = b.build_libraries()["regions"]
        cls.smoking = b.build_smoking()

    def library(self, sigungu):
        return next(r for r in self.libraries if r["sigungu"] == sigungu)

    def test_every_region_appears_once(self):
        keys = [(r["sido"], r["sigungu"]) for r in self.libraries]
        self.assertEqual(len(keys), len(set(keys)))
        self.assertEqual(len(keys), 229)  # 원본 252행에서 중복 23행을 합친 수
        self.assertEqual(self.library("창원시")["total"], 83)  # 시 79 + 구 3개 행의 4

    def test_names_are_clean(self):
        for r in self.libraries:
            self.assertEqual(r["sigungu"], r["sigungu"].strip())
            # 시도 이름이 앞에 반복되면 안 된다 (시군구가 없는 세종만 시도 이름 그대로)
            self.assertFalse(r["sigungu"].startswith(r["sido"] + " "))
            self.assertNotEqual(r["sigungu"], "없음")
            self.assertNotIn(r["sido"], ("전라남도", "광주광역시"))
        self.assertNotIn("깅화군", {r["sigungu"] for r in self.libraries})

    def test_duplicate_rows_are_merged_not_contradictory(self):
        self.assertEqual(self.library("강화군")["hub"], 3)
        self.assertEqual(self.library("강화군")["total"], 6)
        self.assertEqual(self.library("보성군")["level"], "green")

    def test_only_wando_has_no_hub(self):
        self.assertEqual([r["sigungu"] for r in self.libraries if r["level"] == "red"], ["완도군"])

    def test_boundary_region_is_orange(self):
        hamyang = self.library("함양군")  # 거점 1곳, 10곳 중 5곳 주말 휴관
        self.assertEqual((hamyang["weekendClosedPct"], hamyang["level"]), (50.0, "orange"))

    def test_every_region_has_reason(self):
        for r in self.libraries + self.smoking["regions"]:
            self.assertTrue(r["reason"])
            self.assertIn(r["level"], ("red", "orange", "green"))

    def test_national_is_computed_from_rows(self):
        rows = self.smoking["regions"]
        registered, high, camp = (sum(r[k] for r in rows) for k in ("registered", "high", "camp"))
        self.assertEqual(len(rows), 17)
        self.assertEqual(self.smoking["national"]["highPct"], round(high / registered * 100, 1))
        self.assertEqual(self.smoking["national"]["campPer1000"], round(camp / high * 1000))

    def test_daegu_is_red(self):
        daegu = next(r for r in self.smoking["regions"] if r["sido"] == "대구광역시")
        self.assertEqual(daegu["level"], "red")


if __name__ == "__main__":
    unittest.main()
