"""Regression tests for release documentation drift."""
import unittest

from check_project import validate_release_metadata, validate_documented_toolchain


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



class ToolchainDocumentationTests(unittest.TestCase):
    workflow = "env:\n  MOONBIT_INSTALL_VERSION: 0.10.22+124d61d05\n"
    documents = {
        "README.md": "moonc 0.10.22+124d61d05",
        "docs/validation.md": "moonc 0.10.22+124d61d05",
    }

    def test_consistent_toolchain(self):
        validate_documented_toolchain(self.workflow, self.documents)

    def test_stale_validation_document(self):
        documents = dict(self.documents, **{"docs/validation.md": "moonc 0.10.15+943464bfa"})
        with self.assertRaisesRegex(AssertionError, "differs from CI"):
            validate_documented_toolchain(self.workflow, documents)

    def test_stale_readme(self):
        documents = dict(self.documents, **{"README.md": "moonc 0.10.19+2edd3f5fa"})
        with self.assertRaisesRegex(AssertionError, "differs from CI"):
            validate_documented_toolchain(self.workflow, documents)

    def test_mixed_old_and_current_versions(self):
        documents = dict(self.documents, **{"docs/validation.md": "moonc 0.10.22+124d61d05; 0.10.15+943464bfa"})
        with self.assertRaisesRegex(AssertionError, "differs from CI"):
            validate_documented_toolchain(self.workflow, documents)

    def test_missing_documented_version(self):
        with self.assertRaisesRegex(AssertionError, "missing documented compiler"):
            validate_documented_toolchain(self.workflow, {"README.md": "MoonBit"})

    def test_missing_or_duplicate_ci_pin(self):
        for workflow in ["env: {}", self.workflow + self.workflow]:
            with self.subTest(workflow=workflow):
                with self.assertRaisesRegex(AssertionError, "one MoonBit compiler pin"):
                    validate_documented_toolchain(workflow, self.documents)

    def test_invalid_ci_pin(self):
        with self.assertRaisesRegex(AssertionError, "invalid CI compiler pin"):
            validate_documented_toolchain(self.workflow.replace("0.10.22+124d61d05", "latest"), self.documents)


if __name__ == "__main__":
    unittest.main()
