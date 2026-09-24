# The database the chipdb generator and the bitstream tools all read.
#
# Pinned to the revision openXC7/nextpnr's own CI uses (PRJXRAY_DB_REV in
# .github/workflows/demos.yml), so the chipdb, fasm2frames and xc7frames2bit
# in one devshell agree on one database.
{ lib, fetchFromGitHub }:

fetchFromGitHub {
  owner = "openXC7";
  repo = "prjxray-db";
  rev = "a90f27c1caefee5276f47440f4c730b50519a86f";
  hash = "sha256-EugZWK38rwLkhbp81eX/+kr4vrqdzRQuDbLpPn6ij7U=";
}
