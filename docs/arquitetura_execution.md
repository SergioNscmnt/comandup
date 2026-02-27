# Arquitetura Execution — ComandUp

## Objetivo
Consolidar arquitetura Rails + Hotwire + Sidekiq para operação de pedidos com fila FIFO, ETA em tempo real e pagamento no app.

## Escopo Executado
1. Definição de estados e transições do pedido.
2. Estratégia de concorrência e idempotência para fila/admin.
3. Orquestração de jobs Sidekiq para ETA, broadcasts e pagamentos.
4. Blueprint de rotas, serviços e streams Turbo.
5. Plano incremental com backlog e critérios de aceite.

## Arquitetura-alvo
- Stack: Rails 7.1, MariaDB, Redis, Sidekiq, Hotwire (Turbo + Stimulus).
- Domínios principais:
1. Pedidos (`orders`, `order_items`)
2. Pagamentos (`payments`)
3. Auditoria (`audit_logs`)
4. Catálogo (`products`, `combos`, `promotions`, `categories`)

## Regras de negócio centrais
1. FIFO por `created_at ASC` para pedidos em aberto (`received`, `in_production`).
2. Cancelamento cliente permitido apenas até `received`.
3. Transição fora do topo da fila exige auditoria com motivo.
4. Em `PRE_PAGO`, pedido só entra em fluxo após pagamento aprovado.

## Backlog por Sprint

### Sprint 1 — Estado e integridade transacional
Itens:
1. Fechar transições no `Orders::TransitionService` com validação de origem.
2. Aplicar `with_lock` nas mudanças de status críticas.
3. Garantir idempotência de transições repetidas.
4. Auditar toda transição relevante em `AuditLog`.

Critérios de aceite:
1. Não há transição inválida por requisição concorrente.
2. Testes de serviço cobrem caminho feliz e rejeições.
3. Mudanças fora de FIFO ficam registradas com motivo.

### Sprint 2 — ETA e atualização em tempo real
Itens:
1. Implementar `Orders::EtaCalculator` com `TMP` configurável e clamp.
2. Disparar `RecalculateQueueEtaJob` nos eventos de entrada/saída da fila.
3. Broadcast de fila e pedido via Turbo Streams.
4. Ajustar UI admin/cliente para refletir ETA e status em tempo real.

Critérios de aceite:
1. ETA recalcula ao mudar status e ao criar pedido.
2. Fila admin atualiza sem reload.
3. Tela cliente atualiza status em tempo real.

### Sprint 3 — Pagamentos e webhook
Itens:
1. Consolidar `Payments::GatewayAdapter` para abstração de provider.
2. Processar webhook com idempotência por `provider_event_id`.
3. Criar `PaymentReconcileJob` para retentativa e conciliação.
4. Integrar estados de pagamento ao fluxo do pedido.

Critérios de aceite:
1. Eventos duplicados de webhook não geram efeitos duplicados.
2. Pedido muda de estado de forma consistente com pagamento.
3. Falhas de gateway resultam em estado observável e recuperável.

### Sprint 4 — Segurança, observabilidade e hardening
Itens:
1. Revisar políticas Pundit para área admin e cliente.
2. Padronizar logs estruturados por correlação de pedido.
3. Cobrir fluxos críticos com request specs e system tests Turbo.
4. Instrumentar métricas operacionais (fila aberta, tempo médio, erros).

Critérios de aceite:
1. Acesso indevido bloqueado por política.
2. Logs permitem rastrear ciclo de vida completo do pedido.
3. Pipeline de testes cobre transição, ETA, webhook e UI crítica.

## Blueprint técnico (resumo)

### Serviços
1. `Orders::CreateService` (criação do pedido e validações).
2. `Orders::TransitionService` (máquina de estados + FIFO + auditoria).
3. `Orders::EtaCalculator` (cálculo e atualização de ETA).
4. `Payments::WebhookService` (interpretação e aplicação de eventos).

### Jobs
1. `RecalculateQueueEtaJob`
2. `BroadcastQueueUpdateJob`
3. `BroadcastOrderUpdateJob`
4. `PaymentReconcileJob`
5. `ProcessPaymentWebhookJob`

### Rotas críticas
1. `GET /admin/queue`
2. `PATCH /admin/orders/:id/start_production`
3. `PATCH /admin/orders/:id/mark_ready`
4. `PATCH /admin/orders/:id/deliver`
5. `POST /orders/:id/cancel`
6. `POST /webhooks/payments`

### Streams Turbo
1. Canal de fila admin (`orders_queue`).
2. Canal de pedido individual (`order_<id>`).
3. Partials para card de fila e status do pedido.

## Riscos e mitigação
1. Concorrência em cliques simultâneos: mitigar com lock + checagem de origem.
2. Tempestade de recálculo ETA: mitigar com debounce e coalescência de jobs.
3. Webhook duplicado: mitigar com chave idempotente única.
4. Drift entre status e pagamento: mitigar com reconciliação periódica.

