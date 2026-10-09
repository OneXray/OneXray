import os
import shutil
import tempfile
import xml.etree.ElementTree as ET
from glob import glob

from app.command_line import run_command

_FOUNDATION = "http://schemas.microsoft.com/appx/manifest/foundation/windows10"
_UAP = "http://schemas.microsoft.com/appx/manifest/uap/windows10"
_UAP10 = "http://schemas.microsoft.com/appx/manifest/uap/windows10/10"
_DESKTOP = "http://schemas.microsoft.com/appx/manifest/desktop/windows10"
_RESCAP = "http://schemas.microsoft.com/appx/manifest/foundation/windows10/restrictedcapabilities"

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
    development_publisher: str | None = None,
) -> None:
    tree = ET.parse(path)
    package = tree.getroot()
    identity = package.find(_tag(_FOUNDATION, "Identity"))
    applications = package.find(_tag(_FOUNDATION, "Applications"))
    if identity is None or applications is None:
        raise ValueError("generated MSIX manifest is incomplete")

    ignorable = [
        prefix
        for prefix in package.get("IgnorableNamespaces", "").split()
        if prefix in {"uap", "uap10", "desktop", "rescap"}
    ]
    if "uap10" not in ignorable:
        ignorable.append("uap10")
    package.set("IgnorableNamespaces", " ".join(ignorable))

    if development_publisher:
        identity.set("Name", "OneXray.Dev")
        identity.set("Publisher", development_publisher)

    application_items = applications.findall(_tag(_FOUNDATION, "Application"))
    if len(application_items) != 1:
        raise ValueError("generated MSIX manifest must contain exactly one Application")
    application = application_items[0]

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
            "Executable": "vole-windows-session-host.exe",
        },
    )
    ET.SubElement(session, _tag(_DESKTOP, "FullTrustProcess"))

    background = ET.SubElement(
        application_extensions,
        _tag(_FOUNDATION, "Extension"),
        {
            "Category": "windows.backgroundTasks",
            "Executable": "vole-windows-vpn-host.exe",
            "EntryPoint": "Vole.VpnBackgroundTask",
            _tag(_UAP10, "RuntimeBehavior"): "windowsApp",
            _tag(_UAP10, "TrustLevel"): "appContainer",
        },
    )
    tasks = ET.SubElement(background, _tag(_FOUNDATION, "BackgroundTasks"))
    ET.SubElement(tasks, _tag(_UAP, "Task"), {"Type": "vpnClient"})

    package_extensions = package.find(_tag(_FOUNDATION, "Extensions"))
    if package_extensions is None:
        package_extensions = ET.SubElement(package, _tag(_FOUNDATION, "Extensions"))
    activation = ET.SubElement(
        package_extensions,
        _tag(_FOUNDATION, "Extension"),
        {"Category": "windows.activatableClass.inProcessServer"},
    )
    server = ET.SubElement(activation, _tag(_FOUNDATION, "InProcessServer"))
    ET.SubElement(server, _tag(_FOUNDATION, "Path")).text = "vole.dll"
    ET.SubElement(
        server,
        _tag(_FOUNDATION, "ActivatableClass"),
        {
            "ActivatableClassId": "Vole.VpnBackgroundTask",
            "ThreadingModel": "both",
        },
    )

    temporary = f"{path}.tmp"
    tree.write(temporary, encoding="utf-8", xml_declaration=True)
    os.replace(temporary, path)


def pack_msix(stage: str, package: str, *, local_development: bool = False) -> None:
    """Pack once; publish the output only after packaging/signing succeeds."""
    publisher = os.environ.get("ONEXRAY_DEV_PUBLISHER")
    thumbprint = "".join(os.environ.get("ONEXRAY_DEV_CERT_THUMBPRINT", "").split())
    if local_development and (not publisher or not thumbprint):
        raise ValueError("ONEXRAY_DEV_PUBLISHER and ONEXRAY_DEV_CERT_THUMBPRINT are required")
    augment_manifest(
        os.path.join(stage, "AppxManifest.xml"),
        development_publisher=publisher if local_development else None,
    )
    # Use the output volume so replacing a prior package is atomic.
    with tempfile.TemporaryDirectory(
        prefix="onexray-msix-", dir=os.path.dirname(package)
    ) as temporary:
        built = os.path.join(temporary, "OneXray.msix")
        run_command([_sdk_tool("makeappx.exe"), "pack", "/d", stage, "/p", built, "/o"])
        if local_development:
            signtool = _sdk_tool("signtool.exe")
            run_command([signtool, "sign", "/fd", "SHA256", "/sha1", thumbprint, "/s", "My", built])
        os.replace(built, package)


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
