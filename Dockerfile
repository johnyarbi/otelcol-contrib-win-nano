# escape=`

# --- Versions you can override at build time -------------------------------
ARG NANO_RELEASE=ltsc2022
ARG OTEL_VERSION=0.138.0
ARG BUILD_VERSION=2025.11.1.1

# --- Stage 1: fetch + stage OpenTelemetry Collector (contrib) --------------
FROM mcr.microsoft.com/windows/nanoserver:${NANO_RELEASE} AS builder
ARG OTEL_VERSION

ADD https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v${OTEL_VERSION}/otelcol-contrib_${OTEL_VERSION}_windows_amd64.tar.gz C:\stage\otelcol.tar.gz

SHELL ["cmd","/S","/C"]
RUN mkdir C:\otel && `
    tar -xf C:\stage\otelcol.tar.gz -C C:\stage && `
    move /Y C:\stage\otelcol-contrib.exe C:\otel\otelcol-contrib.exe >nul && `
    rmdir /S /Q C:\stage

# --- Stage 2: final runtime image (pure NanoServer) ----
FROM mcr.microsoft.com/windows/nanoserver:${NANO_RELEASE}
ARG NANO_RELEASE
ARG OTEL_VERSION
ARG BUILD_VERSION

COPY ["include/otel/config.yaml", "C:/otel/config.yaml"]
COPY --from=builder ["C:/otel/otelcol-contrib.exe", "C:/otel/otelcol-contrib.exe"]

ENV OS_TYPE=windows `
    OTEL_EXPORTER_OTLP_ENDPOINT_HOST=otelrelay `
    OTEL_EXPORTER_OTLP_ENDPOINT_PORT=4317 `
    OTEL_EXPORTER_OTLP_ENDPOINT_TLS_INSECURE=true `
    OTEL_EXPORTER_DEBUG_VERBOSITY=basic `
    OTEL_INTERNAL_TELEMETRY_LOGS_LEVEL=info `
    OTEL_INTERNAL_TELEMETRY_METRICS_LEVEL_VERBOSITY=basic `
    OTEL_INTERNAL_TELEMETRY_OTLP_ENDPOINT=http://otelrelay:4318 `
    OTEL_INTERNAL_TELEMETRY_OTLP_PROTOCOL=http/protobuf `
    OTEL_DEFAULT_EXPORTERS="[otlp, debug]"

ENV NANO_RELEASE=${NANO_RELEASE}
ENV OTEL_VERSION=${OTEL_VERSION}
ENV BUILD_VERSION=${BUILD_VERSION}

ENTRYPOINT ["cmd", "/S", "/C", "cd C:\\otel && otelcol-contrib.exe --config=config.yaml"]
