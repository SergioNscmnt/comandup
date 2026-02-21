# Contexto do Produto — CommandUp, Sistema de Comandas (Rails + Hotwire + Sidekiq)

## Visão Geral
Sistema de gerenciamento de comandas/pedidos com dois painéis:

1) **Área Cliente (Hotwire/Turbo)**
- Ver produtos disponíveis, valores, mais consumidos, promoções e combos
- Criar pedido
- Cancelar pedido (quando permitido)
- Realizar pagamento direto no app
- Acompanhar status e ETA em tempo real

2) **Área Administrativa (Hotwire/Turbo)**
- Ver fila de pedidos (FIFO: mais velho → mais novo)
- Iniciar produção, finalizar e “mandar de volta para a praça” (marcar como pronto)
- Ver métricas de fila (quantos abertos, TMP, alertas)
- Atualizações em tempo real (fila mudando sem reload)

Stack:
- **Ruby on Rails**
- **Hotwire**: Turbo Drive, Turbo Frames, Turbo Streams
- **Stimulus** para interações de UI
- **Sidekiq** para jobs de background (orquestração de ETA, notificações, conciliação de pagamento, etc.)

---

## Objetivos
- UX simples para cliente (descobrir, pedir, pagar e acompanhar)
- Operação eficiente e confiável na cozinha com FIFO
- ETA calculado a partir da carga atual de pedidos em aberto
- Consistência forte nos estados do pedido e prevenção de “furar fila” sem auditoria
- Atualizações em tempo real via Turbo Streams

---

## Máquina de Estados do Pedido (sugestão Rails-friendly)
Estados:
- `draft` (opcional)
- `received`
- `in_production`
- `ready`
- `delivered` (opcional)
- `canceled`
- `payment_failed` (opcional)

Transições:
- Cliente:
  - confirmar: `draft` -> `received`
  - cancelar: `received` -> `canceled` (apenas antes de `in_production`)
- Admin:
  - iniciar: `received` -> `in_production`
  - finalizar: `in_production` -> `ready`
  - entregar: `ready` -> `delivered` (opcional)

Regra: cliente não cancela após `in_production`.

---

## Fila FIFO
- Fila exibida ordenada por `created_at ASC` com filtro de status “em aberto”
- “Em aberto” padrão: `received` + `in_production` (configurável)
- Ação “Iniciar produção” deve preferir o topo da fila
- Se iniciar um pedido fora do topo, registrar auditoria (quem, quando, motivo)

Concorrência:
- Dois admins podem clicar ao mesmo tempo; usar travas e idempotência:
  - `SELECT ... FOR UPDATE` (via `with_lock`) no pedido alvo
  - ou optimistic locking (`lock_version`)
  - garantir que transição só ocorra se status atual for o esperado

---

## ETA (Estimativa de Entrega)
Regra fornecida:
- **TMP = minutos / quantidade_de_pedidos_em_aberto**
  - `minutos` = `minutos_base_producao` (config do estabelecimento)

Sugestão operacional:
- `N = pedidos_em_aberto.count` (inclui `received` e `in_production`)
- `TMP = clamp(minutos_base_producao / max(N,1), TMP_min, TMP_max)`
- Para cada pedido na fila aberta, com posição `pos` (1 = mais velho):
  - `eta_minutos = TMP * pos`

Atualização:
- Recalcular ETA quando:
  - novo pedido entra em `received`
  - pedido muda para `in_production`, `ready`, `canceled`
- Sidekiq faz “debounce” de recálculo para evitar tempestade de updates.
- Turbo Streams atualiza a UI em tempo real.

---

## Pagamento no App
- Abstrair gateway (“PaymentGateway”)
- Estados de pagamento:
  - `pending`, `approved`, `refused`, `refunded`
- Configuração do modo:
  - `PRE_PAGO`: pedido só vai para `received` após `approved`
  - `POS_PAGO`: pedido pode ir para `received` antes do pagamento

Webhook:
- Receber confirmação/alteração do gateway e atualizar pagamento/pedido
- Enfileirar jobs de conciliação e atualização de status/streams

---

## Rails — Entidades (modelo de dados sugerido)
- `User` (ou `Customer` + `AdminUser`) com roles
- `Product`
- `Combo` (+ join table `combo_items`)
- `Promotion`
- `Order`
- `OrderItem`
- `Payment`
- `AuditLog` (mudança de status, furo de fila, cancelamentos)

Campos essenciais em `orders`:
- `status` (enum)
- `total_cents`, `subtotal_cents`, `discount_cents`
- `eta_minutes` (cached)
- `queue_position` (cached opcional)
- `customer_id`
- `created_at`, `updated_at`

---

## Hotwire — Diretrizes
- Cliente:
  - catálogo e carrinho com Turbo Frames (atualizações parciais)
  - status do pedido e ETA via Turbo Streams (assinatura do pedido)
- Admin:
  - fila e cards via Turbo Streams no canal “orders_queue”
  - botões “Iniciar” / “Finalizar” com Turbo (sem JS pesado)
- Stimulus:
  - controle de quantidade no carrinho
  - feedback/confirm modal de cancelamento
  - countdown visual do ETA (opcional, só UI)

---

## Sidekiq — Orquestração
Jobs típicos:
- `RecalculateQueueEtaJob` (debounced)
- `BroadcastOrderUpdateJob` (Turbo Streams)
- `PaymentReconcileJob` (conciliação/atualização via gateway)
- `ExpireDraftOrdersJob` (opcional)

---

## Critérios de Qualidade
A resposta do assistente deve:
- Entregar arquitetura Rails + Hotwire coerente e pronta para implementação
- Detalhar concorrência (locks/idempotência) nas transições
- Incluir exemplos de controllers/services/jobs e rotas REST
- Propor streams Turbo (nomes, partials, broadcasts)
- Cobrir casos de borda e auditoria