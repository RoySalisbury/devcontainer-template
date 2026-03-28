# Use base:ubuntu so the dotnet feature controls the exact SDK version.
# Avoids: (1) stale RC builds in dotnet:1-X.0, (2) Yarn APT source signing bug.
FROM mcr.microsoft.com/devcontainers/base:ubuntu

# Restore NuGet XML docs for richer IntelliSense tooltips.
ENV NUGET_XMLDOC_MODE=
