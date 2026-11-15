"""build_predict_data.py 테스트. 실행: python -m unittest (tools 폴더에서)"""
import json
import unittest

import build_predict_data as p


class PredictCellTest(unittest.TestCase):
    def test_most_common_level_wins(self):
        cell = p.predict_cell({"low": 10, "mid": 70, "high": 20})
        self.assertEqual(cell["level"], "mid")
        self.assertEqual(cell["n"], 100)
        self.assertEqual(cell["pct"], {"low": 10.0, "mid": 70.0, "high": 20.0})

    def test_tie_goes_to_the_higher_level(self):
        # 같은 수면 더 높은 등급으로 본다. 높은 의존도를 놓치는 쪽이 더 위험하기 때문.
        self.assertEqual(p.predict_cell({"low": 50, "mid": 50, "high": 0})["level"], "mid")

    def test_no_respondents_is_rejected(self):
        with self.assertRaises(ValueError):
            p.predict_cell({"low": 0, "mid": 0, "high": 0})


class BuildTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = p.build_predict()
        cls.cells = {(c["q1"], c["q4"]): c for c in cls.data["cells"]}

    def test_every_answer_pair_has_a_cell(self):
        self.assertEqual(set(self.cells), {(a, b) for a in range(4) for b in range(4)})

    def test_predicted_table(self):
        L, M, H = "low", "mid", "high"
        expected = [  # 행: 문항1 점수 0~3, 열: 문항4 점수 0~3
            [L, L, L, M],
            [L, L, M, M],
            [L, M, M, H],
            [M, M, H, H],
        ]
        actual = [[self.cells[(a, b)]["level"] for b in range(4)] for a in range(4)]
        self.assertEqual(actual, expected)

    def test_counts_and_percentages_are_consistent(self):
        self.assertEqual(sum(c["n"] for c in self.cells.values()), self.data["total"])
        self.assertEqual(self.data["total"], 239386)
        for c in self.cells.values():
            self.assertAlmostEqual(sum(c["pct"].values()), 100, delta=0.2)

    def test_accuracy_is_reported_honestly(self):
        # 등록자 전체로 잰 값 (시험용 20%로 쟀을 때는 77.4% / 53.5%였다)
        self.assertEqual(self.data["accuracyPct"], 77.2)
        self.assertEqual(self.data["highRecallPct"], 53.8)  # '높음'의 절반만 찾는다

    def test_missed_high_is_always_predicted_mid(self):
        # 화면 문구("나머지는 '중간'으로 예측")가 참이려면 '높음'을 '낮음'으로 본 경우가 없어야 한다.
        self.assertEqual(self.data["highAsMidPct"], 46.2)
        self.assertAlmostEqual(self.data["highRecallPct"] + self.data["highAsMidPct"], 100, delta=0.05)

    def test_question_wording_and_scores_follow_the_standard_test(self):
        # 표준 니코틴의존도 검사(FTND) 1번·4번 문항. 보기는 설문지에 나오는 순서대로.
        options = [[(o["label"], o["score"]) for o in q["options"]] for q in self.data["questions"]]
        self.assertEqual(options[0], [("5분 이내", 3), ("6~30분", 2), ("31분~1시간", 1), ("1시간 이후", 0)])
        self.assertEqual(options[1], [("10개비 이하", 0), ("11~20개비", 1), ("21~30개비", 2), ("31개비 이상", 3)])

    def test_questions_and_levels_are_complete(self):
        self.assertEqual([q["id"] for q in self.data["questions"]], ["q1", "q4"])
        self.assertEqual([lv["id"] for lv in self.data["levels"]], ["low", "mid", "high"])
        for lv in self.data["levels"]:
            self.assertTrue(lv["label"] and lv["range"] and lv["advice"])

    def test_app_asset_is_up_to_date(self):
        on_disk = json.loads(p.OUT.read_text(encoding="utf-8"))
        self.assertEqual(on_disk, self.data, "python build_predict_data.py 를 다시 실행해야 한다")


if __name__ == "__main__":
    unittest.main()
