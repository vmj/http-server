# Debian and Slackware are functional.
# Debian Stretch works, 57.1MB
FROM debian:stretch-slim
# Slackare 14.[12] works, 84.8MB
#FROM vbatts/slackware:14.1

# None of these small distros work.

# 3.99MB; does not have glibc.
#FROM alpine:3.5

# 4.2MB; does not have libz.
#FROM busybox:glibc

# 4.23MB; has libz but mixes libuClibc and libgcc...
#FROM radial/busyboxplus:curl

# 7.32MB; seems to have all the libs, but
# $ /app/bin/java --version
# sh: /app/bin/java: not found
#FROM tatsushid/tinycore:7.2-x86_64

# 10.7MB; has glibc but "__rawmemchr: symbol not found"
#FROM frolvlad/alpine-glibc:alpine-3.5_glibc-2.25

MAINTAINER Mikko Värri "vmj@linuxbox.fi"
COPY linux /app
CMD ["/app/bin/java", "-m", "http.server"]
