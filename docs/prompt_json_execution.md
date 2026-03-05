# Prompt JSON Execution — ComandUp

## Escopo
Este documento executa o plano definido em `/home/sergio/Projetos/prompt.json`, com foco em:
1. Inventário real do repositório.
2. Diagnóstico dos pontos de dor.
3. Execução prática do que é possível nesta sessão.
4. Roadmap em fases com checklist operacional.
5. Plano de rollback rápido.

## 1) Inventário do Repositório (Passo 1)

### 1.1 Estrutura Rails encontrada
1. `app/models`
2. `app/controllers`
3. `app/views`
4. `app/javascript/controllers` (Stimulus)
5. `app/services`
6. `app/jobs`
7. `app/channels`
8. `config/routes.rb`
9. `db/migrate`
10. `spec/`

Observação:
1. `app/queries` não existe no estado atual.

### 1.2 Fluxo principal identificado (estado atual)
1. Catálogo: `ProductsController#index`, `CombosController#index`, `PromotionsController#index`.
2. Carrinho: `CartsController#show/#update/#destroy`.
3. Criação do pedido: `OrdersController#create` com `Orders::CreateService`.
4. Transição de status: `Orders::TransitionService` + `Admin::OrdersController`.
5. Atualização em tempo real: `BroadcastOrderUpdateJob`, `BroadcastQueueUpdateJob`, `OrderChannel`.
6. Pagamentos: `PaymentsController`, `Payments::WebhookService`, `Webhooks::PaymentsController`.

### 1.3 Telas principais encontradas
1. Operação pedidos: `app/views/orders/index.html.erb`, `app/views/orders/show.html.erb`.
2. KDS/fila admin: `app/views/admin/queue/show.html.erb`.
3. Dashboard admin: `app/views/admin/dashboards/*.html.erb`.

### 1.4 Dependências e capacidades
1. Hotwire: `turbo-rails`, `stimulus-rails`.
2. UI: `bootstrap` + `sassc-rails`.
3. Jobs/tempo real: `sidekiq`, `redis`, ActionCable.
4. Auth: `devise` + sessão customizada para cliente/admin.
5. Autorização: `pundit`.
6. Testes: `rspec-rails` + request/service specs.

## 2) Pontos de dor encontrados (alinhado ao prompt)

### 2.1 Cobertura de testes
1. 9 specs de modelo estão apenas com placeholder "Not yet implemented".
2. Suíte interrompida no primeiro request spec por indisponibilidade de MySQL no ambiente atual.

### 2.2 Lacunas de arquitetura
1. Não há `Query Objects` em `app/queries`.
2. `Orders::CreateService` concentra várias responsabilidades (itens, cupom, cálculo, quote delivery, totalização).

### 2.3 Consistência de domínio e operação
1. Máquina de estados já existe e está centralizada em `Orders::TransitionService`.
2. Regra FIFO existe e está testada em `spec/services/orders/transition_service_spec.rb`.
3. Não há camada explícita de idempotência para criação/edição de itens baseada em `idempotency_key`.

## 3) Execução prática nesta sessão

### 3.1 Comandos executados
1. Varredura de arquivos Rails/Specs e leitura de rotas.
2. Inspeção de modelos, controllers, services, jobs e channel.
3. Subida de infraestrutura: `docker compose up -d db redis`.
4. Preparação da base de teste: `docker compose run --rm -e RAILS_ENV=test web bin/rails db:prepare`.
5. Validação da suíte: `docker compose run --rm -e RAILS_ENV=test web bundle exec rspec --format progress`.

### 3.2 Resultado da execução
1. Inventário concluído com caminhos reais.
2. Fluxo crítico e módulos principais mapeados.
3. Suíte RSpec executada em ambiente isolado de teste.
4. Resultado anterior: `25 examples, 0 failures, 9 pending`.
5. Resultado atual após substituir placeholders de model specs: `43 examples, 0 failures`.
6. Pendências de model specs foram eliminadas.

### 3.3 Ajustes aplicados durante execução
1. Isolamento de ambiente de teste em `spec/rails_helper.rb` (`RAILS_ENV` forçado para `test`).
2. Separação de banco de teste em `docker-compose.yml` (`DB_NAME_TEST: comand_up_test`).
3. Criação de base/permissão no MariaDB para `comand_up_test`.
4. Seed desabilitado em teste (`db/seeds.rb`) para evitar contaminação de dados.
5. Correção de request spec de autenticação com `host! "localhost"` em `spec/requests/customer_authentication_spec.rb`.
6. Blindagem do teste FIFO contra dados preexistentes em `spec/services/orders/transition_service_spec.rb`.

## 4) Roadmap por Fases (Checklist)

### Fase 0 — Base
1. [x] Confirmar stack e arquitetura atual.
2. [x] Verificar logging estruturado existente (`config/initializers/log_formatter.rb`).
3. [x] Rodar smoke tests com DB ativo (docker compose + db preparada).
4. [ ] Adicionar contexto de domínio no log (ex.: `order_id`, `customer_id`) com padrão único.

### Fase 1 — Characterization Tests
1. [x] Identificar cobertura existente em requests/services.
2. [x] Estabilizar specs de autenticação e transição de status em ambiente isolado.
3. [ ] Cobrir fluxo fim-a-fim: criar pedido -> iniciar produção -> pronto -> entregue.
4. [x] Transformar placeholders de models em testes reais.
5. [ ] Adicionar testes de idempotência para criação de pedido/item.

### Fase 2 — Refatoração de Domínio
1. [ ] Extrair responsabilidades de `Orders::CreateService` em serviços menores.
2. [ ] Criar `app/queries` para métricas pesadas do admin.
3. [ ] Expandir auditoria para ações sensíveis (desconto/cancelamento administrativo).

### Fase 3 — Módulos críticos
1. [ ] Add item: idempotência com chave e transação robusta.
2. [ ] KDS: revisar escopo de broadcast por canal/contexto.
3. [ ] Fechamento e divisão: centralização total de cálculo financeiro.
4. [ ] KPIs admin: separar queries e otimizar índices.

### Fase 4 — Performance e escalabilidade
1. [ ] Revisar N+1 nas telas críticas (orders, queue, dashboard).
2. [ ] Paginador para listas grandes do admin.
3. [ ] Índices adicionais guiados por filtros reais de produção.

### Fase 5 — Módulo de apetite/upsell
1. [ ] Externalizar conteúdo sensorial em `config/*.yml` ou tabela dedicada.
2. [ ] Regras de recomendação desacopladas por feature toggle.

## 5) Como executar o plano completo localmente
1. Subir infraestrutura: `docker compose up -d db redis`.
2. Preparar DB: `docker compose run --rm web bin/rails db:prepare`.
3. Rodar testes: `docker compose run --rm web bundle exec rspec`.
4. Aplicar refatorações por lotes pequenos (PRs curtos com testes antes/depois).

## 6) Plano de rollback rápido
1. Toda mudança em lotes pequenos, isolada por PR.
2. Feature flags para módulos novos (idempotência/upsell).
3. Migrations reversíveis (`up/down` ou `change` seguro).
4. Em incidente: rollback do deploy + desabilitar flags + restaurar comportamento anterior.

## 7) Evidências objetivas
1. Rotas e módulos: `config/routes.rb`, `app/services/orders/create_service.rb`, `app/services/orders/transition_service.rb`.
2. Tempo real: `app/jobs/broadcast_order_update_job.rb`, `app/channels/order_channel.rb`.
3. Testes existentes: `spec/services/orders/transition_service_spec.rb`, `spec/requests/*.rb`.
