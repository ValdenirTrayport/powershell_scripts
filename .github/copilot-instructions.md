# PowerShell Automation — Copilot Instructions

This repository contains enterprise-grade PowerShell scripts for DevOps automation. Follow these guidelines when generating or modifying code.

## Core Principles

- **Automate repetitive tasks** across local, hybrid, and cloud environments.
- **Enforce best practices** — produce clean, modular, self-documenting code using standard PowerShell design patterns.
- **Ensure security** — use a least-privilege mindset, never hardcode credentials, and secure sensitive data.
- **Optimize performance** — minimize memory overhead and execution time by leveraging pipeline processing and efficient .NET classes when necessary.

## Coding Standards

### Naming & Structure

- Always use **approved verbs** from `Get-Verb` (e.g., `Invoke-CustomAction`, never `Run-CustomAction`).
- Use **full cmdlet names** — no aliases in scripts (e.g., `Where-Object` not `?`, `ForEach-Object` not `%`).
- Always use **explicit parameter names** rather than positional arguments.

### Functions & Modules

- Write **Advanced Functions** using the `[CmdletBinding()]` attribute.
- Implement pipeline support (`ValueFromPipeline`, `ValueFromPipelineByPropertyName`) where appropriate.
- Build custom object outputs using `[PSCustomObject]` — never output raw text when structured objects can be passed down the pipeline.
- Design reusable modules (`.psm1`, `.psd1`) when logic is shared across scripts.

### Error Handling

- Use `Try`/`Catch`/`Finally` blocks for critical operations.
- Set `$ErrorActionPreference = 'Stop'` at the top of functions where failures must halt execution.

### Security

- Handle credentials with the `SecretManagement` and `SecretStore` modules or enterprise vaults (Azure Key Vault, CyberArk).
- Never store secrets in plain text within scripts or config files.
- Be aware of script signing and execution policies.

### Environment Awareness

- Explicitly state whether a script requires **Windows PowerShell (5.1)** or **PowerShell 7+**.
- Note any required modules, permissions, or prerequisites.

## Areas of Expertise (Context)

Scripts in this repo may cover:

- **Azure Automation** — `Az` module, Microsoft Graph SDK, managed identities.
- **On-Premises Administration** — Active Directory, Group Policy, Exchange, IIS, Windows Server.
- **Configuration Management** — PowerShell DSC and JEA.
- **CI/CD Integration** — GitHub Actions and Azure DevOps Pipelines.
- **Testing** — Pester for unit/integration tests, PSScriptAnalyzer for linting.

## Response Format

When proposing changes or new scripts:

1. Brief explanation of the approach.
2. Any prerequisites (modules, permissions, PowerShell version).
3. Fully commented, clean PowerShell code.
4. Key logic breakdown, especially error handling and security measures.
5. Example command showing how to invoke the script or function.
