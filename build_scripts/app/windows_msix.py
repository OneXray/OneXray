import os
import shutil
import tempfile
import xml.etree.ElementTree as ET
from glob import glob

from app.command_line import run_command

_FOUNDATION = "http://schemas.microsoft.com/appx/manifest/foundation/windows10"
_UAP = "http://schemas.microsoft.com/appx/manifest/uap/windows10"
_DESKTOP = "http://schemas.microsoft.com/appx/manifest/desktop/windows10"
_RESCAP = (
    "http://schemas.microsoft.com/appx/manifest/foundation/windows10/"
    "restrictedcapabilities"
)

for prefix, namespace in (
    ("", _FOUNDATION),
    ("uap", _UAP),
    ("desktop", _DESKTOP),
    ("rescap", _RESCAP),
):
    ET.register_namespace(prefix, namespace)


def _tag(namespace: str, name: str) -> str:
    return f"{{{namespace}}}{name}"


def augment_manifest(
    path: str,
    *,
    local_development: bool = False,
    development_publisher: str | None = None,
) -> None:
    tree = ET.parse(path)
    package = tree.getroot()
    identity = package.find(_tag(_FOUNDATION, "Identity"))
    applications = package.find(_tag(_FOUNDATION, "Applications"))
    capabilities = package.find(_tag(_FOUNDATION, "Capabilities"))
    if identity is None or applications is None or capabilities is None:
        raise ValueError("generated MSIX manifest is incomplete")

    package.set("IgnorableNamespaces", "uap desktop rescap")

    if local_development:
        if not development_publisher:
            raise ValueError("ONEXRAY_DEV_PUBLISHER is required")
        identity.set("Name", "OneXray.Dev")
        identity.set("Publisher", development_publisher)

    application_ids = {
        app.get("Id") for app in applications.findall(_tag(_FOUNDATION, "Application"))
    }
    if application_ids.intersection({"SessionHost", "VpnProvider"}):
        raise ValueError("generated MSIX manifest already contains VCore applications")

    visual_attributes = {
        "Square150x150Logo": r"Images\Square150x150Logo.png",
        "Square44x44Logo": r"Images\Square44x44Logo.png",
        "BackgroundColor": "transparent",
        "AppListEntry": "none",
    }
    session = ET.SubElement(
        applications,
        _tag(_FOUNDATION, "Application"),
        {
            "Id": "SessionHost",
            "Executable": "vcore-windows-session-host.exe",
            "EntryPoint": "Windows.FullTrustApplication",
        },
    )
    ET.SubElement(
        session,
        _tag(_UAP, "VisualElements"),
        {
            **visual_attributes,
            "DisplayName": "OneXray VPN Session Host",
            "Description": "OneXray VPN session host",
        },
    )

    provider = ET.SubElement(
        applications,
        _tag(_FOUNDATION, "Application"),
        {
            "Id": "VpnProvider",
            "Executable": "vcore-windows-vpn-host.exe",
            "EntryPoint": "VCore.VpnHost.App",
        },
    )
    ET.SubElement(
        provider,
        _tag(_UAP, "VisualElements"),
        {
            **visual_attributes,
            "DisplayName": "OneXray VPN Provider",
            "Description": "OneXray VPN provider",
        },
    )
    provider_extensions = ET.SubElement(provider, _tag(_FOUNDATION, "Extensions"))
    background = ET.SubElement(
        provider_extensions,
        _tag(_FOUNDATION, "Extension"),
        {
            "Category": "windows.backgroundTasks",
            "Executable": "vcore-windows-vpn-host.exe",
            "EntryPoint": "VCore.VpnBackgroundTask",
        },
    )
    tasks = ET.SubElement(background, _tag(_FOUNDATION, "BackgroundTasks"))
    ET.SubElement(tasks, _tag(_UAP, "Task"), {"Type": "vpnClient"})

    package_extensions = next(
        (
            element
            for element in package.findall(_tag(_FOUNDATION, "Extensions"))
            if element.get("Category") is None
        ),
        None,
    )
    if package_extensions is None:
        package_extensions = ET.SubElement(package, _tag(_FOUNDATION, "Extensions"))
    activation = ET.SubElement(
        package_extensions,
        _tag(_FOUNDATION, "Extension"),
        {"Category": "windows.activatableClass.inProcessServer"},
    )
    server = ET.SubElement(activation, _tag(_FOUNDATION, "InProcessServer"))
    ET.SubElement(server, _tag(_FOUNDATION, "Path")).text = "vcore.dll"
    ET.SubElement(
        server,
        _tag(_FOUNDATION, "ActivatableClass"),
        {
            "ActivatableClassId": "VCore.VpnBackgroundTask",
            "ThreadingModel": "both",
        },
    )

    startup_tasks = package.findall(
        f".//{_tag(_DESKTOP, 'StartupTask')}[@TaskId='VCoreStartup']"
    )
    capability_names = {
        element.get("Name")
        for element in capabilities
        if element.tag in {
            _tag(_FOUNDATION, "Capability"),
            _tag(_RESCAP, "Capability"),
        }
    }
    if len(startup_tasks) != 1 or startup_tasks[0].get("Enabled") != "false":
        raise ValueError("generated MSIX manifest has no disabled VCoreStartup task")
    if not {
        "internetClientServer",
        "privateNetworkClientServer",
        "runFullTrust",
        "networkingVpnProvider",
    }.issubset(capability_names):
        raise ValueError("generated MSIX manifest is missing VCore capabilities")

    temporary = f"{path}.tmp"
    tree.write(temporary, encoding="utf-8", xml_declaration=True)
    os.replace(temporary, path)


def package_with_vcore(
    package: str,
    *,
    local_development: bool = False,
    certificate_path: str | None = None,
    certificate_password: str | None = None,
    development_publisher: str | None = None,
) -> None:
    if local_development and (
        not certificate_path
        or not os.path.isfile(certificate_path)
        or not certificate_password
        or not development_publisher
    ):
        raise ValueError(
            "ONEXRAY_DEV_CERT_PATH, ONEXRAY_DEV_CERT_PASSWORD, and "
            "ONEXRAY_DEV_PUBLISHER are required"
        )
    makeappx = _sdk_tool("makeappx.exe")
    with tempfile.TemporaryDirectory(prefix="onexray-msix-") as temporary:
        stage = os.path.join(temporary, "stage")
        rebuilt = os.path.join(temporary, "OneXray.msix")
        run_command([makeappx, "unpack", "/p", package, "/d", stage, "/o"])
        for required in (
            "vcore.dll",
            "vcore-windows-vpn-host.exe",
            "vcore-windows-session-host.exe",
        ):
            if not os.path.isfile(os.path.join(stage, required)):
                raise FileNotFoundError(f"MSIX payload is missing {required}")
        augment_manifest(
            os.path.join(stage, "AppxManifest.xml"),
            local_development=local_development,
            development_publisher=development_publisher,
        )
        run_command([makeappx, "pack", "/d", stage, "/p", rebuilt, "/o"])
        shutil.move(rebuilt, package)

    if local_development:
        signtool = _sdk_tool("signtool.exe")
        run_command(
            [
                signtool,
                "sign",
                "/fd",
                "SHA256",
                "/f",
                certificate_path,
                "/p",
                certificate_password,
                package,
            ],
            redact=True,
        )
        run_command([signtool, "verify", "/pa", package])


def _sdk_tool(name: str) -> str:
    if command := shutil.which(name):
        return command
    program_files = os.environ.get("PROGRAMFILES(X86)")
    if not program_files:
        raise FileNotFoundError(f"{name} was not found")
    matches = sorted(
        glob(os.path.join(program_files, "Windows Kits", "10", "bin", "*", "x64", name)),
        reverse=True,
    )
    if not matches:
        raise FileNotFoundError(f"{name} was not found")
    return matches[0]
