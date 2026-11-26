"""Regression tests for release documentation drift."""
import unittest

from check_project import validate_release_metadata


class ReleaseMetadataTests(unittest.TestCase):
    manifest = 'name = "owner/project"\nversion = "0.1.3"\n'
    readme = '`owner/project@0.1.3`\nmoon add owner/project@0.1.3\n'
    changelog = '## 0.1.3 - 2026-11-26\n\n## 0.1.2 - 2026-11-25\n'

    def test_consistent_release(self):
        validate_release_metadata(self.manifest, self.readme, self.changelog)

    def test_stale_install_command(self):
        with self.assertRaisesRegex(AssertionError, "README version mismatch"):
            validate_release_metadata(self.manifest, self.readme.replace("moon add owner/project@0.1.3", "moon add owner/project@0.1.1"), self.changelog)

    def test_stale_module_description(self):
        with self.assertRaisesRegex(AssertionError, "README version mismatch"):
            validate_release_metadata(self.manifest, self.readme.replace("`owner/project@0.1.3`", "`owner/project@0.1.1`"), self.changelog)

    def test_stale_changelog(self):
        with self.assertRaisesRegex(AssertionError, "CHANGELOG"):
            validate_release_metadata(self.manifest, self.readme, self.changelog.replace("0.1.3", "0.1.2"))

    def test_missing_install_command(self):
        with self.assertRaisesRegex(AssertionError, "installation command"):
            validate_release_metadata(self.manifest, self.readme.replace("moon add", "install"), self.changelog)


if __name__ == "__main__":
    unittest.main()
