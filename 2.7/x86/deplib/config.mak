TARGET = i386-linux-musl
GCC_VER = 15.1.0
MUSL_VER = 1.2.5
COMMON_CONFIG += CFLAGS="-g0 -O3" CXXFLAGS="-g0 -O3" LDFLAGS="-s"
GCC_CONFIG += --enable-default-pie --enable-static-pie

# Override musl-cross-make's default GNU_SITE = https://ftpmirror.gnu.org/gnu
# — the redirector is fast but routes to community mirrors that periodically
# return 502 Bad Gateway, killing the entire build. kernel.org's GNU mirror
# is anycast-fronted and one of the most reliable on the public internet.
# Affects binutils, gmp, mpc, mpfr, gcc (all ${GNU_SITE}/<pkg>).
GNU_SITE = https://mirrors.kernel.org/gnu
