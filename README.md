# Coarsests Subdivisions of Hypersimplices

This repository contains the data and code necessary to reproduce the results
of [[1]](#1).

## Data
### Delta(2,7)
### Delta(3,6)

## Code
The triangulations are produced by mptopcom [[3]](#3) and then processed by
polymake [[2]](#2) scripts.
### rays_of_sec_cones.pl
This script gets as input an input and an output file of mptopcom. The input
file is necessary to ensure that the script works with the same group and point
configuration as mptopcom. The output is a polymake data file containing a set
of vectors. These vectors are the rays of the secondary cones of the
triangulations in the mptopcom output. Since the group acts on the
triangulations and thereby on the rays, there is only one representative per
ray orbit.

### process_rays.pl
For large output of mptopcom it makes sense to split it into chunks and run
_rays_of_sec_cones.pl_ separately on every chunk. This script unifies the
intermediate results and does additional postprocessing:
- It associates an ID to every ray representative
- It produces a histogram of how many rays exhibit a given spread.

## References
<a id="1">[1]</a> 
Laura Casabelle, Michael Joswig, Lars Kastner:
Coarsest Subdivisions of Hypersimplices.
[arxiv](link).

<a id="2">[2]</a>
[polymake](https://polymake.org/) -- open source software for research in
polyhedral geometry.

<a id="3">[3]</a>
[mptopcom](https://polymake.org/mptopcom)
