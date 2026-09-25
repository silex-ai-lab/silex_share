# Plan: hello.py v2
Spec:
- `python3 hello.py [NAME...]` prints `Hello, NAME!`. Multiple words are joined with one space.
- NAME is stripped of surrounding whitespace. If NAME is missing, empty, or whitespace-only, print `Hello, World!`.
- Exit status 0 in all cases.
- `main(argv)` takes an explicit argument list so tests can call it without touching the real sys.argv.
- Unit tests in test_hello.py, run with `python3 -m unittest`, cover: no name, a padded name, a whitespace-only name, and main([]) printing the default.
- README states what was tested. It must not claim more than the tests show.
