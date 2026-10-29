FROM rocker/r-ver:4.6.1

# System libraries commonly needed by widely-used R packages (sf, terra, cpp11, httr2, ragg).
RUN apt-get update && apt-get install -y --no-install-recommends \
      libssl-dev libxml2-dev libcurl4-openssl-dev libgit2-dev \
      libgdal-dev libproj-dev libgeos-dev libudunits2-dev \
      libfontconfig1-dev libharfbuzz-dev libfribidi-dev \
      libfreetype6-dev libpng-dev libtiff5-dev libjpeg-dev \
      pandoc git sudo \
 && apt-get clean

# Quarto (long-form documentation engine — books, websites, papers).
# Vignette default is still `knitr::rmarkdown` on .Rmd files for CRAN-floor
# compatibility (R CMD check --as-cran does not register `.qmd` as a
# first-class vignette engine). Quarto is installed here so devcontainer
# users can author Quarto docs without leaving the container.
ARG QUARTO_VERSION=1.5.57
RUN curl -fsSL -o /tmp/quarto.deb "https://github.com/quarto-dev/quarto-cli/releases/download/v$QUARTO_VERSION/quarto-$QUARTO_VERSION-linux-amd64.deb" \
 && dpkg -i /tmp/quarto.deb

ARG USERNAME=rstudio
ARG USER_UID=1000
RUN useradd --uid $USER_UID -m -s /bin/bash $USERNAME

USER $USERNAME
WORKDIR /workspaces/flexyBayesOrchestra

RUN R -e "install.packages(c('pak','renv','devtools','languageserver'), repos = 'https://packagemanager.posit.co/cran/__linux__/jammy/latest')"
