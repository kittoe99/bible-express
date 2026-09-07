# Cloud Agent development image for Bible Xpress (Flutter web).
# Installs a pinned Flutter SDK so `flutter pub get`, analyze, test, and the
# web dev server all work out of the box. The production image lives in the
# repository-root Dockerfile; this one is for interactive development only.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# System packages Flutter needs to download tooling and build for the web.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        git \
        unzip \
        xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Pin the Flutter SDK version. Bump this to move the whole environment forward.
ARG FLUTTER_VERSION=3.47.2

RUN curl -fSL -o /tmp/flutter.tar.xz \
        "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
    && tar -xf /tmp/flutter.tar.xz -C /opt \
    && rm /tmp/flutter.tar.xz \
    && chown -R ubuntu:ubuntu /opt/flutter

ENV PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Mark the SDK checkout as trusted for every user (Flutter shells out to git).
RUN git config --system --add safe.directory /opt/flutter

# Run the remaining setup as the runtime user so all generated Flutter state
# under /opt/flutter (bin/cache, flutter_tools/.dart_tool, ...) is owned by
# `ubuntu`. Doing this as root would leave root-owned files the agent can't write.
USER ubuntu

# Warm the web toolchain so the first `flutter` invocation in an agent is fast.
RUN flutter config --enable-web --no-analytics \
    && flutter precache --universal --web \
    && flutter --version
