include <BOSL2/std.scad>

// ------------------------------------------------------------
// The Belfry OpenSCAD Library V2
// https://github.com/revarbat/BOSL2
// License: BSD 2-Clause
// ------------------------------------------------------------

////////////////////////////////////////////////////////////////////
// Design Overview:
//
// Generates a mesh-filled rectangular case base with optional
// stacking pillars and standoff pegs for boards.
//
// Components:
// - Hexagonal grid (hollow cells)
// - Outer pillars with optional pegs/holes
// - Optional standoffs with pegs
//
// Use `main()` to render the full case.
// Global parameters control size, spacing, pegs, etc.
//
////////////////////////////////////////////////////////////////////

/* [Case] */
// Base dimensions of the case [x, y, z]
case_base = [100.0, 75, 3];
// Width across flats of each hex hole
hex_size = 4; // [1:0.1:10]
// Wall thickness between each hex
hex_spacing = 1; // [0.1:0.1:5]
// Radius of base pillars
pillar_base_r = 3.0; // [1:0.1:10]
// Height of base pillars
pillar_base_h = 32; // [1:1:50]
// Peg radius at top of pillar
pillar_peg_r = 1.5; // [0.5:0.1:5]
// Peg height at top of pillar
pillar_peg_h = 2.5; // [0.5:0.1:5]
// Clearance height added to peg hole
pillar_clearance_h = 0.1; // [0.01:0.01:1]
// Clearance radius added to peg hole
pillar_clearance_r = 0.1; // [0.01:0.01:1]

/* [Standoffs] */
// Spacing between standoffs [x, y]
standoff_size = [58.0, 49.0];
// Radius of standoff base
standoff_base_r = 4; // [1:0.1:10]
// Height of standoff base
standoff_base_h = 1; // [0.1:0.1:5]
// Radius of standoff peg
standoff_peg_r = 1; // [0.1:0.1:5]
// Height of standoff peg
standoff_peg_h = 1; // [0.1:0.1:5]
// X offset for standoff grid
standoff_offset_x = 10.0; // [-20:1:20]
// Y offset for standoff grid
standoff_offset_y = 0; // [-20:1:20]

/* [Other] */
// True if this is the top piece
isTop = false;
// True if this is the bottom piece
isBottom = false;

/* [Global Settings] */
// Default resolution for rounded geometry
resolution = 64;
// Small tolerance used to avoid artifacts
tol = 0.001;


////////////////////////////////////////////////////////////////////
// cell():
//   Creates a single hexagonal prism (a cell) with a hollow center.
//
// Parameters:
//   diameter: Width across flats of the inner hexagon.
//   height:  Height (depth) of the cell (Z-axis).
//   wall:    Thickness of the wall surrounding the inner hex hole.
//
// Notes:
//   Outer hex size = diameter + 2 * wall.
////////////////////////////////////////////////////////////////////
module cell(diameter, height, wall) {
	difference() {
		cyl(d = diameter + 2 * wall, h = height, $fn = 6, circum = true);
		cyl(d = diameter, h = height + tol, $fn = 6, circum = true);
	}
}

////////////////////////////////////////////////////////////////////
// grid():
//   Generates a staggered hexagonal grid of cells.
//
// Parameters:
//   size:       [x, y, z] dimensions of the area to fill.
//   cell_hole:  Inner hex width across flats.
//   cell_wall:  Wall thickness around each hex.
////////////////////////////////////////////////////////////////////
module grid(size, cell_hole, cell_wall) {
	dx = cell_hole * sqrt(3) + cell_wall * sqrt(3);
	dy = cell_hole + cell_wall;

	ycopies(spacing = dy, l = size[1])
	xcopies(spacing = dx, l = size[0]) {
		cell(diameter = cell_hole, height = size[2], wall = cell_wall);
		right(dx / 2)
		fwd(dy / 2)
		cell(diameter = cell_hole, height = size[2], wall = cell_wall);
	}
}

////////////////////////////////////////////////////////////////////
// mask():
//   Used to clip the hex grid to the desired area, removing overhangs.
//
// Parameters:
//   size: [x, y, z] dimensions of the clipping cuboid.
////////////////////////////////////////////////////////////////////
module mask(size) {
	difference() {
		cuboid(size = 2 * size);
		cuboid(size = [size[0], size[1], size[2]]);
	}
}

////////////////////////////////////////////////////////////////////
// create_grid():
//   Builds a rectangular box with an inset hex grid cutout.
//
// Parameters:
//   size:      [x, y, z] size of the outer shell.
//   diameter:  Width across flats of each hex hole.
//   wall:      Wall thickness between hexes.
//   padding:   Extra padding to shrink the mesh within the shell.
//   rounding:  Optional rounding radius for outer shell corners.
////////////////////////////////////////////////////////////////////
module create_grid(size, diameter, wall, padding, rounding = 0) {
	mesh_size = [size[0] - padding, size[1] - padding, size[2] + 2 * tol];

	translate([0, 0, size[2] / 2]) {
		union() {
			// Shell with central cutout
			difference() {
				cuboid(size = size, rounding = rounding, edges = ["Z"], $fn = resolution);
				cuboid(size = mesh_size);
			}
			// Inner mesh
			difference() {
				grid(size, diameter, wall);
				mask(mesh_size);
			}
		}
	}
}

////////////////////////////////////////////////////////////////////
// pillar_box():
//   Places four cylindrical pillars at the corners of a rectangle,
//   with optional offset adjustment.
//
// Parameters:
//   box_size:  [x, y] dimensions of the rectangle.
//   radius:    Radius of each pillar.
//   height:    Height of each pillar.
//   offset_x:  X-axis offset (default: 0).
//   offset_y:  Y-axis offset (default: 0).
////////////////////////////////////////////////////////////////////
module pillar_box(box_size, radius, height, offset_x = 0, offset_y = 0, offset_z=0) {
	spacing_x = box_size[0] / 2;
	spacing_y = box_size[1] / 2;

	for (pos = [[spacing_x, spacing_y], [-spacing_x, spacing_y], [-spacing_x, -spacing_y], [spacing_x, -spacing_y]]) {
		translate([pos[0] + offset_x, pos[1] + offset_y, offset_z])
			cyl(d = radius * 2, h = height, anchor = BOTTOM, $fn = resolution);
	}
}

////////////////////////////////////////////////////////////////////
// main():
//   Assembles the full model based on global parameters.
//
// Notes:
//   - Set `isTop`/`isBottom` to toggle pegs/holes.
//   - Run this module to generate the part.
////////////////////////////////////////////////////////////////////
module main() {
	pillar_base_d = 2 * pillar_base_r;
	grid_size = [case_base[0], case_base[1], case_base[2]];
	pillar_size = [case_base[0] - pillar_base_d, case_base[1] - pillar_base_d];

	union() {
		difference() {
			union() {
				// Create main hex-mesh base
				create_grid(grid_size, hex_size, hex_spacing, padding = pillar_base_d * 2, rounding = pillar_base_r);

				if (!isTop) {
					// Tall outer pillars
					pillar_box(pillar_size, pillar_base_r, pillar_base_h);
				}
			}
			union() {
				if (!isBottom) {
					// Peg holes (underside)
					up(-tol)
						pillar_box(
							pillar_size,
							pillar_peg_r + pillar_clearance_r,
							pillar_peg_h + pillar_clearance_h + tol
						);
				}
				if (!isTop) {
					// Workaround for: WARNING: Object may not be a valid 2-manifold and may need repair!
					pillar_box(
						standoff_size,
						// Slightly enlarging the subtracted standoff base radius:
						standoff_base_r + tol/100,
						standoff_base_h + case_base[2],
						offset_x = standoff_offset_x,
						offset_y = standoff_offset_y,
					);
				}
			}
		}

		if (!isTop) {
			// Pegs on top of each pillar
			up(pillar_base_h)
				pillar_box(pillar_size, pillar_peg_r, pillar_peg_h);
			union() {
				// Standoff bases
				pillar_box(
					standoff_size,
					standoff_base_r,
					standoff_base_h + case_base[2],
					offset_x = standoff_offset_x,
					offset_y = standoff_offset_y
				);
				// Standoff pegs
				up(standoff_base_h + case_base[2])
					pillar_box(
						standoff_size,
						standoff_peg_r,
						standoff_peg_h,
						offset_x = standoff_offset_x,
						offset_y = standoff_offset_y
					);
			}

		}
	}
}

// Generate the part
main();

