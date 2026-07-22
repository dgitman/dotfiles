export OP_PLUGIN_ALIASES_SOURCED=1
agent() {
    op plugin run -- agent "$@"
}
claude() {
    op plugin run -- claude "$@"
}
gh() {
    op plugin run -- gh "$@"
}
openai() {
    op plugin run -- openai "$@"
}
