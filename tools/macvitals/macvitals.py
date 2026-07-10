#!/usr/bin/env python3
"""
MacVitals — Beautiful macOS System Monitor
Real-time CPU, Memory, Disk, Network, Battery & Process dashboard.
"""
import tkinter as tk
import customtkinter as ctk
import psutil
import platform
import subprocess
import threading
import time
from collections import deque
from datetime import datetime

# ─────────────────────────────────────────────────────────────────────
# Theme
# ─────────────────────────────────────────────────────────────────────
ctk.set_appearance_mode("System")
ctk.set_default_color_theme("blue")

ACCENT   = "#007AFF"
GREEN    = "#30D158"
YELLOW   = "#FF9F0A"
RED      = "#FF453A"
PURPLE   = "#BF5AF2"
TEAL     = "#5AC8FA"

DARK_CARD = "#1c1c1e"
LIGHT_CARD = "#f2f2f7"
DARK_BG   = "#111111"
LIGHT_BG  = "#e5e5ea"


def card_bg():
    return DARK_CARD if ctk.get_appearance_mode() == "Dark" else LIGHT_CARD


def canvas_bg():
    return DARK_CARD if ctk.get_appearance_mode() == "Dark" else LIGHT_CARD


def pct_colour(pct: float) -> str:
    if pct < 60:
        return GREEN
    if pct < 85:
        return YELLOW
    return RED


def fmt_bytes(b: float) -> str:
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if abs(b) < 1024:
            return f"{b:.1f} {unit}"
        b /= 1024
    return f"{b:.1f} PB"


# ─────────────────────────────────────────────────────────────────────
# Reusable Widgets
# ─────────────────────────────────────────────────────────────────────
class RingGauge(tk.Canvas):
    """Animated arc gauge that fills from 12 o'clock clockwise."""

    def __init__(self, parent, size: int = 160, **kw):
        bg = canvas_bg()
        super().__init__(parent, width=size, height=size,
                         highlightthickness=0, bd=0, bg=bg, **kw)
        self.size = size
        self._draw(0, GREEN)

    def set(self, pct: float):
        self._draw(max(0, min(100, pct)), pct_colour(pct))

    def _draw(self, pct: float, colour: str):
        self.delete("all")
        s = self.size
        pad = 18
        # track ring
        self.create_arc(pad, pad, s - pad, s - pad,
                        start=90, extent=-360,
                        outline="#333333" if ctk.get_appearance_mode() == "Dark" else "#d1d1d6",
                        width=14, style="arc")
        # value ring
        extent = -max(1, int(pct / 100 * 360))
        self.create_arc(pad, pad, s - pad, s - pad,
                        start=90, extent=extent,
                        outline=colour, width=14, style="arc")
        # glow cap dots at ends
        angle_rad = __import__("math").radians(90)
        # centre label
        self.create_text(s // 2, s // 2 - 8,
                         text=f"{pct:.0f}",
                         font=("SF Pro Display", int(s * 0.18), "bold"),
                         fill=colour)
        self.create_text(s // 2, s // 2 + 14,
                         text="%",
                         font=("SF Pro Display", int(s * 0.1)),
                         fill="#8e8e93")


class SparkLine(tk.Canvas):
    """Scrolling line history graph."""

    def __init__(self, parent, width: int = 300, height: int = 56,
                 maxval: float = 100, colour: str = ACCENT, label: str = "", **kw):
        bg = canvas_bg()
        super().__init__(parent, width=width, height=height,
                         highlightthickness=0, bd=0, bg=bg, **kw)
        self.maxval  = maxval
        self.colour  = colour
        self.history = deque([0.0] * 60, maxlen=60)
        self.label   = label
        self.bind("<Configure>", lambda e: self._draw())

    def push(self, value: float):
        self.history.append(value)
        self._draw()

    def _draw(self):
        self.delete("all")
        w = self.winfo_width() or int(self["width"])
        h = self.winfo_height() or int(self["height"])
        pts = list(self.history)
        n = len(pts)
        if n < 2:
            return
        step = w / (n - 1)
        maxv = self.maxval or max(pts) or 1
        coords = []
        for i, v in enumerate(pts):
            x = i * step
            y = h - 4 - (v / maxv) * (h - 8)
            coords += [x, y]
        if len(coords) >= 4:
            # fill area under curve
            fill_coords = [0, h] + coords + [w, h]
            fill_colour = self.colour + "22"  # semi-transparent
            try:
                self.create_polygon(fill_coords, fill=fill_colour, outline="")
            except tk.TclError:
                pass
            self.create_line(*coords, fill=self.colour, width=2, smooth=True)
        # latest value label
        latest = pts[-1]
        label = f"{latest:.1f}" if latest < 100 else f"{latest:.0f}"
        self.create_text(w - 6, 6, text=label, anchor="ne",
                         font=("SF Pro Display", 10, "bold"),
                         fill=self.colour)


class StatCard(ctk.CTkFrame):
    """Metric tile with title, large value, and optional subtitle."""

    def __init__(self, parent, title: str, value: str = "—", sub: str = "", **kw):
        super().__init__(parent, corner_radius=14,
                         fg_color=(LIGHT_CARD, DARK_CARD), **kw)
        ctk.CTkLabel(self, text=title,
                     font=ctk.CTkFont(size=11),
                     text_color="#8e8e93").pack(anchor="w", padx=14, pady=(10, 0))
        self._val_lbl = ctk.CTkLabel(self, text=value,
                                      font=ctk.CTkFont(size=22, weight="bold"))
        self._val_lbl.pack(anchor="w", padx=14)
        self._sub_lbl = ctk.CTkLabel(self, text=sub,
                                      font=ctk.CTkFont(size=11),
                                      text_color="#8e8e93")
        self._sub_lbl.pack(anchor="w", padx=14, pady=(0, 10))

    def set(self, value: str, sub: str = ""):
        self._val_lbl.configure(text=value)
        if sub:
            self._sub_lbl.configure(text=sub)


class BarRow(ctk.CTkFrame):
    """Single labelled progress bar row."""

    def __init__(self, parent, label: str = "", bar_width: int = 200, **kw):
        super().__init__(parent, fg_color="transparent", **kw)
        self._lbl = ctk.CTkLabel(self, text=label, width=100,
                                  anchor="w", font=ctk.CTkFont(size=12))
        self._lbl.pack(side="left", padx=(0, 8))
        self._bar = ctk.CTkProgressBar(self, width=bar_width, height=10,
                                        progress_color=GREEN)
        self._bar.set(0)
        self._bar.pack(side="left", padx=(0, 8))
        self._pct = ctk.CTkLabel(self, text="0%", width=44, anchor="e",
                                  font=ctk.CTkFont(size=12))
        self._pct.pack(side="left")

    def set(self, pct: float, label: str = ""):
        v = max(0, min(100, pct))
        self._bar.set(v / 100)
        self._bar.configure(progress_color=pct_colour(v))
        self._pct.configure(text=f"{v:.0f}%")
        if label:
            self._lbl.configure(text=label)


def section(parent, title: str) -> ctk.CTkFrame:
    """Card frame with a section title header."""
    outer = ctk.CTkFrame(parent, corner_radius=14,
                          fg_color=(LIGHT_CARD, DARK_CARD))
    ctk.CTkLabel(outer, text=title, font=ctk.CTkFont(size=13, weight="bold")
                 ).pack(anchor="w", padx=16, pady=(12, 6))
    ctk.CTkFrame(outer, height=1,
                 fg_color=("gray75", "gray30")).pack(fill="x", padx=12)
    inner = ctk.CTkFrame(outer, fg_color="transparent")
    inner.pack(fill="both", expand=True, padx=12, pady=(8, 12))
    return outer, inner


# ─────────────────────────────────────────────────────────────────────
# Views
# ─────────────────────────────────────────────────────────────────────
class CPUView(ctk.CTkScrollableFrame):
    def __init__(self, parent):
        super().__init__(parent, fg_color="transparent", corner_radius=0)
        self.columnconfigure((0, 1), weight=1)

        ctk.CTkLabel(self, text="CPU",
                     font=ctk.CTkFont(size=30, weight="bold")
                     ).grid(row=0, column=0, columnspan=2,
                            sticky="w", padx=4, pady=(0, 14))

        # ── Left: gauge card
        gauge_card = ctk.CTkFrame(self, corner_radius=14,
                                   fg_color=(LIGHT_CARD, DARK_CARD))
        gauge_card.grid(row=1, column=0, sticky="nsew", padx=(0, 6), pady=(0, 8))
        self._ring = RingGauge(gauge_card, size=168)
        self._ring.pack(pady=(22, 6), padx=22)
        self._ring_sub = ctk.CTkLabel(gauge_card, text="Overall Usage",
                                       text_color="#8e8e93",
                                       font=ctk.CTkFont(size=12))
        self._ring_sub.pack(pady=(0, 18))

        # ── Right: stat cards
        right = ctk.CTkFrame(self, fg_color="transparent")
        right.grid(row=1, column=1, sticky="nsew", padx=(6, 0), pady=(0, 8))
        right.columnconfigure((0, 1), weight=1)

        self._freq_card  = StatCard(right, "Frequency", "—", "GHz")
        self._cores_card = StatCard(right, "Cores",
                                     f"{psutil.cpu_count(logical=False)}P / {psutil.cpu_count()}L")
        self._load_card  = StatCard(right, "Load Avg (1m)", "—")
        self._model_card = StatCard(right, "Processor", self._cpu_name()[:26])

        for i, card in enumerate([self._freq_card, self._cores_card,
                                    self._load_card, self._model_card]):
            card.grid(row=i // 2, column=i % 2,
                      padx=4, pady=4, sticky="ew")

        # ── Per-core bars
        core_outer, core_inner = section(self, "Per-Core Usage")
        core_outer.grid(row=2, column=0, columnspan=2,
                         sticky="ew", pady=(0, 8))
        core_inner.columnconfigure((0, 1), weight=1)

        n = psutil.cpu_count()
        self._core_bars = []
        for i in range(n):
            bar = BarRow(core_inner, label=f"Core {i + 1}", bar_width=160)
            bar.grid(row=i // 2, column=i % 2, sticky="ew", padx=4, pady=2)
            self._core_bars.append(bar)

        # ── Sparkline
        spark_outer, spark_inner = section(self, "Usage History  (60 s)")
        spark_outer.grid(row=3, column=0, columnspan=2, sticky="ew")
        self._spark = SparkLine(spark_inner, height=64, colour=ACCENT)
        self._spark.pack(fill="x", expand=True, pady=(4, 0))

    def _cpu_name(self) -> str:
        try:
            r = subprocess.run(["sysctl", "-n", "machdep.cpu.brand_string"],
                               capture_output=True, text=True, timeout=2)
            return r.stdout.strip()
        except Exception:
            return platform.processor() or "Unknown"

    def update_data(self):
        overall   = psutil.cpu_percent()
        per_core  = psutil.cpu_percent(percpu=True)
        freq      = psutil.cpu_freq()
        load1, *_ = psutil.getloadavg()

        self._ring.set(overall)
        self._spark.push(overall)
        self._load_card.set(f"{load1:.2f}")
        if freq:
            self._freq_card.set(f"{freq.current / 1000:.2f}", "GHz")
        for bar, pct in zip(self._core_bars, per_core):
            bar.set(pct)


class MemoryView(ctk.CTkScrollableFrame):
    def __init__(self, parent):
        super().__init__(parent, fg_color="transparent", corner_radius=0)
        self.columnconfigure((0, 1), weight=1)

        ctk.CTkLabel(self, text="Memory",
                     font=ctk.CTkFont(size=30, weight="bold")
                     ).grid(row=0, column=0, columnspan=2,
                            sticky="w", padx=4, pady=(0, 14))

        # Gauge
        gauge_card = ctk.CTkFrame(self, corner_radius=14,
                                   fg_color=(LIGHT_CARD, DARK_CARD))
        gauge_card.grid(row=1, column=0, sticky="nsew", padx=(0, 6), pady=(0, 8))
        self._ring = RingGauge(gauge_card, size=168)
        self._ring.pack(pady=(22, 6), padx=22)
        ctk.CTkLabel(gauge_card, text="RAM Pressure",
                     text_color="#8e8e93",
                     font=ctk.CTkFont(size=12)).pack(pady=(0, 18))

        right = ctk.CTkFrame(self, fg_color="transparent")
        right.grid(row=1, column=1, sticky="nsew", padx=(6, 0), pady=(0, 8))
        right.columnconfigure((0, 1), weight=1)

        vm = psutil.virtual_memory()
        self._used_card  = StatCard(right, "Used", "—", "GB")
        self._avail_card = StatCard(right, "Available", "—", "GB")
        self._total_card = StatCard(right, "Total RAM",
                                     f"{vm.total / 1e9:.1f}", "GB")
        self._swap_card  = StatCard(right, "Swap Used", "—", "GB")

        for i, c in enumerate([self._used_card, self._avail_card,
                                 self._total_card, self._swap_card]):
            c.grid(row=i // 2, column=i % 2, padx=4, pady=4, sticky="ew")

        bk_outer, bk_inner = section(self, "Usage Breakdown")
        bk_outer.grid(row=2, column=0, columnspan=2, sticky="ew", pady=(0, 8))
        bk_inner.columnconfigure(0, weight=1)
        self._ram_bar  = BarRow(bk_inner, label="RAM", bar_width=320)
        self._swap_bar = BarRow(bk_inner, label="Swap", bar_width=320)
        self._ram_bar.pack(fill="x", pady=3)
        self._swap_bar.pack(fill="x", pady=3)

        spark_outer, spark_inner = section(self, "Pressure History  (60 s)")
        spark_outer.grid(row=3, column=0, columnspan=2, sticky="ew")
        self._spark = SparkLine(spark_inner, height=64, colour=GREEN)
        self._spark.pack(fill="x", expand=True, pady=(4, 0))

    def update_data(self):
        vm   = psutil.virtual_memory()
        swap = psutil.swap_memory()
        pct  = vm.percent

        self._ring.set(pct)
        self._spark.push(pct)
        self._used_card.set(f"{vm.used / 1e9:.1f}", "GB")
        self._avail_card.set(f"{vm.available / 1e9:.1f}", "GB")
        self._swap_card.set(f"{swap.used / 1e9:.1f}", "GB")
        self._ram_bar.set(pct)
        self._swap_bar.set(swap.percent)


class DiskView(ctk.CTkScrollableFrame):
    def __init__(self, parent):
        super().__init__(parent, fg_color="transparent", corner_radius=0)
        self.columnconfigure(0, weight=1)

        ctk.CTkLabel(self, text="Disk",
                     font=ctk.CTkFont(size=30, weight="bold")
                     ).grid(row=0, sticky="w", padx=4, pady=(0, 14))

        # I/O speed cards
        io_row = ctk.CTkFrame(self, fg_color="transparent")
        io_row.grid(row=1, sticky="ew", pady=(0, 8))
        io_row.columnconfigure((0, 1, 2, 3), weight=1)
        self._read_card  = StatCard(io_row, "Read Speed",  "—", "/s")
        self._write_card = StatCard(io_row, "Write Speed", "—", "/s")
        self._read_card.grid(row=0, column=0, padx=(0, 4), sticky="ew")
        self._write_card.grid(row=0, column=1, padx=(4, 0), sticky="ew")

        # Volumes
        vol_outer, self._vol_inner = section(self, "Volumes")
        vol_outer.grid(row=2, sticky="ew", pady=(0, 8))
        self._vol_bars: dict[str, BarRow] = {}

        # Sparklines
        spark_outer, spark_inner = section(self, "I/O Activity  (60 s)")
        spark_outer.grid(row=3, sticky="ew")
        ctk.CTkLabel(spark_inner, text="▲ Read",
                     font=ctk.CTkFont(size=11), text_color=TEAL).pack(anchor="w")
        self._read_spark  = SparkLine(spark_inner, height=48, colour=TEAL)
        self._read_spark.pack(fill="x", expand=True)
        ctk.CTkLabel(spark_inner, text="▼ Write",
                     font=ctk.CTkFont(size=11), text_color=YELLOW).pack(anchor="w", pady=(8, 0))
        self._write_spark = SparkLine(spark_inner, height=48, colour=YELLOW)
        self._write_spark.pack(fill="x", expand=True)

        self._prev_io = psutil.disk_io_counters()
        self._prev_t  = time.time()

    def update_data(self):
        # Volumes
        for part in psutil.disk_partitions(all=False):
            try:
                u = psutil.disk_usage(part.mountpoint)
            except (PermissionError, OSError):
                continue
            mp = part.mountpoint
            pct = u.percent
            sub = f"{u.used / 1e9:.0f} / {u.total / 1e9:.0f} GB"
            if mp not in self._vol_bars:
                bar = BarRow(self._vol_inner, label=mp, bar_width=280)
                bar.pack(fill="x", pady=3)
                self._vol_bars[mp] = bar
            self._vol_bars[mp].set(pct, label=f"{mp}  ({sub})")

        # I/O
        now = time.time()
        curr = psutil.disk_io_counters()
        if curr and self._prev_io:
            dt = max(now - self._prev_t, 0.001)
            r_spd = (curr.read_bytes  - self._prev_io.read_bytes)  / dt
            w_spd = (curr.write_bytes - self._prev_io.write_bytes) / dt
            self._read_card.set(fmt_bytes(r_spd), "/s")
            self._write_card.set(fmt_bytes(w_spd), "/s")
            self._read_spark.push(r_spd / 1e6)
            self._write_spark.push(w_spd / 1e6)
        self._prev_io = curr
        self._prev_t  = now


class NetworkView(ctk.CTkScrollableFrame):
    def __init__(self, parent):
        super().__init__(parent, fg_color="transparent", corner_radius=0)
        self.columnconfigure((0, 1), weight=1)

        ctk.CTkLabel(self, text="Network",
                     font=ctk.CTkFont(size=30, weight="bold")
                     ).grid(row=0, column=0, columnspan=2,
                            sticky="w", padx=4, pady=(0, 14))

        self._up_card   = StatCard(self, "Upload Speed",   "—", "/s")
        self._down_card = StatCard(self, "Download Speed", "—", "/s")
        self._sent_card = StatCard(self, "Total Sent",  "—")
        self._recv_card = StatCard(self, "Total Received", "—")

        self._up_card.grid(row=1, column=0, padx=(0, 6), pady=(0, 8), sticky="ew")
        self._down_card.grid(row=1, column=1, padx=(6, 0), pady=(0, 8), sticky="ew")
        self._sent_card.grid(row=2, column=0, padx=(0, 6), pady=(0, 8), sticky="ew")
        self._recv_card.grid(row=2, column=1, padx=(6, 0), pady=(0, 8), sticky="ew")

        spark_outer, spark_inner = section(self, "Throughput History  (60 s)")
        spark_outer.grid(row=3, column=0, columnspan=2, sticky="ew")
        ctk.CTkLabel(spark_inner, text="↑ Upload",
                     font=ctk.CTkFont(size=11), text_color=YELLOW).pack(anchor="w")
        self._up_spark = SparkLine(spark_inner, height=50, colour=YELLOW)
        self._up_spark.pack(fill="x", expand=True)
        ctk.CTkLabel(spark_inner, text="↓ Download",
                     font=ctk.CTkFont(size=11), text_color=TEAL).pack(anchor="w", pady=(8, 0))
        self._down_spark = SparkLine(spark_inner, height=50, colour=TEAL)
        self._down_spark.pack(fill="x", expand=True)

        # Interfaces
        iface_outer, iface_inner = section(self, "Active Interfaces")
        iface_outer.grid(row=4, column=0, columnspan=2, sticky="ew", pady=(8, 0))
        addrs = psutil.net_if_addrs()
        stats = psutil.net_if_stats()
        for iface, stat in stats.items():
            if stat.isup:
                ip = next((a.address for a in addrs.get(iface, [])
                           if a.family.name in ("AF_INET",)), "—")
                ctk.CTkLabel(iface_inner,
                             text=f"• {iface}  —  {ip}",
                             font=ctk.CTkFont(size=12),
                             text_color=("gray20", "gray80")).pack(anchor="w", pady=2)

        self._prev   = psutil.net_io_counters()
        self._prev_t = time.time()

    def update_data(self):
        now  = time.time()
        curr = psutil.net_io_counters()
        dt   = max(now - self._prev_t, 0.001)
        up   = (curr.bytes_sent - self._prev.bytes_sent) / dt
        dn   = (curr.bytes_recv - self._prev.bytes_recv) / dt

        self._up_card.set(fmt_bytes(up), "/s")
        self._down_card.set(fmt_bytes(dn), "/s")
        self._sent_card.set(fmt_bytes(curr.bytes_sent))
        self._recv_card.set(fmt_bytes(curr.bytes_recv))
        self._up_spark.push(up / 1e3)
        self._down_spark.push(dn / 1e3)

        self._prev   = curr
        self._prev_t = now


class BatteryView(ctk.CTkScrollableFrame):
    def __init__(self, parent):
        super().__init__(parent, fg_color="transparent", corner_radius=0)
        self.columnconfigure((0, 1), weight=1)

        ctk.CTkLabel(self, text="Battery",
                     font=ctk.CTkFont(size=30, weight="bold")
                     ).grid(row=0, column=0, columnspan=2,
                            sticky="w", padx=4, pady=(0, 14))

        gauge_card = ctk.CTkFrame(self, corner_radius=14,
                                   fg_color=(LIGHT_CARD, DARK_CARD))
        gauge_card.grid(row=1, column=0, sticky="nsew", padx=(0, 6), pady=(0, 8))
        self._ring = RingGauge(gauge_card, size=168)
        self._ring.pack(pady=(22, 6), padx=22)
        self._status_lbl = ctk.CTkLabel(gauge_card, text="—",
                                         text_color="#8e8e93",
                                         font=ctk.CTkFont(size=12))
        self._status_lbl.pack(pady=(0, 18))

        right = ctk.CTkFrame(self, fg_color="transparent")
        right.grid(row=1, column=1, sticky="nsew", padx=(6, 0), pady=(0, 8))
        right.columnconfigure((0, 1), weight=1)

        cycle, health = self._system_profiler()
        self._time_card   = StatCard(right, "Time Remaining", "—")
        self._power_card  = StatCard(right, "Power Source",   "—")
        self._cycle_card  = StatCard(right, "Cycle Count",    cycle)
        self._health_card = StatCard(right, "Condition",      health)

        for i, c in enumerate([self._time_card, self._power_card,
                                 self._cycle_card, self._health_card]):
            c.grid(row=i // 2, column=i % 2, padx=4, pady=4, sticky="ew")

        spark_outer, spark_inner = section(self, "Charge History  (60 s)")
        spark_outer.grid(row=2, column=0, columnspan=2, sticky="ew")
        self._spark = SparkLine(spark_inner, height=64, colour=GREEN)
        self._spark.pack(fill="x", expand=True, pady=(4, 0))

    def _system_profiler(self):
        try:
            r = subprocess.run(["system_profiler", "SPPowerDataType"],
                               capture_output=True, text=True, timeout=6)
            cycle = health = "—"
            for line in r.stdout.splitlines():
                if "Cycle Count" in line:
                    cycle = line.split(":")[-1].strip()
                if "Condition" in line:
                    health = line.split(":")[-1].strip()
            return cycle, health
        except Exception:
            return "—", "—"

    def update_data(self):
        bat = psutil.sensors_battery()
        if bat is None:
            self._status_lbl.configure(text="No Battery Found")
            return

        pct = bat.percent
        self._ring.set(pct)
        self._spark.push(pct)

        if bat.power_plugged:
            status = "Charging ⚡" if pct < 100 else "Fully Charged ✓"
        else:
            status = "On Battery"
        self._status_lbl.configure(text=status)
        self._power_card.set("AC Power" if bat.power_plugged else "Battery")

        secs = bat.secsleft
        if secs and secs > 0:
            h, m = divmod(secs // 60, 60)
            self._time_card.set(f"{h}h {m:02d}m")
        else:
            self._time_card.set("Calculating…" if bat.power_plugged else "—")


class ProcessesView(ctk.CTkFrame):
    COLS = [
        ("PID",     50, "pid"),
        ("Name",   220, "name"),
        ("CPU %",   76, "cpu"),
        ("MEM %",   76, "mem"),
        ("Status",  80, "status"),
        ("Threads", 64, "threads"),
    ]

    def __init__(self, parent):
        super().__init__(parent, fg_color="transparent", corner_radius=0)
        self.columnconfigure(0, weight=1)
        self.rowconfigure(1, weight=1)

        header_row = ctk.CTkFrame(self, fg_color="transparent")
        header_row.grid(row=0, sticky="ew", padx=4, pady=(0, 14))
        ctk.CTkLabel(header_row, text="Processes",
                     font=ctk.CTkFont(size=30, weight="bold")).pack(side="left")
        ctk.CTkLabel(header_row,
                     text=f"Total: {len(psutil.pids())}",
                     font=ctk.CTkFont(size=13),
                     text_color="#8e8e93").pack(side="left", padx=14, pady=(6, 0))

        # Table card
        card = ctk.CTkFrame(self, corner_radius=14,
                             fg_color=(LIGHT_CARD, DARK_CARD))
        card.grid(row=1, sticky="nsew")
        card.rowconfigure(1, weight=1)
        card.columnconfigure(0, weight=1)

        # Column headers
        hdr = ctk.CTkFrame(card, fg_color="transparent")
        hdr.grid(row=0, sticky="ew", padx=16, pady=(12, 4))
        for title, width, _ in self.COLS:
            ctk.CTkLabel(hdr, text=title, width=width, anchor="w",
                         font=ctk.CTkFont(size=11, weight="bold"),
                         text_color="#8e8e93").pack(side="left")

        ctk.CTkFrame(card, height=1,
                     fg_color=("gray75", "gray30")).grid(row=1,
                                                          column=0,
                                                          sticky="ew",
                                                          padx=12)

        self._scroll = ctk.CTkScrollableFrame(card, fg_color="transparent")
        self._scroll.grid(row=2, sticky="nsew", padx=4, pady=4)
        card.rowconfigure(2, weight=1)
        self._rows: list[ctk.CTkFrame] = []

    def update_data(self):
        procs = []
        for p in psutil.process_iter(
                ["pid", "name", "cpu_percent", "memory_percent",
                 "status", "num_threads"]):
            try:
                procs.append(p.info)
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                pass
        procs.sort(key=lambda x: x.get("cpu_percent") or 0, reverse=True)

        for row in self._rows:
            row.destroy()
        self._rows.clear()

        for i, p in enumerate(procs[:25]):
            row = ctk.CTkFrame(self._scroll,
                               fg_color=("gray88", "#232323") if i % 2 == 0
                               else ("gray93", "#1c1c1c"),
                               corner_radius=6)
            row.pack(fill="x", padx=4, pady=1)

            cpu = p.get("cpu_percent") or 0
            mem = p.get("memory_percent") or 0
            cells = [
                (str(p.get("pid", "")),         50, "#8e8e93"),
                ((p.get("name") or "")[:28],   220, None),
                (f"{cpu:.1f}%",                 76, pct_colour(cpu) if cpu > 5 else None),
                (f"{mem:.1f}%",                 76, pct_colour(mem) if mem > 10 else None),
                (p.get("status") or "",         80, None),
                (str(p.get("num_threads", "")), 64, "#8e8e93"),
            ]
            for text, width, colour in cells:
                kw = {"text_color": colour} if colour else {}
                ctk.CTkLabel(row, text=text, width=width, anchor="w",
                             font=ctk.CTkFont(size=12), **kw
                             ).pack(side="left", padx=(8, 0), pady=5)

            self._rows.append(row)


# ─────────────────────────────────────────────────────────────────────
# Sidebar
# ─────────────────────────────────────────────────────────────────────
NAV_ITEMS = [
    ("CPU",       "🖥",  ACCENT),
    ("Memory",    "💾",  GREEN),
    ("Disk",      "💿",  YELLOW),
    ("Network",   "🌐",  TEAL),
    ("Battery",   "🔋",  GREEN),
    ("Processes", "📊",  PURPLE),
]


class Sidebar(ctk.CTkFrame):
    def __init__(self, parent, on_select):
        super().__init__(parent, width=190, corner_radius=0,
                         fg_color=("gray88", "#141414"))
        self.propagate(False)
        self._on_select = on_select
        self._btns: dict[str, ctk.CTkButton] = {}
        self._build()

    def _build(self):
        ctk.CTkLabel(self, text="MacVitals",
                     font=ctk.CTkFont(size=20, weight="bold"),
                     text_color=ACCENT).pack(pady=(28, 6), padx=20, anchor="w")
        ctk.CTkLabel(self, text="System Monitor",
                     font=ctk.CTkFont(size=11),
                     text_color="#8e8e93").pack(padx=20, anchor="w")

        ctk.CTkFrame(self, height=1,
                     fg_color=("gray75", "gray25")).pack(fill="x",
                                                          padx=14,
                                                          pady=(14, 10))

        for name, icon, colour in NAV_ITEMS:
            btn = ctk.CTkButton(
                self,
                text=f"  {icon}  {name}",
                anchor="w",
                height=40,
                corner_radius=10,
                fg_color="transparent",
                hover_color=("gray80", "#2a2a2a"),
                text_color=("gray20", "gray80"),
                font=ctk.CTkFont(size=13),
                command=lambda n=name: self._on_select(n),
            )
            btn.pack(fill="x", padx=10, pady=2)
            self._btns[name] = btn

        # Appearance toggle at bottom
        ctk.CTkLabel(self, text="",).pack(expand=True)
        ctk.CTkLabel(self, text="Appearance",
                     font=ctk.CTkFont(size=10),
                     text_color="#8e8e93").pack(padx=14, anchor="w")
        ctk.CTkOptionMenu(self, values=["System", "Dark", "Light"],
                          width=160, height=28,
                          font=ctk.CTkFont(size=11),
                          command=ctk.set_appearance_mode
                          ).pack(padx=14, pady=(4, 8), anchor="w")

        self._time_lbl = ctk.CTkLabel(self, text="",
                                       font=ctk.CTkFont(size=11),
                                       text_color="#8e8e93")
        self._time_lbl.pack(pady=(4, 18))

    def select(self, name: str):
        for n, btn in self._btns.items():
            if n == name:
                btn.configure(fg_color=(ACCENT, ACCENT), text_color="white")
            else:
                btn.configure(fg_color="transparent",
                              text_color=("gray20", "gray80"))

    def tick(self, t: str):
        self._time_lbl.configure(text=t)


# ─────────────────────────────────────────────────────────────────────
# Application
# ─────────────────────────────────────────────────────────────────────
class MacVitals(ctk.CTk):
    def __init__(self):
        super().__init__()
        self.title("MacVitals")
        self.geometry("1020x700")
        self.minsize(860, 580)

        self.grid_columnconfigure(1, weight=1)
        self.grid_rowconfigure(0, weight=1)

        self._sidebar = Sidebar(self, self._show)
        self._sidebar.grid(row=0, column=0, sticky="nsew")

        content = ctk.CTkFrame(self, fg_color="transparent", corner_radius=0)
        content.grid(row=0, column=1, sticky="nsew", padx=20, pady=20)
        content.grid_rowconfigure(0, weight=1)
        content.grid_columnconfigure(0, weight=1)

        self._views: dict[str, ctk.CTkBaseClass] = {
            "CPU":       CPUView(content),
            "Memory":    MemoryView(content),
            "Disk":      DiskView(content),
            "Network":   NetworkView(content),
            "Battery":   BatteryView(content),
            "Processes": ProcessesView(content),
        }
        for v in self._views.values():
            v.grid(row=0, column=0, sticky="nsew")

        # Keyboard shortcuts Cmd+1…6
        for i, name in enumerate(self._views, 1):
            self.bind(f"<Command-{i}>", lambda e, n=name: self._show(n))

        self._show("CPU")
        threading.Thread(target=self._loop, daemon=True).start()

    def _show(self, name: str):
        self._sidebar.select(name)
        self._views[name].tkraise()

    def _loop(self):
        psutil.cpu_percent(percpu=True)   # warm-up call
        while True:
            self.after(0, self._tick)
            time.sleep(1)

    def _tick(self):
        self._sidebar.tick(datetime.now().strftime("%H:%M:%S"))
        for view in self._views.values():
            try:
                view.update_data()
            except Exception:
                pass


def main():
    app = MacVitals()
    app.mainloop()


if __name__ == "__main__":
    main()
