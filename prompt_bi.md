# Prompt — BI Administrativo e Lucratividade (ComandUp)

Act like um(a) especialista sênior em **BI (Business Intelligence), Controladoria e Operações**, com experiência em dashboards administrativos, métricas de performance e análise de lucratividade para negócios de pedidos (delivery/retirada/salão).

## Objetivo
Desenhar e detalhar um dashboard administrativo completo para o **ComandUp**, com foco em:
- leitura executiva rápida (gestão)
- investigação operacional/financeira detalhada
- simulação de ofertas e decisão de mix/produto

Use o conteúdo de `context.md` e os dados reais do schema/modelos da aplicação como referência normativa.

---

## Contexto do ComandUp (obrigatório)
### Modalidades
Mapear modalidade de negócio a partir de `orders.order_type`:
- `delivery` => Entrega
- `pickup` => Retirada
- `table` => Local

### Status de pedido
Considerar `Order.status`:
- `draft`, `received`, `in_production`, `ready`, `delivered`, `canceled`, `payment_failed`

### Tabelas-fonte principais
- `orders`
- `order_items`
- `products`
- `categories`
- `promotions`
- `payments`
- `users` (cliente e conta admin/empresa)
- `audit_logs` (para investigação de anomalias/transições)

### Campos-chave existentes
- `orders`: `created_at`, `status`, `order_type`, `subtotal_cents`, `discount_cents`, `delivery_fee_cents`, `total_cents`, `received_at`, `started_at`, `ready_at`, `delivered_at`, `canceled_at`, `customer_id`
- `order_items`: `order_id`, `product_id`, `combo_id`, `quantity`, `unit_price_cents`, `total_cents`
- `products`: `id`, `name`, `category_id`, `price_cents`, `prep_minutes`, `active`
- `promotions`: `discount_kind`, `discount_percent`, `discount_value_cents`, `coupon_category`, `starts_at`, `ends_at`, `quantity`, `active`
- `payments`: `status`, `amount_cents`, `provider`, `approved_at`

> Observação: valores monetários no banco estão em centavos (`*_cents`). Sempre converter para R$ em visualização.

---

## Escopo obrigatório da resposta

### 1) Mapa completo do dashboard (abas)
Estruturar no mínimo estas abas:
1. Visão Geral (Executivo)
2. Pedidos por Período (Diário/Semanal/Mensal/6 meses/Anual)
3. Análise por Horário e Dia da Semana
4. Modalidades (Entrega vs Retirada vs Local)
5. Financeiro (Receita, Custos, Lucro/Prejuízo)
6. Produto & Lucratividade (custos de produção e melhor oferta)
7. Alertas e Anomalias

Para cada aba, informar:
- KPIs principais (cards)
- Gráficos recomendados
- Tabelas recomendadas
- Filtros essenciais
- Perguntas que a aba responde
- Exemplo textual de layout (posicionamento dos blocos)

### 2) Dicionário de métricas com fórmula e interpretação
Incluir, no mínimo:
- pedidos totais/únicos/cancelados/concluídos
- taxa de cancelamento
- DoD/WoW/MoM/YoY
- ticket médio
- itens por pedido
- pico de pedidos (hora/dia)
- participação por modalidade
- tempos médio/p90/atraso (se aplicável)
- receita bruta, descontos, receita líquida
- CPV/CMV, custos variáveis, custos fixos
- lucro bruto, margem bruta, lucro operacional, margem operacional
- regra explícita para “prejuízo” e “ponto de atenção”

### 3) Matriz completa de metas por unidade (benchmark interno)
Gerar:
- metodologia de benchmark interno por unidade (P50/P75/P90 ou equivalente)
- metas `mínimo`, `alvo`, `excelência` por KPI
- pesos por KPI e score consolidado por unidade
- regra para KPIs “quanto menor melhor” (cancelamento/atraso)
- thresholds de desempenho (ex.: >=100 no alvo, 90-99 atenção, <90 crítico)

### 4) Elasticidade por produto para simulador
Incluir:
- modelo de elasticidade preço-volume por produto (mínimo: abordagem log-log)
- alternativa robusta para baixa amostra (shrink por categoria)
- fórmula de previsão de volume no cenário
- como aplicar sazonalidade e efeito promoção
- sinalização de confiança da elasticidade (`alta/média/baixa`)

### 5) Área de custos de produção e melhor oferta
Incluir modelo com:
- custo de ingredientes (por receita)
- embalagem
- taxas/comissões por canal
- perdas/desperdício
- mão de obra unitária (opcional)
- rateio de custo fixo (opcional)

Definir:
- custo unitário total por produto
- lucro unitário e lucro total
- simulador de cenários: desconto X%, combo (2 por 1,8), frete grátis absorvido, aumento de preço
- regra automática:
  - melhor oferta (preserva margem mínima + maior lucro)
  - produto herói (alto lucro total)
  - produto problema (margem baixa/negativa)
- margem mínima padrão: **25%** com alertas automáticos abaixo desse valor

### 6) Blueprint técnico implementável (SQL + DAX)
Entregar exemplos prontos de:
- SQL para camada semântica (views/marts de resultado)
- SQL de benchmark por unidade
- SQL de elasticidade por produto
- medidas DAX principais (KPIs financeiros/operacionais)
- medidas DAX de simulador (what-if)

As fórmulas devem ser consistentes com os campos reais do ComandUp.

### 7) Alertas e anomalias
Trazer lista de alertas com:
- métrica monitorada
- threshold
- severidade (`info/atenção/crítico`)
- ação recomendada

---

## Regras de qualidade da resposta
- Responder em português-BR.
- Ser objetivo, técnico e orientado à implementação.
- Não usar placeholders genéricos se houver campo real no schema.
- Separar claramente: premissas, cálculos, visualização, ação.
- Sempre explicitar onde há inferência por ausência de dado.

---

## Formato de saída obrigatório
1. Mapa do dashboard (abas + componentes)
2. Dicionário de métricas (nome + fórmula + interpretação)
3. Matriz de metas por unidade (benchmark interno)
4. Modelo de elasticidade e previsão de volume
5. Simulador de custos/ofertas e regras automáticas
6. Blueprint SQL
7. Blueprint DAX
8. Lista de insights acionáveis
9. Lista de alertas e thresholds
10. Autoavaliação (nota 0-10 + lacunas para 10/10)

