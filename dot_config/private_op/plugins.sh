export OP_PLUGIN_ALIASES_SOURCED=1
agent() {
    op plugin run -- agent "$@"
}
aws() {
    op plugin run -- aws "$@"
}
brew() {
    op plugin run -- brew "$@"
}
codex() {
    op plugin run -- codex "$@"
}
copilot() {
    op plugin run -- copilot "$@"
}
gemini() {
    op plugin run -- gemini "$@"
}
gh() {
    op plugin run -- gh "$@"
}
openai() {
    op plugin run -- openai "$@"
}
stripe() {
    op plugin run -- stripe "$@"
}
vercel() {
    op plugin run -- vercel "$@"
}
wrangler() {
    op plugin run -- wrangler "$@"
}
zapier() {
    op plugin run -- zapier "$@"
}
