# Migracao Windows -> CachyOS (5 etapas)

## Etapa 1 - Auditoria do Windows

Executar PowerShell como administrador:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\scripts\01_audit_windows.ps1
```

Saida esperada: pasta `C:\migration-plan\audit-output\<timestamp>` com inventario de apps, runtimes, diretorios e configs.

## Etapa 2 - Scanner de projetos

```powershell
.\scripts\02_scan_projects.ps1 -ProjectPaths @("E:\servidorbadger","E:\gazella") -MaxDepth 4
```

Saida esperada: `projects-full.json`, `projects-summary.json`, `required-toolchains.txt`.

## Etapa 3 - Manifesto unico

Use as duas pastas mais recentes (audit e scan):

```powershell
.\scripts\03_build_manifest.ps1 `
  -AuditFolder "C:\migration-plan\audit-output\<audit_ts>" `
  -ProjectScanFolder "C:\migration-plan\audit-output\<scan_ts>" `
  -OutputFile "C:\migration-plan\migration-manifest.json"
```

## Etapa 4 - Plano instalacao/documentacao

```powershell
.\scripts\04_generate_install_plan.ps1 `
  -ManifestFile "C:\migration-plan\migration-manifest.json" `
  -OutputMarkdown "C:\migration-plan\CACHYOS_INSTALL_PLAN.md"
```

## Etapa 5 - Bootstrap no CachyOS

Copie `scripts/05_postinstall_bootstrap_cachyos.sh` para o Linux e rode:

```bash
chmod +x 05_postinstall_bootstrap_cachyos.sh
./05_postinstall_bootstrap_cachyos.sh
```

---

## O que aconteceu com seu input anterior

- O texto ficou truncado/mesclado no meio (script + output + tabela).
- Isso geralmente acontece por colagem gigante com buffer quebrado.
- Solucao: manter um arquivo por etapa e evitar colar resultados no mesmo bloco do codigo.

## Checklist rapido

- [ ] Validar `00_INDEX.json` da auditoria
- [ ] Validar `projects-summary.json`
- [ ] Revisar apps `manual-review` no manifesto
- [ ] Fazer backup de `.ssh`, `.gnupg`, `.gitconfig`, configs de IDE
- [ ] Testar bootstrap em VM antes da maquina principal
