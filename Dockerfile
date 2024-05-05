# encodingtools

# Use archlinux:base-devel for our base build image
FROM ghcr.io/archlinux/archlinux:base-devel as build

# Update
RUN pacman -Syu --noconfirm

# Install build packages
RUN pacman -Sy --noconfirm \
        rust \
        ninja \
        git

# Compile and install ab-av1 git
RUN cargo install --git https://github.com/alexheretic/ab-av1

# Add a new builder user for makepkg
RUN useradd -m builder && \
    # Allow builder user to run sudo without a password
    # Required to install makepkg build dependencies
    echo "builder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/builder

# Set the working directory to /home/builder
WORKDIR /home/builder

# Switch to the builder user context
USER builder

# Clone AUR packages
RUN git clone https://aur.archlinux.org/svt-av1-psy-git.git && \
    git clone https://aur.archlinux.org/ffmpeg-git.git

# Build svt-av1-psy-git
WORKDIR /home/builder/svt-av1-psy-git
RUN MAKEFLAGS="-j$(nproc)" \
    makepkg -s --nocheck --noconfirm && \
    rm -f *debug*.pkg.tar.zst

# Build ffmpeg-git
WORKDIR /home/builder/ffmpeg-git
RUN MAKEFLAGS="-j$(nproc)" \
    makepkg -s --nocheck --noconfirm && \
    rm -f *debug*.pkg.tar.zst

# Use archlinux for our base runtime image
FROM ghcr.io/archlinux/archlinux:latest as runtime

# Set the working directory to /app
WORKDIR /app

# Copy from build container
COPY --from=build /root/.cargo/bin/ab-av1 .
COPY --from=build /home/builder/svt-av1-psy-git/*.pkg.tar.zst .
COPY --from=build /home/builder/ffmpeg-git/*.pkg.tar.zst .

# Update
RUN pacman -Syu --noconfirm && \
# Install runtime packages
    pacman -Sy --noconfirm \
        libopusenc && \
# Install AUR packages
    pacman -U --noconfirm \
        *.pkg.tar.zst && \
# Cleanup
    pacman -Scc --noconfirm && \
    rm -f *.pkg.tar.zst

ENTRYPOINT ["/app/ab-av1"]