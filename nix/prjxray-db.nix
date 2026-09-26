# The database the chipdb generator and the bitstream tools all read.
#
# Pinned to the revision openXC7/nextpnr's own CI uses (PRJXRAY_DB_REV in
# .github/workflows/demos.yml), so the chipdb, fasm2frames and xc7frames2bit
# in one devshell agree on one database.
{ lib, fetchFromGitHub }:

fetchFromGitHub {
  owner = "openXC7";
  repo = "prjxray-db";
  rev = "517d66a383676cb971177ea92b0ff3b6ea6e8690";
  hash = "sha256-CA6Lz5sA3Mebusu5lGeM1oW9w5dz8GIjYyFy611SOks=";
}
