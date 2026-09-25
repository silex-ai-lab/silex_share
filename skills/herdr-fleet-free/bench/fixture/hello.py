import sys


def greet(name=None):
    if not name:
        return "Hello, World!"
    return f"Hello, {name.strip()}!"


def main(argv=None):
    argv = argv or sys.argv[1:]
    name = " ".join(argv)
    print(greet(name), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
