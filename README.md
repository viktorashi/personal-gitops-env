# my personal GitOps with whatever clouds / onprems ill be connected to

```sh
mise bootstrap
mise run check
```

- Check tools and tasks: [mise.toml](mise.toml)
- Operational tools: [.mise/conf.d/ops.toml](.mise/conf.d/ops.toml)
- Editor tools: [.mise/conf.d/editor.toml](.mise/conf.d/editor.toml)
- Formatters, linters and validation: [prek.toml](prek.toml)
- CI: [.github/workflows/check.yml](.github/workflows/check.yml)
- Infrastructure: [infra/README.md](infra/README.md)
- Argo CD and notes: [cluster/README.md](cluster/README.md)

Foundation is basically bootstrapping
