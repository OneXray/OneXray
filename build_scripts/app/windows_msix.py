import os
import re
import shutil
import tempfile
import xml.etree.ElementTree as ET
from glob import glob

from app.command_line import run_command

_FOUNDATION = "http://schemas.microsoft.com/appx/manifest/foundation/windows10"
_UAP = "http://schemas.microsoft.com/appx/manifest/uap/windows10"
_UAP10 = "http://schemas.microsoft.com/appx/manifest/uap/windows10/10"
_DESKTOP = "http://schemas.microsoft.com/appx/manifest/desktop/windows10"
_RESCAP = (
    "http://schemas.microsoft.com/appx/manifest/foundation/windows10/"
    "restrictedcapabilities"
)

for prefix, namespace in (
    ("", _FOUNDATION),
    ("uap", _UAP),
    ("uap10", _UAP10),
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

    ignorable = [
        prefix
        for prefix in package.get("IgnorableNamespaces", "").split()
        if prefix in {"uap", "uap10", "desktop", "rescap"}
    ]
    if "uap10" not in ignorable:
        ignorable.append("uap10")
    package.set("IgnorableNamespaces", " ".join(ignorable))

    if local_development:
        if not development_publisher:
            raise ValueError("ONEXRAY_DEV_PUBLISHER is required")
        identity.set("Name", "OneXray.Dev")
        identity.set("Publisher", development_publisher)

    application_items = applications.findall(_tag(_FOUNDATION, "Application"))
    if len(application_items) != 1:
        raise ValueError("generated MSIX manifest must contain exactly one Application")
    application = application_items[0]

    vcore_executables = {
        "vcore-windows-session-host.exe",
        "vcore-windows-vpn-host.exe",
    }
    extension_tags = {
        _tag(_FOUNDATION, "Extension"),
        _tag(_DESKTOP, "Extension"),
    }
    if (
        any(
            element.tag in extension_tags
            and (
                element.get("Executable") in vcore_executables
                or element.get("EntryPoint") == "VCore.VpnBackgroundTask"
            )
            for element in package.iter()
        )
        or package.find(
            f".//{_tag(_FOUNDATION, 'ActivatableClass')}"
            "[@ActivatableClassId='VCore.VpnBackgroundTask']"
        )
        is not None
    ):
        raise ValueError("generated MSIX manifest already contains VCore extensions")

    application_extensions = application.find(_tag(_FOUNDATION, "Extensions"))
    if application_extensions is None:
        application_extensions = ET.SubElement(
            application,
            _tag(_FOUNDATION, "Extensions"),
        )
    session = ET.SubElement(
        application_extensions,
        _tag(_DESKTOP, "Extension"),
        {
            "Category": "windows.fullTrustProcess",
            "Executable": "vcore-windows-session-host.exe",
        },
    )
    ET.SubElement(session, _tag(_DESKTOP, "FullTrustProcess"))

    background = ET.SubElement(
        application_extensions,
        _tag(_FOUNDATION, "Extension"),
        {
            "Category": "windows.backgroundTasks",
            "Executable": "vcore-windows-vpn-host.exe",
            "EntryPoint": "VCore.VpnBackgroundTask",
            _tag(_UAP10, "RuntimeBehavior"): "windowsApp",
            _tag(_UAP10, "TrustLevel"): "appContainer",
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
        if element.tag
        in {
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
    certificate_thumbprint: str | None = None,
    certificate_path: str | None = None,
    certificate_password: str | None = None,
    development_publisher: str | None = None,
) -> None:
    if local_development:
        if not development_publisher:
            raise ValueError("ONEXRAY_DEV_PUBLISHER is required")
        if certificate_thumbprint:
            certificate_thumbprint = re.sub(r"\s", "", certificate_thumbprint).upper()
            if not re.fullmatch(r"[0-9A-F]{40}", certificate_thumbprint):
                raise ValueError(
                    "ONEXRAY_DEV_CERT_THUMBPRINT must contain exactly "
                    "40 hexadecimal characters"
                )
        elif (
            not certificate_path
            or not os.path.isfile(certificate_path)
            or not certificate_password
        ):
            raise ValueError(
                "ONEXRAY_DEV_CERT_THUMBPRINT or ONEXRAY_DEV_CERT_PATH and "
                "ONEXRAY_DEV_CERT_PASSWORD are required"
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
        sign_command = [signtool, "sign", "/fd", "SHA256"]
        if certificate_thumbprint:
            sign_command.extend(["/sha1", certificate_thumbprint, "/s", "My", package])
        else:
            sign_command.extend(
                ["/f", certificate_path, "/p", certificate_password, package]
            )
        run_command(sign_command, redact=True)
        run_command([signtool, "verify", "/pa", package])


def _sdk_tool(name: str) -> str:
    if command := shutil.which(name):
        return command
    program_files = os.environ.get("PROGRAMFILES(X86)")
    if not program_files:
        raise FileNotFoundError(f"{name} was not found")
    matches = sorted(
        glob(
            os.path.join(program_files, "Windows Kits", "10", "bin", "*", "x64", name)
        ),
        reverse=True,
    )
    if not matches:
        raise FileNotFoundError(f"{name} was not found")
    return matches[0]
