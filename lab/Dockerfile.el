# Systemd-enabled Enterprise Linux image for local testing of the roles.
# Parameterised by BASE so the same file builds EL9 and EL8 (Rocky, multi-arch:
# runs native on arm64 for fast structural tests, or as linux/amd64 (emulated)
# for full installs of x86_64-only RPMs).
ARG BASE=rockylinux/rockylinux:9
FROM ${BASE}

ENV container=docker LANG=C.UTF-8

# systemd (so the service/systemd modules work), python3.11 (Ansible target —
# EL8's default python3 is 3.6, too old for modern ansible-core), plus the small
# tools Ansible facts and the roles expect.
RUN dnf -y install systemd python3.11 sudo procps-ng iproute hostname findutils \
    && dnf clean all \
    && systemctl mask dev-hugepages.mount sys-fs-fuse-connections.mount \
         systemd-logind.service getty.target console-getty.service 2>/dev/null || true

# Clean shutdown of PID 1 = systemd.
STOPSIGNAL SIGRTMIN+3
CMD ["/sbin/init"]
