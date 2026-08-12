FROM --platform=linux/amd64 ubuntu:24.04

RUN apt-get update && apt-get install -y --no-install-recommends \
  curl build-essential pkg-config libssl-dev git ca-certificates && \
  rm -rf /var/lib/apt/lists/*

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

RUN cargo install cargo-codspeed && \
  curl -fsSL https://codspeed.io/install.sh | sh && \
  git config --global --add safe.directory /app

WORKDIR /app

CMD ["bash"]
