#!/usr/bin/env python3

from __future__ import annotations

import argparse
import hashlib
import json
import os
import pathlib
import shlex
import signal
import socket
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.request
from collections import deque
from dataclasses import dataclass


DEFAULT_HOST = "root@10.11.99.1"
DEFAULT_SCREEN_WIDTH = 1404
DEFAULT_SCREEN_HEIGHT = 1872
DEFAULT_STREAM_RATE_MS = 50
DEFAULT_STREAM_PORT_BASE = 23000
GOMARKABLESTREAM_RELEASE_API = "https://api.github.com/repos/owulveryck/goMarkableStream/releases/latest"
GOMARKABLESTREAM_ASSET_NAME = "gomarkablestream-RM2-lite"
REMOTE_INJECTOR_BASENAME = "remarkable-touch-injector"
REMOTE_STREAM_BASENAME = "gomarkablestream"
STATUS_POLL_MS = 350
STREAM_REFRESH_COOLDOWN_SECONDS = 0.75
USER_AGENT = "remarkable-sudoku-mirror/1.0"
BOOTSTRAP_ENV = "RM2_MIRROR_BOOTSTRAPPED"
MIN_WINDOW_WIDTH = 420
MIN_WINDOW_HEIGHT = 560
REPO_ROOT = pathlib.Path(__file__).resolve().parents[1]
VENV_DIR = REPO_ROOT / ".mirror-venv"
CACHE_DIR = REPO_ROOT / ".mirror-cache" / "goMarkableStream"


class MirrorError(RuntimeError):
    pass


def shell_quote(value: str) -> str:
    return shlex.quote(value)


def require_command(name: str) -> None:
    completed = subprocess.run(
        ["zsh", "-lc", f"command -v {shell_quote(name)} >/dev/null 2>&1"],
        check=False,
    )
    if completed.returncode != 0:
        raise MirrorError(f"missing required command: {name}")


def ssh_base_command(host: str) -> list[str]:
    return ["ssh", "-o", "ConnectTimeout=5", host]


def run_ssh(host: str, command: str, *, check: bool = True) -> subprocess.CompletedProcess[str]:
    completed = subprocess.run(
        [*ssh_base_command(host), command],
        check=False,
        capture_output=True,
        text=True,
    )
    if check and completed.returncode != 0:
        raise MirrorError(completed.stderr.strip() or completed.stdout.strip() or "ssh command failed")
    return completed


def run_scp(local_path: pathlib.Path, host: str, remote_path: str) -> None:
    completed = subprocess.run(
        ["scp", "-q", str(local_path), f"{host}:{remote_path}"],
        check=False,
        capture_output=True,
        text=True,
    )
    if completed.returncode != 0:
        raise MirrorError(completed.stderr.strip() or "failed to copy file to tablet")


def parse_host(host: str) -> tuple[str, str]:
    if "@" not in host:
        return ("root", host)
    username, hostname = host.split("@", 1)
    return (username, hostname)


def fetch_json(url: str) -> dict:
    request = urllib.request.Request(
        url,
        headers={
            "Accept": "application/vnd.github+json",
            "User-Agent": USER_AGENT,
        },
    )
    with urllib.request.urlopen(request, timeout=20) as response:
        return json.load(response)


def fetch_text(url: str) -> str:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=2) as response:
        return response.read().decode("utf-8", "replace").strip()


def ensure_host_environment() -> None:
    if os.environ.get(BOOTSTRAP_ENV) == "1":
        return

    venv_python = VENV_DIR / "bin/python"
    venv_pip = VENV_DIR / "bin/pip"

    if not venv_python.exists():
        subprocess.run([sys.executable, "-m", "venv", str(VENV_DIR)], check=True)

    probe = subprocess.run(
        [str(venv_python), "-c", "import PyQt5; from PyQt5.QtWebEngineWidgets import QWebEngineView"],
        check=False,
        capture_output=True,
        text=True,
    )
    if probe.returncode != 0:
        subprocess.run([str(venv_pip), "install", "--upgrade", "pip"], check=True)
        subprocess.run([str(venv_pip), "install", "PyQt5", "PyQtWebEngine"], check=True)

    environment = os.environ.copy()
    environment[BOOTSTRAP_ENV] = "1"
    os.execve(
        str(venv_python),
        [str(venv_python), str(pathlib.Path(__file__).resolve()), *sys.argv[1:]],
        environment,
    )


ensure_host_environment()


from PyQt5.QtCore import QCoreApplication, QObject, QRect, QTimer, Qt, QUrl, pyqtSignal  # noqa: E402


QCoreApplication.setAttribute(Qt.AA_ShareOpenGLContexts)


from PyQt5.QtGui import QMouseEvent  # noqa: E402
from PyQt5.QtWebEngineWidgets import QWebEnginePage, QWebEngineView  # noqa: E402
from PyQt5.QtWidgets import QApplication, QLabel, QStackedLayout, QVBoxLayout, QWidget  # noqa: E402


PAGE_CUSTOMIZATION_SCRIPT = """
(() => {
    const styleId = "codex-mirror-style";
    if (!document.getElementById(styleId)) {
        const style = document.createElement("style");
        style.id = styleId;
        style.textContent = `
            #menuContainer,
            #hamburgerMenu,
            #screenshotBtn,
            #onboardingHint,
            #fullscreenHint {
                display: none !important;
            }

            #container {
                position: fixed !important;
                inset: 0 !important;
            }

            #statusIndicator,
            #reconnectBanner,
            #message {
                z-index: 10 !important;
            }
        `;
        document.head.appendChild(style);
    }

    window.codexRestartStream = () => {
        if (typeof streamWorker === "undefined" || typeof initStreamWorker !== "function") {
            return false;
        }

        try {
            streamWorker.postMessage({ type: "terminate" });
        } catch (error) {
        }

        streamWorker = new Worker("worker_stream_processing.js");
        initStreamWorker();
        return true;
    };

    return true;
})();
"""


CANVAS_RECT_SCRIPT = """
(() => {
    const canvas = document.getElementById("canvas");
    if (!canvas) {
        return null;
    }

    const rect = canvas.getBoundingClientRect();
    return {
        left: rect.left,
        top: rect.top,
        width: rect.width,
        height: rect.height,
    };
})();
"""


@dataclass(frozen=True)
class ReleaseAsset:
    tag_name: str
    published_at: str
    asset_name: str
    download_url: str
    sha256: str | None

    @property
    def label(self) -> str:
        return f"goMarkableStream {self.tag_name}"


@dataclass(frozen=True)
class MirrorConfig:
    host: str
    injector_path: pathlib.Path
    gomarkablestream_path: pathlib.Path | None
    port: int
    rate_ms: int


@dataclass
class InjectorSession:
    process: subprocess.Popen[str]
    remote_path: str
    width: int
    height: int


@dataclass
class RemoteProcessSession:
    process: subprocess.Popen[str]
    remote_path: str
    port: int
    log_tail: "ProcessLogTail"
    label: str


class ProcessLogTail:
    def __init__(self, process: subprocess.Popen[str]) -> None:
        self._process = process
        self._lines: deque[str] = deque(maxlen=24)
        self._thread = threading.Thread(target=self._consume, daemon=True)
        self._thread.start()

    def _consume(self) -> None:
        if self._process.stdout is None:
            return

        for line in self._process.stdout:
            stripped = line.strip()
            if stripped:
                self._lines.append(stripped)

    def snapshot(self) -> str:
        return "\n".join(self._lines)


def parse_release_asset(payload: dict) -> ReleaseAsset:
    for asset in payload.get("assets", []):
        if asset.get("name") != GOMARKABLESTREAM_ASSET_NAME:
            continue

        digest = asset.get("digest") or ""
        sha256 = None
        if digest.startswith("sha256:"):
            sha256 = digest.split(":", 1)[1]

        return ReleaseAsset(
            tag_name=str(payload.get("tag_name", "")).strip(),
            published_at=str(payload.get("published_at", "")).strip(),
            asset_name=asset["name"],
            download_url=asset["browser_download_url"],
            sha256=sha256,
        )

    raise MirrorError(f"latest release is missing {GOMARKABLESTREAM_ASSET_NAME}")


def load_cached_release() -> ReleaseAsset | None:
    metadata_path = CACHE_DIR / "latest-release.json"
    if not metadata_path.is_file():
        return None

    try:
        return parse_release_asset(json.loads(metadata_path.read_text()))
    except Exception:
        return None


def resolve_release_asset() -> ReleaseAsset:
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    metadata_path = CACHE_DIR / "latest-release.json"

    try:
        payload = fetch_json(GOMARKABLESTREAM_RELEASE_API)
        metadata_path.write_text(json.dumps(payload, indent=2))
        return parse_release_asset(payload)
    except (MirrorError, OSError, urllib.error.URLError, urllib.error.HTTPError, TimeoutError) as error:
        cached = load_cached_release()
        if cached is not None:
            return cached
        raise MirrorError(f"failed to resolve the latest goMarkableStream release: {error}") from error


def sha256_file(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        while True:
            chunk = handle.read(1024 * 1024)
            if not chunk:
                break
            digest.update(chunk)
    return digest.hexdigest()


def download_file(url: str, destination: pathlib.Path) -> None:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=60) as response, destination.open("wb") as output:
        while True:
            chunk = response.read(1024 * 1024)
            if not chunk:
                break
            output.write(chunk)


def ensure_gomarkablestream_binary(local_override: pathlib.Path | None) -> tuple[pathlib.Path, str]:
    if local_override is not None:
        resolved = local_override.expanduser().resolve()
        if not resolved.is_file():
            raise MirrorError(f"goMarkableStream binary not found at {resolved}")
        return resolved, resolved.name

    asset = resolve_release_asset()
    target_dir = CACHE_DIR / asset.tag_name
    target_dir.mkdir(parents=True, exist_ok=True)
    binary_path = target_dir / asset.asset_name

    if binary_path.is_file():
        if asset.sha256 is None or sha256_file(binary_path) == asset.sha256:
            binary_path.chmod(binary_path.stat().st_mode | 0o111)
            return binary_path, asset.label

    download_path = target_dir / f"{asset.asset_name}.download"
    if download_path.exists():
        download_path.unlink()

    try:
        download_file(asset.download_url, download_path)
        if asset.sha256 is not None and sha256_file(download_path) != asset.sha256:
            raise MirrorError("downloaded goMarkableStream binary failed SHA256 verification")
        download_path.chmod(0o755)
        download_path.replace(binary_path)
    finally:
        if download_path.exists():
            download_path.unlink()

    return binary_path, asset.label


def terminate_process(process: subprocess.Popen[str], *, timeout: float = 2.0) -> None:
    if process.poll() is not None:
        return

    process.terminate()
    try:
        process.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait(timeout=timeout)


def remove_remote_path(host: str, remote_path: str) -> None:
    run_ssh(host, f"rm -f {shell_quote(remote_path)}", check=False)


def stop_remote_process(
    host: str,
    remote_path: str,
    local_process: subprocess.Popen[str] | None = None,
) -> None:
    if local_process is not None:
        terminate_process(local_process)

    quoted_path = shell_quote(remote_path)
    remote_command = "\n".join(
        [
            f"for pid in $(ps | grep -F -- {quoted_path} | grep -v grep | awk '{{print $1}}'); do",
            '  kill "$pid" >/dev/null 2>&1 || true',
            "done",
            f"rm -f {quoted_path}",
        ]
    )
    run_ssh(host, remote_command, check=False)


def parse_ready_dimensions(ready_line: str) -> tuple[int, int]:
    width = DEFAULT_SCREEN_WIDTH
    height = DEFAULT_SCREEN_HEIGHT
    for token in ready_line.split():
        if token.startswith("width="):
            width = int(token.split("=", 1)[1])
        if token.startswith("height="):
            height = int(token.split("=", 1)[1])
    return (width, height)


def start_injector(host: str, injector_path: pathlib.Path) -> InjectorSession:
    remote_path = f"/tmp/{REMOTE_INJECTOR_BASENAME}-{os.getpid()}"
    run_scp(injector_path, host, remote_path)
    run_ssh(host, f"chmod +x {shell_quote(remote_path)}")

    process = subprocess.Popen(
        [*ssh_base_command(host), remote_path],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
    )

    assert process.stdout is not None
    ready_line = process.stdout.readline().strip()
    if not ready_line.startswith("READY "):
        details = ready_line or "touch injector did not print its ready line"
        terminate_process(process)
        remove_remote_path(host, remote_path)
        raise MirrorError(f"touch injector did not start cleanly: {details}")

    width, height = parse_ready_dimensions(ready_line)
    return InjectorSession(process=process, remote_path=remote_path, width=width, height=height)


def start_gomarkablestream(host: str, binary_path: pathlib.Path, port: int, label: str) -> RemoteProcessSession:
    remote_path = f"/tmp/{REMOTE_STREAM_BASENAME}-{os.getpid()}"
    run_scp(binary_path, host, remote_path)
    run_ssh(host, f"chmod +x {shell_quote(remote_path)}")

    remote_command = " ".join(
        [
            f"RK_SERVER_BIND_ADDR=:{port}",
            "RK_HTTPS=false",
            "RK_JWT_ENABLED=false",
            f"exec {shell_quote(remote_path)} -unsafe",
        ]
    )
    process = subprocess.Popen(
        [*ssh_base_command(host), remote_command],
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
    )
    log_tail = ProcessLogTail(process)

    return RemoteProcessSession(
        process=process,
        remote_path=remote_path,
        port=port,
        log_tail=log_tail,
        label=label,
    )


class InjectorBridge(QObject):
    def __init__(self, process: subprocess.Popen[str], parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._process = process
        self._touch_active = False

    def press(self, x: int, y: int) -> None:
        if self._touch_active:
            self.move(x, y)
            return

        self.send_command(f"down {x} {y}")
        self._touch_active = True

    def move(self, x: int, y: int) -> None:
        if not self._touch_active:
            return
        self.send_command(f"move {x} {y}")

    def release(self) -> None:
        if not self._touch_active:
            return
        self.send_command("up")
        self._touch_active = False

    def send_command(self, command: str) -> None:
        if self._process.poll() is not None:
            raise MirrorError("touch injector exited unexpectedly")
        if self._process.stdin is None:
            raise MirrorError("touch injector stdin is unavailable")

        self._process.stdin.write(command + "\n")
        self._process.stdin.flush()

    def close(self) -> None:
        if self._process.poll() is not None:
            return

        if self._process.stdin is not None:
            try:
                self.send_command("quit")
            except Exception:
                pass

        terminate_process(self._process)


class MirrorPage(QWebEnginePage):
    def javaScriptConsoleMessage(self, level: int, message: str, line_number: int, source_id: str) -> None:
        if level == QWebEnginePage.ErrorMessageLevel:
            sys.stderr.write(f"[mirror-page] {source_id}:{line_number}: {message}\n")


class MirrorBrowserView(QWebEngineView):
    pageReady = pyqtSignal()
    fatalError = pyqtSignal(str)

    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.setPage(MirrorPage(self))
        self.setMouseTracking(True)

        self.injector_bridge: InjectorBridge | None = None
        self.tablet_width = DEFAULT_SCREEN_WIDTH
        self.tablet_height = DEFAULT_SCREEN_HEIGHT
        self.canvas_rect = QRect()
        self.pointer_active = False
        self.last_stream_restart = 0.0

        self.canvas_sync_timer = QTimer(self)
        self.canvas_sync_timer.timeout.connect(self.sync_canvas_rect)
        self.loadFinished.connect(self.handle_load_finished)

    def attach_injector(self, injector_bridge: InjectorBridge, width: int, height: int) -> None:
        self.injector_bridge = injector_bridge
        self.tablet_width = width
        self.tablet_height = height

    def load_stream(self, url: str) -> None:
        self.load(QUrl(url))

    def handle_load_finished(self, ok: bool) -> None:
        if not ok:
            self.fatalError.emit("goMarkableStream page failed to load")
            return

        self.page().runJavaScript(PAGE_CUSTOMIZATION_SCRIPT)
        self.sync_canvas_rect()
        self.canvas_sync_timer.start(250)
        self.pageReady.emit()

    def sync_canvas_rect(self) -> None:
        self.page().runJavaScript(CANVAS_RECT_SCRIPT, self.update_canvas_rect)

    def update_canvas_rect(self, rect_data: object) -> None:
        if not isinstance(rect_data, dict):
            return

        width = int(rect_data.get("width") or 0)
        height = int(rect_data.get("height") or 0)
        if width <= 0 or height <= 0:
            return

        self.canvas_rect = QRect(
            int(rect_data.get("left") or 0),
            int(rect_data.get("top") or 0),
            width,
            height,
        )

    def restart_stream(self) -> None:
        self.page().runJavaScript("window.codexRestartStream && window.codexRestartStream();")
        self.last_stream_restart = time.monotonic()

    def clear_touch_state(self) -> None:
        if not self.pointer_active or self.injector_bridge is None:
            return

        try:
            self.injector_bridge.release()
        except MirrorError:
            pass

        self.pointer_active = False
        self.releaseMouse()

    def map_to_tablet(self, event_pos: object, *, clamp: bool) -> tuple[int, int] | None:
        if self.canvas_rect.isNull():
            return None

        x = float(event_pos.x())
        y = float(event_pos.y())
        left = float(self.canvas_rect.left())
        top = float(self.canvas_rect.top())
        right = left + float(self.canvas_rect.width()) - 1.0
        bottom = top + float(self.canvas_rect.height()) - 1.0

        if not clamp and (x < left or x > right or y < top or y > bottom):
            return None

        x = min(max(x, left), right)
        y = min(max(y, top), bottom)

        width = max(1.0, float(self.canvas_rect.width()) - 1.0)
        height = max(1.0, float(self.canvas_rect.height()) - 1.0)
        normalized_x = (x - left) / width
        normalized_y = (y - top) / height

        tablet_x = round(normalized_x * (self.tablet_width - 1))
        tablet_y = round(normalized_y * (self.tablet_height - 1))
        return (tablet_x, tablet_y)

    def should_restart_stream(self) -> bool:
        return time.monotonic() - self.last_stream_restart >= STREAM_REFRESH_COOLDOWN_SECONDS

    def mousePressEvent(self, event: QMouseEvent) -> None:
        if event.button() == Qt.LeftButton and self.injector_bridge is not None:
            mapped = self.map_to_tablet(event.localPos(), clamp=False)
            if mapped is not None:
                try:
                    if self.should_restart_stream():
                        self.restart_stream()
                    self.injector_bridge.press(*mapped)
                except MirrorError as error:
                    self.fatalError.emit(str(error))
                    return

                self.pointer_active = True
                self.grabMouse()
                event.accept()
                return

        super().mousePressEvent(event)

    def mouseMoveEvent(self, event: QMouseEvent) -> None:
        if self.pointer_active and self.injector_bridge is not None:
            mapped = self.map_to_tablet(event.localPos(), clamp=True)
            if mapped is not None:
                try:
                    self.injector_bridge.move(*mapped)
                except MirrorError as error:
                    self.fatalError.emit(str(error))
                    return
            event.accept()
            return

        super().mouseMoveEvent(event)

    def mouseReleaseEvent(self, event: QMouseEvent) -> None:
        if self.pointer_active and self.injector_bridge is not None:
            try:
                self.injector_bridge.release()
            except MirrorError as error:
                self.fatalError.emit(str(error))
                return

            self.pointer_active = False
            self.releaseMouse()
            event.accept()
            return

        super().mouseReleaseEvent(event)


class PlaceholderView(QWidget):
    def __init__(self, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.setStyleSheet("background: #f3f1ea; color: #1f1e1a;")

        self.title_label = QLabel(self)
        self.title_label.setAlignment(Qt.AlignHCenter)
        self.title_label.setStyleSheet("font-size: 22px; font-weight: 600;")

        self.subtitle_label = QLabel(self)
        self.subtitle_label.setAlignment(Qt.AlignHCenter)
        self.subtitle_label.setWordWrap(True)
        self.subtitle_label.setStyleSheet("font-size: 14px; color: #535146;")

        self.detail_label = QLabel(self)
        self.detail_label.setAlignment(Qt.AlignHCenter)
        self.detail_label.setWordWrap(True)
        self.detail_label.setTextInteractionFlags(Qt.TextSelectableByMouse)
        self.detail_label.setStyleSheet("font-family: Menlo, monospace; font-size: 12px; color: #635f52;")

        layout = QVBoxLayout(self)
        layout.setContentsMargins(64, 48, 64, 48)
        layout.addStretch(1)
        layout.addWidget(self.title_label)
        layout.addSpacing(16)
        layout.addWidget(self.subtitle_label)
        layout.addSpacing(20)
        layout.addWidget(self.detail_label)
        layout.addStretch(2)

    def set_message(self, title: str, subtitle: str, detail: str = "") -> None:
        self.title_label.setText(title)
        self.subtitle_label.setText(subtitle)
        self.detail_label.setText(detail)
        self.detail_label.setVisible(bool(detail))


class MirrorWindow(QWidget):
    def __init__(self, hostname: str, parent: QWidget | None = None) -> None:
        super().__init__(parent)
        self.setWindowTitle(f"reMarkable Mirror - {hostname}")
        self.setMinimumSize(MIN_WINDOW_WIDTH, MIN_WINDOW_HEIGHT)

        self.placeholder_view = PlaceholderView(self)
        self.browser_view = MirrorBrowserView(self)

        self.stack = QStackedLayout(self)
        self.stack.setContentsMargins(0, 0, 0, 0)
        self.stack.addWidget(self.placeholder_view)
        self.stack.addWidget(self.browser_view)
        self.stack.setCurrentWidget(self.placeholder_view)

        self.resize_for_tablet(DEFAULT_SCREEN_WIDTH, DEFAULT_SCREEN_HEIGHT)

    def resize_for_tablet(self, width: int, height: int) -> None:
        screen = QApplication.primaryScreen()
        if screen is None:
            return

        geometry = screen.availableGeometry()
        target_width = int(geometry.width() * 0.72)
        target_height = int(target_width * (height / width))

        max_height = int(geometry.height() * 0.82)
        if target_height > max_height:
            target_height = max_height
            target_width = int(target_height * (width / height))

        self.resize(target_width, target_height)

    def show_placeholder(self, title: str, subtitle: str, detail: str = "") -> None:
        self.placeholder_view.set_message(title, subtitle, detail)
        self.stack.setCurrentWidget(self.placeholder_view)

    def show_browser(self) -> None:
        self.stack.setCurrentWidget(self.browser_view)


class MirrorController(QObject):
    def __init__(self, config: MirrorConfig, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self.config = config
        self.username, self.hostname = parse_host(config.host)

        self.window = MirrorWindow(self.hostname)
        self.window.browser_view.pageReady.connect(self.window.show_browser)
        self.window.browser_view.fatalError.connect(self.on_browser_error)
        self.window.show()

        self.injector_session: InjectorSession | None = None
        self.injector_bridge: InjectorBridge | None = None
        self.stream_session: RemoteProcessSession | None = None
        self.closed = False

        self.poll_timer = QTimer(self)
        self.poll_timer.timeout.connect(self.try_open_stream)

        self.monitor_timer = QTimer(self)
        self.monitor_timer.timeout.connect(self.monitor_processes)

        QTimer.singleShot(0, self.bootstrap)

    def bootstrap(self) -> None:
        try:
            self.window.show_placeholder(
                "Starting touch bridge",
                "Uploading the tablet touch injector and preparing the mirror window.",
            )
            QApplication.processEvents()

            self.injector_session = start_injector(self.config.host, self.config.injector_path)
            self.injector_bridge = InjectorBridge(self.injector_session.process, self)
            self.window.browser_view.attach_injector(
                self.injector_bridge,
                self.injector_session.width,
                self.injector_session.height,
            )
            self.window.resize_for_tablet(self.injector_session.width, self.injector_session.height)

            self.window.show_placeholder(
                "Preparing goMarkableStream",
                "Downloading the RM2 browser streamer and starting it on the tablet.",
            )
            QApplication.processEvents()

            binary_path, release_label = ensure_gomarkablestream_binary(self.config.gomarkablestream_path)
            self.stream_session = start_gomarkablestream(
                self.config.host,
                binary_path,
                self.config.port,
                release_label,
            )
            self.window.setWindowTitle(f"reMarkable Mirror - {self.hostname} - {release_label}")
            self.window.show_placeholder(
                "Starting goMarkableStream",
                f"Waiting for {self.stream_origin()} to accept connections.",
            )
            self.poll_timer.start(STATUS_POLL_MS)
            self.monitor_timer.start(STATUS_POLL_MS)
        except MirrorError as error:
            self.show_error("Mirror startup failed", str(error))

    def stream_origin(self) -> str:
        return f"http://{self.hostname}:{self.config.port}"

    def stream_url(self) -> str:
        return f"{self.stream_origin()}/?rate={self.config.rate_ms}"

    def port_is_open(self) -> bool:
        try:
            with socket.create_connection((self.hostname, self.config.port), timeout=0.5):
                return True
        except OSError:
            return False

    def try_open_stream(self) -> None:
        if not self.port_is_open():
            return

        self.poll_timer.stop()

        version_text = ""
        try:
            version = fetch_text(f"{self.stream_origin()}/version")
            if version:
                version_text = version
        except (OSError, urllib.error.URLError, urllib.error.HTTPError, TimeoutError):
            version_text = ""

        if version_text:
            self.window.setWindowTitle(f"reMarkable Mirror - {self.hostname} - {version_text}")

        self.window.show_placeholder(
            "Loading tablet UI",
            "Embedding the goMarkableStream viewer in the mirror window.",
        )
        self.window.browser_view.load_stream(self.stream_url())

    def monitor_processes(self) -> None:
        if self.injector_session is not None and self.injector_session.process.poll() is not None:
            self.show_error("Touch bridge stopped", "The tablet touch injector exited unexpectedly.")
            return

        if self.stream_session is not None and self.stream_session.process.poll() is not None:
            details = self.stream_session.log_tail.snapshot()
            self.show_error(
                "goMarkableStream stopped",
                "The tablet-side stream process exited unexpectedly.",
                details,
            )

    def show_error(self, title: str, subtitle: str, detail: str = "") -> None:
        self.poll_timer.stop()
        self.monitor_timer.stop()
        self.window.browser_view.clear_touch_state()
        self.window.show_placeholder(title, subtitle, detail)

    def on_browser_error(self, message: str) -> None:
        details = ""
        if self.stream_session is not None:
            details = self.stream_session.log_tail.snapshot()
        self.show_error("Mirror page failed", message, details)

    def close(self) -> None:
        if self.closed:
            return
        self.closed = True

        self.poll_timer.stop()
        self.monitor_timer.stop()
        self.window.browser_view.clear_touch_state()

        if self.injector_bridge is not None:
            self.injector_bridge.close()
            self.injector_bridge = None

        if self.stream_session is not None:
            stop_remote_process(
                self.config.host,
                self.stream_session.remote_path,
                self.stream_session.process,
            )
            self.stream_session = None

        if self.injector_session is not None:
            stop_remote_process(
                self.config.host,
                self.injector_session.remote_path,
                self.injector_session.process,
            )
            self.injector_session = None

        self.window.close()


def parse_args() -> MirrorConfig:
    parser = argparse.ArgumentParser(description="Mirror the reMarkable tablet UI into a local window")
    parser.add_argument("--host", default=DEFAULT_HOST)
    parser.add_argument(
        "--injector",
        default=str(REPO_ROOT / "build/remarkable_touch_injector"),
        help="local path to the cross-built tablet touch injector",
    )
    parser.add_argument(
        "--gomarkablestream",
        help="optional local path to a pre-downloaded RM2 goMarkableStream binary",
    )
    parser.add_argument(
        "--port",
        type=int,
        default=DEFAULT_STREAM_PORT_BASE + (os.getpid() % 1000),
        help="remote tablet port for goMarkableStream",
    )
    parser.add_argument(
        "--rate",
        type=int,
        default=DEFAULT_STREAM_RATE_MS,
        help="goMarkableStream client poll rate in milliseconds",
    )
    args = parser.parse_args()

    if args.rate < 1:
        raise MirrorError("stream rate must be at least 1ms")

    gomarkablestream_path = None
    if args.gomarkablestream:
        gomarkablestream_path = pathlib.Path(args.gomarkablestream).expanduser().resolve()

    return MirrorConfig(
        host=args.host,
        injector_path=pathlib.Path(args.injector).expanduser().resolve(),
        gomarkablestream_path=gomarkablestream_path,
        port=args.port,
        rate_ms=args.rate,
    )


def main() -> int:
    config = parse_args()
    if not config.injector_path.is_file():
        raise MirrorError(f"touch injector not found at {config.injector_path}")

    for command_name in ("ssh", "scp", "python3"):
        require_command(command_name)

    app = QApplication([sys.argv[0]])
    signal.signal(signal.SIGINT, lambda *_: app.quit())
    signal_timer = QTimer()
    signal_timer.timeout.connect(lambda: None)
    signal_timer.start(200)
    controller = MirrorController(config)
    app.aboutToQuit.connect(controller.close)
    return app.exec_()


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        raise SystemExit(130)
    except MirrorError as error:
        print(error, file=sys.stderr)
        raise SystemExit(1)
