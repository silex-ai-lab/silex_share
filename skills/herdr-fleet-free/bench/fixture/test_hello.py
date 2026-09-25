import unittest

from hello import greet


class GreetTest(unittest.TestCase):
    def test_default(self):
        self.assertEqual(greet(), "Hello, World!")

    def test_padded_name(self):
        self.assertEqual(greet("  Alice  "), "Hello, Alice!")

    def check_blank_name(self):
        self.assertEqual(greet("   "), "Hello, World!")


if __name__ == "__main__":
    unittest.main()
