"""Symphony system tray monitor — shows agent status in the Windows system tray."""

import subprocess
import threading
import re
import time

import pystray
from PIL import Image, ImageDraw, ImageFont


COMPOSE_DIR = r"C:\Users\Coles\Gits\symphony\servo"
POLL_INTERVAL = 10  # seconds


def parse_status(raw: str) -> dict:
    """Parse the last status frame from docker compose logs output."""
    clean = re.sub(r"\x1b\[[0-9;]*m", "", raw)  # strip ANSI codes

    # Split on the frame header to isolate the last complete frame
    frames = re.split(r"╭─ SYMPHONY STATUS", clean)
    last_frame = frames[-1] if len(frames) > 1 else clean

    agents_match = re.search(r"Agents:\s*(\d+)/(\d+)", last_frame)
    active = int(agents_match.group(1)) if agents_match else 0
    capacity = int(agents_match.group(2)) if agents_match else 0

    tokens_match = re.search(r"total\s+([\d,]+)", last_frame)
    tokens = tokens_match.group(1) if tokens_match else "0"

    # Parse running agent rows from the last frame only
    tasks = []
    for m in re.finditer(
        r"[●○]\s+(\S+)\s+([\w ]+?)\s+\d+\s+([\dm ]+s\s*/\s*\d+)", last_frame
    ):
        tasks.append(
            {
                "id": m.group(1).strip(),
                "stage": m.group(2).strip(),
                "age": m.group(3).strip(),
            }
        )

    return {"active": active, "capacity": capacity, "tokens": tokens, "tasks": tasks}


def get_status() -> dict:
    """Get current Symphony status from docker compose logs."""
    try:
        result = subprocess.run(
            ["docker", "compose", "logs", "--tail=30", "symphony"],
            capture_output=True,
            text=True,
            cwd=COMPOSE_DIR,
            timeout=10,
            encoding="utf-8",
            errors="replace",
        )
        return parse_status(result.stdout)
    except Exception:
        return {"active": 0, "capacity": 0, "tokens": "0", "tasks": [], "error": True}


def make_icon(active: int, error: bool = False) -> Image.Image:
    """Draw a simple status icon: green=working, grey=idle, red=error."""
    size = 64
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    if error:
        color = (200, 50, 50)
    elif active > 0:
        color = (50, 200, 80)
    else:
        color = (140, 140, 140)

    # Filled circle
    draw.ellipse([4, 4, size - 4, size - 4], fill=color)

    # Agent count in center
    try:
        font = ImageFont.truetype("arialbd.ttf", 48)
    except OSError:
        try:
            font = ImageFont.truetype("arial.ttf", 48)
        except OSError:
            font = ImageFont.load_default()
    text = str(active)
    bbox = draw.textbbox((0, 0), text, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    x = (size - tw) / 2
    y = (size - th) / 2 - 4

    # Dark outline/stroke for contrast
    outline = 3
    for dx in range(-outline, outline + 1):
        for dy in range(-outline, outline + 1):
            if dx != 0 or dy != 0:
                draw.text((x + dx, y + dy), text, fill=(0, 0, 0, 200), font=font)

    draw.text((x, y), text, fill="white", font=font)

    return img


def build_tooltip(status: dict) -> str:
    if status.get("error"):
        return "Symphony: cannot reach Docker"
    lines = [f"Symphony: {status['active']}/{status['capacity']} agents"]
    for t in status["tasks"]:
        lines.append(f"  {t['id']} - {t['stage']} ({t['age']})")
    if not status["tasks"]:
        lines.append("  Idle")
    lines.append(f"  Tokens: {status['tokens']}")
    return "\n".join(lines)


def open_logs(_):
    subprocess.Popen(
        ["cmd", "/c", "start", "cmd", "/k", "docker compose logs -f symphony"],
        cwd=COMPOSE_DIR,
    )


def open_review_logs(_):
    subprocess.Popen(
        ["cmd", "/c", "start", "cmd", "/k", "docker compose logs -f review"],
        cwd=COMPOSE_DIR,
    )


def restart_containers(_):
    subprocess.Popen(
        ["docker", "compose", "restart"],
        cwd=COMPOSE_DIR,
    )


def stop_containers(icon, _):
    subprocess.Popen(
        ["docker", "compose", "stop"],
        cwd=COMPOSE_DIR,
    )
    icon.stop()


def poll_loop(icon: pystray.Icon):
    """Background thread that updates the icon and tooltip."""
    while icon.visible:
        status = get_status()
        icon.icon = make_icon(status["active"], status.get("error", False))
        icon.title = build_tooltip(status)
        time.sleep(POLL_INTERVAL)


def main():
    status = get_status()
    icon = pystray.Icon(
        "symphony",
        icon=make_icon(status["active"], status.get("error", False)),
        title=build_tooltip(status),
        menu=pystray.Menu(
            pystray.MenuItem("Coding agent logs", open_logs),
            pystray.MenuItem("Review agent logs", open_review_logs),
            pystray.Menu.SEPARATOR,
            pystray.MenuItem("Restart agents", restart_containers),
            pystray.MenuItem("Stop and quit", stop_containers),
        ),
    )

    poll_thread = threading.Thread(target=poll_loop, args=(icon,), daemon=True)
    poll_thread.start()
    icon.run()


if __name__ == "__main__":
    main()
