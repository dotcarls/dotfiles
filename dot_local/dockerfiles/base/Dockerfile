# syntax=docker/dockerfile:1
FROM debian:bookworm-20230814-slim as base
ARG USER_NAME=linuxbrew

RUN apt-get update && \
    apt-get install -y -q --no-install-recommends \
        build-essential \
        ca-certificates \
        curl \
        git \
        procps \
        sudo && \
    useradd -r -m -d "/home/${USER_NAME}" -s /bin/bash ${USER_NAME} && \
    usermod -aG sudo ${USER_NAME} && \
    su - ${USER_NAME} -s /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)" && \
    (echo; echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv bash)"') >> /home/${USER_NAME}/.bash_profile && \
    (echo; echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv bash)"') >> /home/${USER_NAME}/.bashrc && \
    (echo; echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv sh)"') >> /home/${USER_NAME}/.profile && \
    (echo; echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv zsh)"') >> /home/${USER_NAME}/.zprofile && \
    (echo; echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv zsh)"') >> /home/${USER_NAME}/.zshrc && \
    (echo; echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv sh)"') >> /etc/profile && \
    (echo; echo 'PATH="$PATH:/home/linuxbrew/.linuxbrew/bin"') >> /etc/profile && \ 
    (echo; echo 'PATH="$PATH:/home/linuxbrew/.linuxbrew/bin"') >> /etc/environment && \ 
    mkdir -p /etc/homebrew && \
    echo 'HOMEBREW_NO_COLOR=1' > /etc/homebrew/brew.env && \
    echo 'HOMEBREW_DISPLAY_INSTALL_TIMES=1' >> /etc/homebrew/brew.env && \
    echo 'HOMEBREW_NO_AUTO_UPDATE=1' >> /etc/homebrew/brew.env && \
    echo 'HOMEBREW_VERBOSE=1' >> /etc/homebrew/brew.env && \
    echo 'HOMEBREW_AUTOREMOVE=1' >> /etc/homebrew/brew.env && \
    echo 'HOMEBREW_BOOTSNAP=1' >> /etc/homebrew/brew.env && \
    chmod a+r /etc/homebrew/brew.env && \
    chown -R ${USER_NAME}: /home/${USER_NAME} 
    
FROM base AS build
ARG USER_NAME=linuxbrew
USER ${USER_NAME}
COPY --chown=${USER_NAME} .local/brewfiles/base /tmp/base
RUN export NONINTERACTIVE=1 && \
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv sh)" && \
    brew bundle --verbose --file /tmp/base/Brewfile --cleanup 

FROM base AS final
ARG USER_NAME=linuxbrew
COPY --from=build /home/linuxbrew/.linuxbrew /home/linuxbrew/.linuxbrew
RUN echo '/home/linuxbrew/.linuxbrew/bin/zsh' >> /etc/shells && \
    chsh -s /home/linuxbrew/.linuxbrew/bin/zsh ${USER_NAME}

USER ${USER_NAME}
WORKDIR /home/${USER_NAME}
CMD ["/home/linuxbrew/.linuxbrew/bin/zsh", "--login"]
# RUN brew bundle --verbose --file /home/${USER_NAME}/.local/brewfiles/base/Brewfile && \
#     brew cleanup --prune=all && \
#     brew cleanup -s && \
#     rm -rf $(brew --cache) && \
#     brew autoremove


# RUN brew bundle --verbose --file /home/${USER_NAME}/.local/brewfiles/identity/Brewfile 