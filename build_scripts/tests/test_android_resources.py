import unittest
from pathlib import Path
from xml.etree import ElementTree


class AndroidNetworkPolicyTest(unittest.TestCase):
    def test_metrics_cleartext_exception_is_limited_to_exact_loopback(self):
        android = Path(__file__).resolve().parents[2] / "android"
        namespace = "{http://schemas.android.com/apk/res/android}"
        manifest = ElementTree.parse(android / "app/src/main/AndroidManifest.xml")
        application = manifest.getroot().find("application")
        self.assertIsNotNone(application)
        self.assertNotEqual(application.get(namespace + "usesCleartextTraffic"), "true")
        resource = application.get(namespace + "networkSecurityConfig")
        self.assertEqual(resource, "@xml/network_security_config")

        policy = ElementTree.parse(
            android / "app/src/main/res/xml/network_security_config.xml"
        ).getroot()
        self.assertIsNone(policy.find("base-config"))
        exceptions = policy.findall("domain-config")
        self.assertEqual(len(exceptions), 1)
        self.assertEqual(exceptions[0].get("cleartextTrafficPermitted"), "true")
        domains = exceptions[0].findall("domain")
        self.assertEqual(
            [(domain.text, domain.get("includeSubdomains")) for domain in domains],
            [("127.0.0.1", "false")],
        )


if __name__ == "__main__":
    unittest.main()
