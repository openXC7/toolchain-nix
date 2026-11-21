# The database the chipdb generator and the bitstream tools all read.
#
# Pinned to the openXC7/prjxray-db tip.  Since the revision openXC7/nextpnr's
# own CI still names (b12466df, PRJXRAY_DB_REV), the database gained #37-#44:
# ICAP.IN_USE in cfg_center_mid for every family, the zynq7 MMCM CLKFBIN bit
# 28_1015, the IBUFDS_GTE2 ODIV2 select into MGTCLKOUT, the xc7z045 HR-bank
# pins, part directories for the 30 parts of parts.yaml that had none, and
# real part.yaml/part.json for the xc7s25csga225 parts.
#
# The engine's CI revision is older than this tip because its workflow pins a
# reproducible database, not a compatibility boundary; the database format is
# unchanged and these commits add parts and fix bit rows.
{ lib, fetchFromGitHub }:

fetchFromGitHub {
  owner = "openXC7";
  repo = "prjxray-db";
  rev = "0c3504f26f5cf77b6a7605c7bc83ebe1ac67b26f";
  hash = "sha256-uLIT9tYF27J1woaov7bcERh/on3wmIUSPfoktRe/ISU=";
}
