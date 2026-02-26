FROM mcr.microsoft.com/devcontainers/ruby:bullseye
RUN sudo apt-get update && sudo apt-get install -y policycoreutils selinux-basics checkpolicy selinux-policy-dev auditd
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
       > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y gh && rm -rf /var/lib/apt/lists/*

RUN npm install -g @anthropic-ai/claude-code

USER vscode
RUN mkdir -p ~/bin
RUN curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to ~/bin
RUN export PATH="$PATH:$HOME/bin"
