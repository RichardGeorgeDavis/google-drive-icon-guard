#!/usr/bin/env python3

from __future__ import annotations

import html
import json
import math
import subprocess
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[2]
REPORT_PATH = PROJECT_ROOT / "cache" / "scope-inventory" / "latest.json"
OUTPUT_DIR = PROJECT_ROOT / "docs" / "images"

WIDTH = 1600
HEIGHT = 1000


def load_report() -> dict:
    return json.loads(REPORT_PATH.read_text(encoding="utf-8"))


def format_bytes(value: int) -> str:
    units = ["B", "KB", "MB", "GB", "TB"]
    current = float(value)
    unit = units[0]
    for candidate in units:
        unit = candidate
        if current < 1024 or candidate == units[-1]:
            break
        current /= 1024
    if unit == "B":
        return f"{int(current)} {unit}"
    if current >= 100:
        return f"{current:.0f} {unit}"
    if current >= 10:
        return f"{current:.1f} {unit}"
    return f"{current:.2f} {unit}"


def escape(value: str) -> str:
    return html.escape(value, quote=False)


def truncate_middle(value: str, limit: int = 42) -> str:
    if len(value) <= limit:
        return value
    half = (limit - 1) // 2
    return f"{value[:half]}…{value[-half:]}"


def write_png(svg_path: Path, png_path: Path) -> None:
    subprocess.run(
        [
            "rsvg-convert",
            "-w",
            str(WIDTH),
            "-h",
            str(HEIGHT),
            "-o",
            str(png_path),
            str(svg_path),
        ],
        check=True,
    )


def card(x: int, y: int, w: int, h: int, title: str, value: str, tone: str = "#0f172a") -> str:
    return f"""
    <g>
      <rect x="{x}" y="{y}" width="{w}" height="{h}" rx="24" fill="#ffffff" />
      <text x="{x + 26}" y="{y + 40}" font-size="20" fill="#64748b" font-weight="600">{escape(title)}</text>
      <text x="{x + 26}" y="{y + 92}" font-size="42" fill="{tone}" font-weight="700">{escape(value)}</text>
    </g>
    """


def dashboard_svg(report: dict) -> str:
    scopes = report.get("scopes", [])
    artefacts = report.get("artefactInventory", {})
    findings = artefacts.get("scopeResults", [])
    supported = sum(1 for scope in scopes if scope.get("supportStatus") == "supported")
    audit_only = sum(1 for scope in scopes if scope.get("supportStatus") == "auditOnly")
    warnings = report.get("warnings", [])
    generated_at = report.get("generatedAt", "").replace("T", " ").replace("Z", " UTC")

    scope_rows = []
    top_scopes = sorted(findings, key=lambda item: item.get("matchedArtefactCount", 0), reverse=True)
    findings_by_name = {item.get("scopeDisplayName"): item for item in top_scopes}
    row_y = 378
    for index, scope in enumerate(scopes[:4]):
        display_name = scope.get("displayName", "Unknown")
        path = truncate_middle(scope.get("path", ""))
        mode = scope.get("driveMode", "unknown").upper()
        support = scope.get("supportStatus", "unknown")
        matched = findings_by_name.get(display_name, {}).get("matchedArtefactCount", 0)
        bytes_value = findings_by_name.get(display_name, {}).get("matchedBytes", 0)
        pill_fill = "#dcfce7" if support == "supported" else "#fef3c7"
        pill_text = "#166534" if support == "supported" else "#92400e"
        scope_rows.append(
            f"""
            <g>
              <rect x="72" y="{row_y + index * 122}" width="920" height="104" rx="20" fill="#f8fafc" />
              <text x="104" y="{row_y + 36 + index * 122}" font-size="28" font-weight="700" fill="#0f172a">{escape(display_name)}</text>
              <text x="104" y="{row_y + 72 + index * 122}" font-size="20" fill="#64748b">{escape(path)}</text>
              <rect x="704" y="{row_y + 20 + index * 122}" width="108" height="34" rx="17" fill="#e2e8f0" />
              <text x="758" y="{row_y + 43 + index * 122}" text-anchor="middle" font-size="16" font-weight="700" fill="#334155">{escape(mode)}</text>
              <rect x="830" y="{row_y + 20 + index * 122}" width="130" height="34" rx="17" fill="{pill_fill}" />
              <text x="895" y="{row_y + 43 + index * 122}" text-anchor="middle" font-size="16" font-weight="700" fill="{pill_text}">{escape(support.title())}</text>
              <text x="704" y="{row_y + 82 + index * 122}" font-size="18" fill="#64748b">Artefacts</text>
              <text x="808" y="{row_y + 82 + index * 122}" font-size="24" font-weight="700" fill="#0f172a">{matched}</text>
              <text x="864" y="{row_y + 82 + index * 122}" font-size="18" fill="#64748b">Impact</text>
              <text x="936" y="{row_y + 82 + index * 122}" font-size="24" font-weight="700" fill="#0f172a">{escape(format_bytes(bytes_value))}</text>
            </g>
            """
        )

    warning_text = warnings[0]["message"] if warnings else "No inventory warnings captured in the latest cached snapshot."
    warning_text = truncate_middle(warning_text, 108)

    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{WIDTH}" height="{HEIGHT}" viewBox="0 0 {WIDTH} {HEIGHT}">
  <rect width="100%" height="100%" fill="#f2efe8" />
  <rect x="36" y="32" width="1528" height="936" rx="36" fill="#fbfaf6" />
  <rect x="72" y="72" width="1456" height="132" rx="28" fill="#0f172a" />
  <text x="112" y="128" font-size="42" font-weight="700" fill="#f8fafc">Google Drive Icon Guard</text>
  <text x="112" y="168" font-size="22" fill="#cbd5e1">Audit-first macOS preview from the latest cached Drive scope inventory</text>
  <rect x="1162" y="106" width="320" height="46" rx="23" fill="#fef3c7" />
  <text x="1322" y="136" text-anchor="middle" font-size="18" font-weight="700" fill="#92400e">ACTIVE BETA · NO LIVE ES HOST YET</text>

  {card(72, 232, 208, 110, "Detected scopes", str(len(scopes)))}
  {card(296, 232, 208, 110, "Supported", str(supported), "#166534")}
  {card(520, 232, 208, 110, "Audit only", str(audit_only), "#92400e")}
  {card(744, 232, 232, 110, "Matched artefacts", str(artefacts.get("totalArtefactCount", 0)), "#991b1b")}
  {card(992, 232, 244, 110, "Disk impact", format_bytes(artefacts.get("totalBytes", 0)), "#7c2d12")}
  {card(1252, 232, 276, 110, "Warnings", str(len(warnings)), "#7c3aed")}

  <text x="72" y="360" font-size="28" font-weight="700" fill="#0f172a">Latest scope review</text>
  {''.join(scope_rows)}

  <rect x="1032" y="378" width="496" height="458" rx="28" fill="#0f172a" />
  <text x="1070" y="428" font-size="28" font-weight="700" fill="#f8fafc">Tester notes</text>
  <text x="1070" y="464" font-size="20" fill="#cbd5e1">Generated from the repo's cached inventory snapshot</text>

  <rect x="1070" y="496" width="420" height="76" rx="22" fill="#111827" stroke="#334155" />
  <text x="1100" y="528" font-size="18" fill="#94a3b8">Current runtime lane</text>
  <text x="1100" y="560" font-size="24" font-weight="700" fill="#f8fafc">LaunchAgent helper path only</text>

  <rect x="1070" y="592" width="420" height="76" rx="22" fill="#111827" stroke="#334155" />
  <text x="1100" y="624" font-size="18" fill="#94a3b8">What testers should validate</text>
  <text x="1100" y="656" font-size="24" font-weight="700" fill="#f8fafc">Discovery, findings, export, packaging</text>

  <rect x="1070" y="688" width="420" height="102" rx="22" fill="#1e293b" />
  <text x="1100" y="722" font-size="18" fill="#fbbf24">Known release warning</text>
  <text x="1100" y="756" font-size="20" font-weight="700" fill="#f8fafc">{escape(truncate_middle(warning_text, 62))}</text>
  <text x="1100" y="782" font-size="16" fill="#cbd5e1">Helper lifecycle is testable. Endpoint Security host entitlement is still pending.</text>

  <text x="1070" y="872" font-size="18" fill="#64748b">Snapshot generated</text>
  <text x="1070" y="902" font-size="22" font-weight="700" fill="#0f172a">{escape(generated_at)}</text>
</svg>
"""


def findings_svg(report: dict) -> str:
    artefacts = report.get("artefactInventory", {})
    results = sorted(
        artefacts.get("scopeResults", []),
        key=lambda item: item.get("matchedArtefactCount", 0),
        reverse=True,
    )
    generated_at = artefacts.get("generatedAt", "").replace("T", " ").replace("Z", " UTC")
    total = artefacts.get("totalArtefactCount", 0)
    total_bytes = artefacts.get("totalBytes", 0)

    bars = []
    max_count = max((item.get("matchedArtefactCount", 0) for item in results), default=1)
    for index, item in enumerate(results[:4]):
        name = item.get("scopeDisplayName", "Unknown")
        count = item.get("matchedArtefactCount", 0)
        matched_bytes = item.get("matchedBytes", 0)
        width = int(520 * (count / max_count)) if max_count else 0
        bars.append(
            f"""
            <g>
              <text x="92" y="{332 + index * 118}" font-size="28" font-weight="700" fill="#0f172a">{escape(name)}</text>
              <rect x="92" y="{354 + index * 118}" width="540" height="22" rx="11" fill="#e2e8f0" />
              <rect x="92" y="{354 + index * 118}" width="{width}" height="22" rx="11" fill="#0f766e" />
              <text x="92" y="{410 + index * 118}" font-size="20" fill="#475569">{count} artefacts · {escape(format_bytes(matched_bytes))}</text>
            </g>
            """
        )

    top_matches = []
    sample_matches = results[0].get("sampleMatches", [])[:4] if results else []
    for index, match in enumerate(sample_matches):
        top_matches.append(
            f"""
            <g>
              <circle cx="934" cy="{455 + index * 84}" r="8" fill="#dc2626" />
              <text x="958" y="{462 + index * 84}" font-size="22" fill="#0f172a">{escape(truncate_middle(match.get('relativePath', ''), 44))}</text>
              <text x="958" y="{492 + index * 84}" font-size="18" fill="#64748b">{escape(match.get('ruleName', 'Unknown rule'))} · {escape(format_bytes(match.get('sizeBytes', 0)))}</text>
            </g>
            """
        )

    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{WIDTH}" height="{HEIGHT}" viewBox="0 0 {WIDTH} {HEIGHT}">
  <rect width="100%" height="100%" fill="#e8efe8" />
  <rect x="36" y="32" width="1528" height="936" rx="36" fill="#ffffff" />
  <rect x="72" y="72" width="1456" height="132" rx="28" fill="#123524" />
  <text x="112" y="128" font-size="42" font-weight="700" fill="#f0fdf4">Findings preview</text>
  <text x="112" y="168" font-size="22" fill="#d1fae5">Representative artefact hotspots from the latest cached Google Drive inventory snapshot</text>
  <rect x="1230" y="108" width="252" height="42" rx="21" fill="#dcfce7" />
  <text x="1356" y="136" text-anchor="middle" font-size="18" font-weight="700" fill="#166534">TESTER BUILD</text>

  {card(72, 228, 300, 110, "Total hidden artefacts", str(total), "#991b1b")}
  {card(392, 228, 280, 110, "Total disk impact", format_bytes(total_bytes), "#7c2d12")}
  {card(692, 228, 300, 110, "Largest hotspot", results[0].get("scopeDisplayName", "None") if results else "None", "#123524")}

  {''.join(bars)}

  <rect x="836" y="378" width="646" height="410" rx="30" fill="#f8fafc" />
  <text x="884" y="430" font-size="28" font-weight="700" fill="#0f172a">Sample matched paths</text>
  {''.join(top_matches)}

  <rect x="836" y="808" width="310" height="92" rx="24" fill="#f8fafc" />
  <text x="868" y="844" font-size="18" fill="#64748b">Generated</text>
  <text x="868" y="878" font-size="24" font-weight="700" fill="#0f172a">{escape(generated_at)}</text>

  <rect x="1172" y="808" width="310" height="92" rx="24" fill="#fef3c7" />
  <text x="1327" y="862" text-anchor="middle" font-size="18" font-weight="700" fill="#92400e">Current release promise remains audit-first, not true live prevention.</text>
</svg>
"""


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    report = load_report()

    dashboard_svg_path = OUTPUT_DIR / "release-dashboard-preview.svg"
    findings_svg_path = OUTPUT_DIR / "release-findings-preview.svg"
    dashboard_png_path = OUTPUT_DIR / "release-dashboard-preview.png"
    findings_png_path = OUTPUT_DIR / "release-findings-preview.png"

    dashboard_svg_path.write_text(dashboard_svg(report), encoding="utf-8")
    findings_svg_path.write_text(findings_svg(report), encoding="utf-8")

    write_png(dashboard_svg_path, dashboard_png_path)
    write_png(findings_svg_path, findings_png_path)

    print(dashboard_png_path)
    print(findings_png_path)


if __name__ == "__main__":
    main()
