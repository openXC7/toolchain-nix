# The database the chipdb generator and the bitstream tools all read.
#
# Pinned to the revision openXC7/nextpnr's own CI uses (PRJXRAY_DB_REV in
# .github/workflows/demos.yml), so the chipdb, fasm2frames and xc7frames2bit
# in one devshell agree on one database.
#
# b12466df is the merge of openXC7/prjxray-db#36 (the zynq7 and kintex7 RIOB18
# drive rows); the only commit on top of it, #37, changes .github/ alone, so
# taking the engine's revision rather than the branch tip costs no database
# content.
{ lib, fetchFromGitHub }:

fetchFromGitHub {
  owner = "openXC7";
  repo = "prjxray-db";
  rev = "b12466df16ecb6fe194fe436ec020ac08d32d61e";
  hash = "sha256-+l8b5kUxQE57M1L73D2jxzfVSbs45mu3AEIhPvIEYZI=";
}
