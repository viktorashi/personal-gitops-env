# my personal GitOps with whatever clouds / onprems ill be connected to

```sh
mise bootstrap
mise run check
```

- Check tools and tasks: [mise.toml](mise.toml)
- Operational tools (`mise -E ops`): [mise.ops.toml](mise.ops.toml)
- Editor tools (`mise -E editor`): [mise.editor.toml](mise.editor.toml)
- Formatters, linters and validation: [prek.toml](prek.toml)
- CI: [.github/workflows/check.yml](.github/workflows/check.yml)
- Infrastructure: [infra/README.md](infra/README.md)

Foundation is basically bootstrapping
