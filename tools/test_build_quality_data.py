"""build_quality_data.py 테스트. 실행: python -m unittest (tools 폴더에서)"""
import json
import unittest

import build_app_data
import build_quality_data as q


class ExplainRegionTest(unittest.TestCase):
    def fixes(self, sido, sigungu):
        return build_app_data.explain_region(sido, sigungu)[1]

    def test_clean_name_has_no_fixes(self):
        self.assertEqual(build_app_data.explain_region("인천광역시", "강화군"), (("인천광역시", "강화군"), []))

    def test_each_kind_of_fix_is_named(self):
        self.assertEqual(self.fixes("인천광역시", "깅화군"), ["오타로 보여 '강화군'으로 고침"])
        self.assertEqual(self.fixes("경상북도", "하양읍"), ["읍 이름이라 소속 시 '경산시'로 합침"])
        self.assertEqual(self.fixes("경상남도", "창원시 성산구"), ["일반구라 소속 시 '창원시'로 합침"])
        self.assertEqual(self.fixes("서울특별시", "노원구　"), ["이름 앞뒤 공백을 지움"])
        self.assertEqual(self.fixes("서울특별시", "서울특별시 도봉구"), ["시군구 칸에 반복된 시도 이름을 지움"])
        self.assertEqual(self.fixes("세종특별자치시", "없음"), [])  # 시군구가 없는 것은 정상 표기
        self.assertEqual(self.fixes("전라남도", "보성군"), ["옛 시도 이름을 '전남광주통합특별시'로 바꿈"])

    def test_region_data_did_not_change(self):
        # 고친 내용을 기록하도록 바꾸면서 지역·등급이 달라지면 안 된다. 커밋된 libraries.json 과 비교한다.
        on_disk = json.loads((build_app_data.OUT / "libraries.json").read_text(encoding="utf-8"))
        self.assertEqual(on_disk, build_app_data.build_libraries(), "지역 이름 정리 결과가 달라졌다")


class BuildTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = q.build_quality()
        cls.sections = {s["kind"]: s for s in cls.data["sections"]}

    def item(self, kind, title):
        return next(i for i in self.sections[kind]["items"] if i["title"] == title)

    def titles(self, kind):
        return [i["title"] for i in self.sections[kind]["items"]]

    def test_section_order_and_counts(self):
        self.assertEqual(
            [(s["kind"], len(s["items"])) for s in self.data["sections"]],
            [("uncertain", 3), ("suspect", 9), ("names", 31), ("single", 4), ("map", 2)],
        )

    def test_every_section_and_item_has_text(self):
        self.assertIn("확인", self.data["notice"])
        for s in self.data["sections"]:
            self.assertTrue(s["title"] and s["count"] and s["description"])
            for i in s["items"]:
                self.assertTrue(i["title"] and i["summary"])
                self.assertIsInstance(i["details"], list)

    # 1. 입력 오류 의심
    def test_suspect_regions_are_sorted_by_count(self):
        self.assertEqual(self.titles("suspect")[:4],
                         ["경상남도 진주시", "제주특별자치도 제주시", "경상남도 합천군", "제주특별자치도 서귀포시"])
        self.assertEqual(self.sections["suspect"]["count"], "9개 지역 · 도서관 155곳")

    def test_jinju_lists_its_73_libraries(self):
        jinju = self.item("suspect", "경상남도 진주시")
        self.assertEqual(len(jinju["details"]), 73)
        self.assertIn("73곳", jinju["summary"])
        self.assertIn("확인해 주세요", jinju["summary"])

    def test_library_lines_show_name_and_written_limit_largest_first(self):
        wando = self.item("suspect", "전남광주통합특별시 완도군")
        self.assertEqual(wando["details"][0], "완도군립도서관 (공공도서관) · 1인 대출 한도 149,538권")
        self.assertEqual(len(wando["details"]), 3)

    def test_suspect_counts_match_region_data(self):
        expected = {f'{r["sido"]} {r["sigungu"]}': r["suspect"]
                    for r in build_app_data.build_libraries()["regions"] if r["suspect"]}
        self.assertEqual({i["title"]: len(i["details"]) for i in self.sections["suspect"]["items"]}, expected)

    # 2. 지명 정리
    def test_typo_row_is_recorded(self):
        ganghwa = self.item("names", "인천광역시 강화군")
        self.assertIn("원본 2행", ganghwa["summary"])
        self.assertEqual(ganghwa["details"], [
            "'인천광역시 강화군' 도서관 5곳 → 그대로 둠",
            "'인천광역시 깅화군' 도서관 1곳 → 오타로 보여 '강화군'으로 고침",
        ])

    def test_old_and_new_province_rows_are_recorded(self):
        boseong = self.item("names", "전남광주통합특별시 보성군")
        self.assertIn("원본 2행", boseong["summary"])
        self.assertIn("'전라남도 보성군' 도서관 4곳 → 옛 시도 이름을 '전남광주통합특별시'로 바꿈", boseong["details"])

    def test_city_districts_are_recorded(self):
        changwon = self.item("names", "경상남도 창원시")
        self.assertIn("원본 4행", changwon["summary"])
        self.assertIn("'경상남도 창원시 성산구' 도서관 1곳 → 일반구라 소속 시 '창원시'로 합침", changwon["details"])

    def test_renamed_only_row_is_not_called_a_merge(self):
        dobong = self.item("names", "서울특별시 도봉구")
        self.assertNotIn("합쳤", dobong["summary"])
        self.assertEqual(len(dobong["details"]), 1)

    def test_merged_rows_add_up_to_the_original_252(self):
        merged = sum(len(i["details"]) for i in self.sections["names"]["items"])
        self.assertEqual(229 - 31 + merged, 252)

    def test_normal_name_without_districts_is_not_a_warning(self):
        self.assertNotIn("세종특별자치시 세종특별자치시", self.titles("names"))

    def test_old_province_only_fixes_come_last(self):
        titles = self.titles("names")
        self.assertLess(titles.index("인천광역시 강화군"), titles.index("전남광주통합특별시 보성군"))

    # 3. 등록 1곳
    def test_single_library_regions(self):
        self.assertEqual(sorted(t.split()[1] for t in self.titles("single")), ["강진군", "봉화군", "부여군", "울릉군"])

    # 4. 지도
    def test_map_gaps_come_from_map_data(self):
        self.assertEqual(self.titles("map"), ["서울특별시 동대문구", "인천광역시 제물포구"])
        self.assertIn("등록된 도서관이 없", self.item("map", "서울특별시 동대문구")["summary"])
        self.assertIn("지도에 표시되지 않", self.item("map", "인천광역시 제물포구")["summary"])

    # 5. 등급 불확실
    def test_wando_grade_is_uncertain(self):
        self.assertEqual(self.titles("uncertain")[0], "전남광주통합특별시 완도군")  # 의심 비율이 큰 순
        wando = self.item("uncertain", "전남광주통합특별시 완도군")
        self.assertIn("3곳 중 3곳", wando["summary"])
        self.assertIn("대형 거점 도서관이 없습니다.", wando["summary"])
        self.assertEqual(self.titles("uncertain"), ["전남광주통합특별시 완도군", "경상남도 진주시", "경상남도 합천군"])

    def test_uncertain_means_half_or_more_suspect_and_grade_can_change(self):
        self.assertTrue(q.is_uncertain(total=4, suspect=2, level="orange"))
        self.assertFalse(q.is_uncertain(total=5, suspect=2, level="red"))
        # 의심 도서관이 거점으로 바뀌어도 양호는 그대로다 (제주시: 50곳 중 32곳 의심, 거점 16곳)
        self.assertFalse(q.is_uncertain(total=50, suspect=32, level="green"))

    def test_single_suspect_library_shows_one_number_not_a_range(self):
        summary = self.item("suspect", "경상북도 영양군")["summary"]
        self.assertIn("64,476권으로", summary)
        self.assertNotIn("~", summary)

    def test_no_warnings_means_no_sections(self):
        self.assertEqual(q.sections_with_items([{"kind": "x", "items": []}]), [])

    def test_app_asset_is_up_to_date(self):
        on_disk = json.loads(q.OUT.read_text(encoding="utf-8"))
        self.assertEqual(on_disk, self.data, "python build_quality_data.py 를 다시 실행해야 한다")


if __name__ == "__main__":
    unittest.main()
