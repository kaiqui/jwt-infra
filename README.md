# JWT Infra Repository

## Visão Geral

Este repositório contém a infraestrutura como código (IaC) para um ambiente ECS que ja configura observalibidade incluindo o agente do Datadog e Deploy Canary com CodeDeploy. A infraestrutura é definida usando Terraform e pode ser implantada tanto localmente quanto via GitHub Actions.

## Estrutura do Repositório

```
infra/
├── backend.tf          # Configuração do backend do Terraform
├── main.tf            # Recursos principais da infraestrutura
├── outputs.tf         # Definição de outputs do Terraform
├── provider.tf        # Configuração dos providers
├── variables.tf       # Variáveis utilizadas na infraestrutura
└── README.md          # Documentação básica
```

## Componentes da Infraestrutura

A infraestrutura provisionada inclui:

1. **AWS como provedor de nuvem**
2. **Recursos para autenticação JWT** (possivelmente incluindo Lambda functions, API Gateway, DynamoDB, etc.)
3. **Configuração de rede básica** (VPC, subnets, security groups)

## Pré-requisitos

- Terraform instalado (para deploy local)
- Conta AWS com credenciais configuradas
- GitHub Actions configurado com secrets AWS (para CI/CD)

## Como Subir a Infraestrutura

### Opção 1: Via GitHub Actions

1. Configure os secrets no seu repositório GitHub:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `AWS_REGION`

2. Os workflows do GitHub Actions já estão configurados no repositório e irão:
   - Executar `terraform init`, `plan` e `apply` em push para a branch principal
   - Executar `terraform destroy` quando o repositório for arquivado (opcional)

3. Faça push para a branch `main` para disparar o deployment automático.

### Opção 2: Localmente

1. Clone o repositório:
   ```bash
   git clone https://github.com/kaiqui/jwt-infra.git
   cd jwt-infra/infra
   ```

2. Inicialize o Terraform:
   ```bash
   terraform init
   ```

3. Revise o plano de execução:
   ```bash
   terraform plan
   ```

4. Aplique as mudanças:
   ```bash
   terraform apply
   ```

5. Para destruir a infraestrutura:
   ```bash
   terraform destroy
   ```

## Variáveis Customizáveis

Você pode sobrescrever as variáveis padrão criando um arquivo `terraform.tfvars` ou passando-as via linha de comando. As principais variáveis disponíveis estão definidas em `variables.tf`.

## Observações Importantes

1. Certifique-se de revisar os custos associados aos recursos AWS antes de aplicar.
2. O estado do Terraform está configurado para usar um backend remoto (ver `backend.tf`).
3. Para produção, considere usar workspaces do Terraform ou branches separadas para diferentes ambientes.

## Troubleshooting

- Problemas de autenticação: verifique suas credenciais AWS
- Erros de região: confira se a região configurada está disponível para todos os serviços
- Limites de conta AWS: alguns recursos podem exigir aumento de limite