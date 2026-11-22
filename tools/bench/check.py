"""Check benchmark files with pyarrow against an independent copy of the generator.

ZPARQ2A_CL_BENCHMARK generates its rows from a seed. ROWS() below makes the
same rows in Python, and the script compares them with what pyarrow reads from
a file the benchmark wrote (tools/run-bench.mjs keeps the file of each
toolchain's last run).

Usage (from the repository root):
  tools/.venv/Scripts/python tools/bench/check.py FILE ROWS SEED      (Windows)
  tools/.venv/bin/python tools/bench/check.py FILE ROWS SEED          (Linux, macOS)

Prints OK, or the first row and column that differ.
Exit code: 0 when every value matches, 1 otherwise.
"""

import datetime
import decimal
import sys

import pyarrow as pa
import pyarrow.parquet as pq

SCHEMA = [
    ("id", pa.int32()),
    ("quantity", pa.int64()),
    ("price", pa.decimal128(15, 2)),
    ("ratio", pa.float64()),
    ("flag", pa.bool_()),
    ("name", pa.string()),
    ("day", pa.date32()),
    ("note", pa.string()),
]


def rows(count, seed):
    """The rows of ZPARQ2A_CL_BENCHMARK->ROWS( count ) for a new instance with SEED."""
    state = abs(seed) % 2147483646 + 1

    def next_value():
        nonlocal state
        state = state * 16807 % 2147483647
        return state

    epoch = datetime.date(1970, 1, 1)
    result = []
    for index in range(1, count + 1):
        row = {"id": index}
        row["quantity"] = next_value() * 4096
        row["price"] = decimal.Decimal(next_value() % 100000000) / 100
        row["ratio"] = next_value() / 2147483647
        row["flag"] = next_value() % 2 == 0
        row["name"] = f"item {next_value() % 1000}"
        row["day"] = epoch + datetime.timedelta(days=next_value() % 25000)
        row["note"] = None if index % 4 == 0 else f"note {index}"
        result.append(row)
    return result


def check(path, count, seed):
    table = pq.read_table(path)
    for name, kind in SCHEMA:
        field = table.schema.field(name)
        if field.type != kind:
            return f"column {name}: type {field.type}, expected {kind}"
    if table.num_rows != count:
        return f"{table.num_rows} rows, expected {count}"
    actual = table.to_pylist()
    for expected_row, actual_row in zip(rows(count, seed), actual):
        for name, _ in SCHEMA:
            if actual_row[name] != expected_row[name]:
                return f"row {expected_row['id']}, column {name}: {actual_row[name]!r}, expected {expected_row[name]!r}"
    return None


def main(argv):
    if len(argv) != 4:
        print(__doc__)
        return 2
    problem = check(argv[1], int(argv[2]), int(argv[3]))
    print(problem or "OK")
    return 1 if problem else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
