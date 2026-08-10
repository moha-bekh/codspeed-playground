FROM --platform=linux/amd64 rust:latest

RUN cargo install cargo-codspeed && \
  curl -fsSL https://codspeed.io/install.sh | sh

WORKDIR /app

CMD ["bash"]
