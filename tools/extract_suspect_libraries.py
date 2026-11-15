"""도서관 군집 결과(저장소 밖 원본) → 입력 오류 의심 도서관 목록(tools/source/suspect_libraries.csv).

원본은 도서관 한 곳이 한 행이고 주소·전화번호까지 들어 있다. 경고 목록에 필요한 열만 남긴다.
실행: python extract_suspect_libraries.py <01_비지도학습_도서관_군집결과.csv 경로>
"""
import csv
import sys
from pathlib import Path

SUSPECT_CLUSTER = "2"  # K-Means 군집 중 '입력 오류 의심' 유형의 번호
COLUMNS = ["시도명", "시군구명", "도서관명", "도서관유형", "대출가능권수"]
OUT = Path(__file__).parent / "source" / "suspect_libraries.csv"


def main(raw_path):
    with open(raw_path, encoding="utf-8-sig", newline="") as f:
        rows = [{c: row[c] for c in COLUMNS} for row in csv.DictReader(f) if row["군집"] == SUSPECT_CLUSTER]
    with open(OUT, "w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, COLUMNS)
        writer.writeheader()
        writer.writerows(rows)
    print(f"{OUT.name}: {len(rows)} libraries")


if __name__ == "__main__":
    main(sys.argv[1])
