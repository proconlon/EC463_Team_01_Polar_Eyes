# Hardware Plan

This directory is the canonical home for all hardware design assets (electrical + mechanical, if present).

## Structure

- `kicad/` - KiCad source files (`.kicad_pro`, `.kicad_sch`, `.kicad_pcb`, symbol/footprint libs)
- `exports/` - rendered exports (schematic PNG/PDF, PCB render PNG, fabrication plots)
- `datasheets/` - component datasheets used in the design
- `bom/` - bill of materials and procurement notes

## Portfolio-Ready Minimum

To make this repo resume-ready, prioritize adding:

1. KiCad source project in `kicad/`
2. Schematic PDF/PNG in `exports/`
3. PCB top/bottom or 3D render in `exports/`
4. BOM CSV in `bom/`
5. Any calibration or wiring notes as markdown in this folder

When you find legacy files, drop them into the right subdirectory and update this README with a quick index.
