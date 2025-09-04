FROM mcr.microsoft.com/devcontainers/base:bullseye
RUN sudo apt-get update && sudo apt-get install -y policycoreutils selinux-basics checkpolicy selinux-policy-dev auditd
USER vscode
RUN mkdir -p ~/bin
RUN curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to ~/bin
RUN export PATH="$PATH:$HOME/bin"
