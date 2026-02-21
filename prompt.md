# Prompt — Especificação e Design (Rails + Hotwire + Sidekiq)

Act like um(a) **Tech Lead Ruby on Rails + Product Manager** especialista em aplicações Hotwire (Turbo/Stimulus) e sistemas de fila/pedidos com pagamentos e jobs em background via Sidekiq.

## Objetivo
Gerar uma especificação detalhada, prática e implementável para um **Sistema de Gerenciamento de Comandas/Pedidos**, com:
- Área Cliente (Hotwire)
- Área Admin (Hotwire)
- Fila FIFO (mais velho → mais novo)
- ETA baseado em pedidos em aberto
- Pagamento no app
- Sidekiq para orquestrar recálculo de ETA, broadcasts e conciliação

Use o conteúdo do `context.md` como referência normativa.

---

## Stack e Padrões Técnicos (obrigatórios)
### Linguagens e versões
- **Ruby**: 3.3.x
- **Ruby on Rails**: 7.1.x
- **JavaScript**: ES2022+ (via importmap ou bundling leve, conforme sugerir)
- **HTML/CSS**: Bootstrap 5.x

### Banco de dados e cache
- **MariaDB**: 11.x (relacional principal)
- **Redis**: 7.x (Sidekiq + cache leve + rate limiting opcional)

> Observação: ao sugerir migrations/índices/constraints, considerar particularidades do MySQL/MariaDB (ex: índices para colunas longas, constraints suportadas, tipos e engine InnoDB).

### Background / filas
- **Sidekiq**: 7.x
- Boas práticas: idempotência, retries, dead jobs, observabilidade básica

### Real-time / UI
- **Hotwire**: Turbo + Stimulus
- Turbo Streams para updates da fila e status do pedido em tempo real

### Infra / Deploy
- **Docker/Containers**: Sim (obrigatório)
- **docker-compose** para ambiente local: `web`, `db`, `redis`, `sidekiq`
- Princípios:
  - 12-factor
  - env vars para secrets (ex: gateway)
  - healthchecks
  - migrações no deploy

### Qualidade e Segurança
- Autorização: Pundit (sugerir) ou equivalente
- Testes: RSpec (sugerir) + system tests para Hotwire (opcional)
- Logs estruturados (JSON) e auditoria de status

---

## Configurações padrão (se eu não enviar)
- `minutos_base_producao = 60`
- `TMP_min = 2`, `TMP_max = 20`
- `modo_pagamento = PRE_PAGO`
- “Em aberto” = `received` + `in_production`
- Cancelamento permitido até `received`

---

## Entradas que você deve aceitar (quando eu enviar)
Vou enviar informações adicionais dentro de delimitadores como:

```txt
[TECH]
ruby=3.3.1
rails=7.1.3
db=mariadb@11
redis=7
sidekiq=7
containers=true
js=importmap
css=bootstrap@5
[/TECH]

[CONFIG]
minutos_base_producao=60
modo_pagamento=PRE_PAGO
cancelamento_permitido_ate_status=received
TMP_min=2
TMP_max=20
[/CONFIG]

[REGRAS_EXTRAS]
- ...
[/REGRAS_EXTRAS]