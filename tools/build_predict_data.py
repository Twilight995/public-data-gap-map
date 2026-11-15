"""2문항 답 조합별 인원수(tools/source) → 앱용 등급 예측 표(app/assets/data/predict.json).

예측 규칙: 같은 답을 한 등록자 중 가장 많았던 등급. 판정 규칙은 이 파일에만 둔다.
성별·출생연대를 더해도 정확도가 같아서 2문항만 쓴다(시험용 20%로 잰 값이 둘 다 77.36%).
이 파일이 내는 정확도 77.2%는 등록자 전체로 잰 값이다.

원본 집계는 국가금연지원서비스 니코틴의존도(2024) 239,386명의 6문항 합계를
낮음(0~3)·중간(4~6)·높음(7~10)으로 나눈 뒤 (문항1, 문항4, 등급)별로 센 것이다.
실행: python build_predict_data.py
"""
import csv
import json
from pathlib import Path

HERE = Path(__file__).parent
SOURCE = HERE / "source" / "nicotine_answer_counts.csv"
OUT = HERE.parent / "app" / "assets" / "data" / "predict.json"

LEVELS = [  # 낮은 등급부터
    {"id": "low", "label": "낮음", "range": "0~3점",
     "advice": "보건소 금연클리닉 상담으로 시작해 볼 수 있습니다."},
    {"id": "mid", "label": "중간", "range": "4~6점",
     "advice": "금연클리닉 상담과 니코틴 보조제를 함께 쓰는 방법을 권합니다. 정식 6문항 검사를 받아 보세요."},
    {"id": "high", "label": "높음", "range": "7~10점",
     "advice": "단기금연캠프나 전문치료형 프로그램, 병원 금연치료를 권합니다."},
]
LEVEL_IDS = [lv["id"] for lv in LEVELS]

QUESTIONS = [
    {"id": "q1", "text": "아침에 일어나서 얼마 만에 첫 담배를 피우십니까?", "options": [
        # 설문지와 같은 순서(빠른 시간부터). 점수는 빠를수록 높다.
        {"score": 3, "label": "5분 이내"}, {"score": 2, "label": "6~30분"},
        {"score": 1, "label": "31분~1시간"}, {"score": 0, "label": "1시간 이후"}]},
    {"id": "q4", "text": "하루에 보통 몇 개비나 피우십니까?", "options": [
        {"score": 0, "label": "10개비 이하"}, {"score": 1, "label": "11~20개비"},
        {"score": 2, "label": "21~30개비"}, {"score": 3, "label": "31개비 이상"}]},
]


def predict_cell(counts):
    """등급별 인원수 → 예측 등급과 비율. 인원이 같으면 더 높은 등급으로 본다."""
    n = sum(counts.values())
    if n == 0:
        raise ValueError("응답자가 없는 답 조합은 예측할 수 없다")
    level = max(LEVEL_IDS, key=lambda lv: (counts[lv], LEVEL_IDS.index(lv)))
    return {"level": level, "n": n, "pct": {lv: round(counts[lv] / n * 100, 1) for lv in LEVEL_IDS}}


def build_predict():
    counts = {}
    with open(SOURCE, encoding="utf-8-sig", newline="") as f:
        for row in csv.DictReader(f):
            cell = counts.setdefault((int(row["문항1"]), int(row["문항4"])), dict.fromkeys(LEVEL_IDS, 0))
            cell[row["등급"]] += int(row["인원"])

    cells = [{"q1": q1, "q4": q4, **predict_cell(c)} for (q1, q4), c in sorted(counts.items())]
    total = sum(c["n"] for c in cells)
    correct = sum(counts[(c["q1"], c["q4"])][c["level"]] for c in cells)
    high_total = sum(c["high"] for c in counts.values())
    high_found = sum(counts[(c["q1"], c["q4"])]["high"] for c in cells if c["level"] == "high")
    high_as_mid = sum(counts[(c["q1"], c["q4"])]["high"] for c in cells if c["level"] == "mid")
    if high_found + high_as_mid != high_total:  # 화면 문구가 "나머지는 중간으로 예측"이라고 말하기 때문
        raise ValueError("실제 '높음'이 '낮음'으로 예측되는 칸이 있다. 화면의 한계 안내 문구를 고쳐야 한다")
    return {
        "source": "공공데이터포털 국가금연지원서비스 니코틴의존도(2024) 등록자",
        "total": total,
        "accuracyPct": round(correct / total * 100, 1),
        "highRecallPct": round(high_found / high_total * 100, 1),
        "highAsMidPct": round(high_as_mid / high_total * 100, 1),
        "questions": QUESTIONS,
        "levels": LEVELS,
        "cells": cells,
    }


def main():
    data = build_predict()
    OUT.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"predict.json: {len(data['cells'])} cells, accuracy {data['accuracyPct']}%, "
          f"high recall {data['highRecallPct']}%")


if __name__ == "__main__":
    main()
