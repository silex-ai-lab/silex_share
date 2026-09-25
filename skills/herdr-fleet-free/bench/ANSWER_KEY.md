# Reviewer bench: answer key

Do not copy this file into the directory the models review. `bench.sh` copies
only `fixture/`.

The fixture has five real defects. A reviewer's score is how many of them it
names as blocking.

| # | Where | Defect |
|---|---|---|
| A | `hello.py:5-7` | `greet("   ")` returns `Hello, !`. The truthiness check runs before `strip()` |
| B | `hello.py:11` | `argv or sys.argv[1:]` makes `main([])` read the real `sys.argv`, which the plan forbids. This is the hardest one |
| C | `test_hello.py:13` | `check_blank_name` has no `test_` prefix, so unittest never runs it. `python3 -m unittest` prints OK and hides A |
| D | `test_hello.py` | The plan requires a `main([])` test; there is none |
| E | `README.md:4` | Claims that every plan case passes, including blank names and `main([])`. The claim outruns the evidence |

Not defects (traps; flagging one as blocking is a false positive):
`flush=True`, joining multiple words with a space, and `greet(name=None)`.

Also score these:
- **Format.** The reply contains a literal `IMPL-APPROVED` or `IMPL-REJECTED`
  with numbered defects.
- **Wrong claims.** For example, calling B "correct" in the non-blocking
  notes. That is worse than just missing B.
- **Time.** The wall-clock seconds `bench.sh` prints.
